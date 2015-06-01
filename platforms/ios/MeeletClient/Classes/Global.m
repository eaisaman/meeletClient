//
//  Global.m
//  MeeletClient
//
//  Created by jill on 15/5/25.
//
//

#import <Foundation/Foundation.h>
#import "Global.h"
#import "MainViewController.h"
#import "UserDetails.h"
#import "SecurityContext.h"
#import "QRCodeViewController.h"
#import <Pods/JSONKit/JSONKit.h>
#import <Pods/CocoaLumberjack/DDLog.h>
#import <Pods/CocoaLumberjack/DDTTYLogger.h>
#import <Pods/CocoaHTTPServer/HTTPServer.h>
#import <Pods/CocoaHTTPServer/DAVConnection.h>
#import <Pods/SSZipArchive/SSZipArchive.h>

#define TMP_PATH @"tmp"
#define PROJECT_PATH @"project"

@implementation Global

+(NetworkEngine*)engine
{
    static NetworkEngine* networkEngine = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        networkEngine = [[NetworkEngine alloc] init];
    });
    
    return networkEngine;
}

+(HTTPServer*)httpServer
{
    static HTTPServer* server = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        server = [[HTTPServer alloc] init];
        
        // Tell the server to broadcast its presence via Bonjour.
        // This allows browsers such as Safari to automatically discover our service.
        [server setType:@"_http._tcp."];
        
        [server setPort:8080];
        
        [server setConnectionClass:[DAVConnection class]];
        
        // Serve files from our embedded Web folder
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *webPath = [paths objectAtIndex:0];
        
        [server setDocumentRoot:webPath];
    });
    
    return server;
}

+(void)initApplication
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self restoreLoginUser];
        [[self engine] initEngine];

#warning Launch HTTP server to browse application files for debug. Should disable this feature in the phase of release.
        NSError *error;
        HTTPServer* httpServer = [self httpServer];
        if([httpServer start:&error])
        {
            ALog(@"Started HTTP Server on port %hu, document root %@", [httpServer listeningPort], [httpServer documentRoot]);
        }
        else
        {
            ALog(@"Error starting HTTP Server: %@", error);
        }
    });
}

+ (void)setLoginUser:(NSString*)loginName plainPassword:(NSString*)plainPassword userObj:(NSDictionary *)userObj
{
    if (loginName && loginName.length) {
        UserDetails* details = [[UserDetails alloc] init];
        details.loginName = loginName;
        details.plainPassword = plainPassword;
        details.detailsObject = userObj;
        
        [SecurityContext getObject].details = details;
        
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *userDict = [userObj mutableCopy];
        [userDict addEntriesFromDictionary:@{@"loginName":loginName, @"plainPassword":plainPassword}];
        [ud setObject:[userDict JSONStringWithOptions:JKSerializeOptionNone error:NULL] forKey:@"loginUser"];
        [ud synchronize];
    } else {
        [SecurityContext getObject].details = [UserDetails getDefault];
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        [ud removeObjectForKey:@"loginUser"];
        [ud synchronize];
    }
}

+ (void)setLoginUser:(NSDictionary*)userObj
{
    NSString* userName = [userObj objectForKey:@"loginName"];
    NSAssert(![userName isEqualToString:[UserDetails getDefault].loginName], [NSString stringWithFormat:@"Invalid user name, maybe not log on."]);
    
    [SecurityContext getObject].details.detailsObject = userObj;
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString* strUser = [ud objectForKey:@"loginUser"];
    
    if (strUser) {
        NSMutableDictionary *userDict = [[strUser objectFromJSONString] mutableCopy];
        [userDict addEntriesFromDictionary:userObj];
        [ud setObject:[userDict JSONStringWithOptions:JKSerializeOptionNone error:NULL] forKey:@"loginUser"];
        [ud synchronize];
    }
}

+(void) restoreLoginUser {
    NSDictionary *userDict = [self getLoginUser];
    
    if (userDict && userDict.count) {
        UserDetails* details = [[UserDetails alloc] init];
        NSString *plainPassword = [userDict objectForKey:@"plainPassword"];
        details.loginName = [userDict objectForKey:@"loginName"];
        details.plainPassword = plainPassword;
        details.detailsObject = userDict;
        [SecurityContext getObject].details = details;
    }
}

+ (NSDictionary*)getLoginUser {
    NSHTTPCookie *sessionCookie = nil;
    
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        if ([cookie.name isEqualToString:@"connect.sid"]) {
            sessionCookie = cookie;
        }
    }
    
    NSDictionary *userDict = @{};
    if (sessionCookie) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSString* strUser = [ud objectForKey:@"loginUser"];
        
        if (strUser) {
            userDict = [strUser objectFromJSONString];
        }
    }
    
    return userDict;
}

+ (NSArray*)getLocalProject
{
    NSMutableArray* result = [NSMutableArray array];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator* directoryEnumerator =[fileManager enumeratorAtURL:[NSURL fileURLWithPath:[self projectsPath] isDirectory:YES] includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLFileResourceTypeKey, nil] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];

    for (NSURL* subDirectory in directoryEnumerator) {
        NSString* dirType = nil;
        [subDirectory getResourceValue:&dirType forKey:NSURLFileResourceTypeKey error:nil];

        if ([dirType isEqual:NSURLFileResourceTypeDirectory]) {
            NSString* jsonPath = [[subDirectory path] stringByAppendingPathComponent:@"project.json"];
            if ([fileManager fileExistsAtPath:jsonPath]) {
                NSString* jsonContent = [NSString stringWithContentsOfFile:jsonPath encoding:NSUTF8StringEncoding error:nil];
                [result addObject:[jsonContent objectFromJSONString]];
            }
        }
    }
    
    return result;
}

+ (void)downloadProject:(NSString*)projectId
{
    [[self engine] downloadProject:projectId codeBlock:^(CommonNetworkOperation *completedOperation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSFileManager* manager = [NSFileManager defaultManager];
            NSString* tmpPath = [[Global tmpPath] stringByAppendingPathComponent:[projectId stringByAppendingPathExtension:@"zip"]];
            NSString* projectPath = [self projectPath:projectId];
            
            if ([manager fileExistsAtPath:tmpPath]) {
                if ([manager fileExistsAtPath:projectPath]) {
                    [manager removeItemAtPath:projectPath error:nil];
                }
                [SSZipArchive unzipFileAtPath:tmpPath toDestination:projectPath];
                [manager removeItemAtPath:tmpPath error:nil];
            }
            
            MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
            [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onDownloadProjectDone && onDownloadProjectDone('%@')", projectId]];
        });
    } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
            [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onDownloadProjectError && onDownloadProjectError('%@', '%@')", projectId, [error localizedDescription]]];
        });
    } progressBlock:^(double progress) {
        DLog(@"Download in progress %.2f", progress);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
            [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onDownloadProjectProgress && onDownloadProjectProgress('%@', %.2f)", projectId, progress]];
        });
    }];
}

+ (BOOL)isValidObjectId:(NSString*)idStr
{
    NSRegularExpression* objectIdPattern = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-fA-F]{24}$" options:NSRegularExpressionCaseInsensitive error:nil];
    
    return idStr && idStr.length == 24 && [objectIdPattern numberOfMatchesInString:idStr options:NSMatchingReportCompletion range:NSMakeRange(0, 24)];
}

+ (NSDate*)parseDateString:(NSString*)dateString
{
    static NSDateFormatter* formatter = nil;
    static NSRegularExpression *regex = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];
        
        regex = [NSRegularExpression regularExpressionWithPattern:@"\\.[0-9]{3}Z$" options:NSRegularExpressionCaseInsensitive error:nil];
    });
    
    dateString = [regex stringByReplacingMatchesInString:dateString options:0 range:NSMakeRange(0, dateString.length) withTemplate:@"GMT+00:00"];
    NSDate* date = [formatter dateFromString:dateString];
    
    return date;
}

+ (NSDictionary*)restoreJSONDate:(NSDictionary*)dict
{
    NSMutableDictionary* result = [NSMutableDictionary dictionaryWithDictionary:dict];
    
    NSString* time = [result objectForKey:@"createTime"];
    if (time) {
        [result setObject:[self parseDateString:time] forKey:@"createTime"];
    }
    
    time = [result objectForKey:@"updateTime"];
    if (time) {
        [result setObject:[self parseDateString:time] forKey:@"updateTime"];
    }
    
    return result;
}

#pragma GCC diagnostic ignored "-Wundeclared-selector"
+ (void)scanProjectCode
{
    UIViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
    QRCodeViewController* ctrl = [[QRCodeViewController alloc] init];
    ctrl.resultBlock = ^(NSString* projectId) {
        if ([self isValidObjectId:projectId]) {
            DLog(@"Scanned project id:%@", projectId);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
                [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onProjectScan && onProjectScan('%@')", projectId]];
            });
        }
    };
    [viewController presentViewController:ctrl animated:YES completion:nil];
}

+(NSString*)userFilePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:[SecurityContext getObject].details.loginName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)tmpPath
{
    NSString *path = [[self userFilePath] stringByAppendingPathComponent:TMP_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)projectsPath
{
    NSString *path = [[self userFilePath] stringByAppendingPathComponent:PROJECT_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)projectPath:(NSString*)projectId
{
    return [[self projectsPath] stringByAppendingPathComponent:projectId];
}

@end