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
#import "ProjectViewController.h"
#import "UserDetails.h"
#import "SecurityContext.h"
#import "QRCodeViewController.h"
#import <Pods/JSONKit/JSONKit.h>
#import <Pods/CocoaLumberjack/DDLog.h>
#import <Pods/CocoaLumberjack/DDTTYLogger.h>
#import <Pods/CocoaHTTPServer/HTTPServer.h>
#import <Pods/CocoaHTTPServer/DAVConnection.h>
#import <Pods/SSZipArchive/SSZipArchive.h>

const char* ProjectModeName[] = {"waitDownload", "waitRefresh", "inProgress"};

#define TMP_PATH @"tmp"
#define PROJECT_PATH @"project"
#define PROJECT_INFO_PATH @"info"
#define PROJECT_CONTENT_PATH @"content"

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
    NSDirectoryEnumerator* directoryEnumerator =[fileManager enumeratorAtURL:[NSURL fileURLWithPath:[self projectsInfoPath] isDirectory:YES] includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLFileResourceTypeKey, nil] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];

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
    NSString *infoPath = [self projectInfoPath:projectId];
    NSString *projectJsonPath = [infoPath stringByAppendingPathComponent:@"project.json"];
    NSFileManager *manager = [NSFileManager defaultManager];
    
    if (![manager fileExistsAtPath:infoPath]) {
        [manager createDirectoryAtPath:infoPath withIntermediateDirectories:NO attributes:nil error:nil];
    }
    
    if (![manager fileExistsAtPath:projectJsonPath]) {
        [[Global engine] getProject:[@{@"_id":projectId} JSONString] codeBlock:^(NSString *record) {
            NSMutableDictionary *recordDict = [@{} mutableCopy];
            [recordDict addEntriesFromDictionary:[record objectFromJSONString]];
            NSArray *arr = [recordDict objectForKey:@"resultValue"];
            
            if(arr.count) {
                NSDictionary *dict = arr[0];
                [[dict JSONString] writeToFile:projectJsonPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
                    [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onGetProjectError && onGetProjectError('%@', '%@')", projectId, @"Project record cannot be found."]];
                });
            }
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
                [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onGetProjectError && onGetProjectError('%@', '%@')", projectId, [error localizedDescription]]];
            });
        }];
    }
    
    MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
    [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onDownloadProjectStart && onDownloadProjectStart('%@', '%@')", projectId, ENUM_NAME(ProjectMode, InProgress)]];//Project mode: 0.Wait Download; 1.Wait Refresh; 2. Download or Refresh in Progress

    [[self engine] downloadProject:projectId codeBlock:^(CommonNetworkOperation *completedOperation) {
        ALog(@"Download complete %@", projectId);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
            [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onDownloadProjectDone && onDownloadProjectDone('%@', '%@')", projectId, ENUM_NAME(ProjectMode, WaitRefersh)]];
        });
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSFileManager* manager = [NSFileManager defaultManager];
            NSString* tmpPath = [[Global tmpPath] stringByAppendingPathComponent:[projectId stringByAppendingPathExtension:@"zip"]];
            NSString* projectTmpPath = [[Global tmpPath] stringByAppendingPathComponent:projectId];
            NSString* projectPath = [self projectPath:projectId];

            if ([manager fileExistsAtPath:tmpPath]) {
                if ([manager fileExistsAtPath:projectTmpPath]) {
                    [manager removeItemAtPath:projectTmpPath error:nil];
                }
                [SSZipArchive unzipFileAtPath:tmpPath toDestination:projectTmpPath];

                if ([manager fileExistsAtPath:projectPath]) {
                    [manager removeItemAtPath:projectPath error:nil];
                }
                [manager moveItemAtPath:projectTmpPath toPath:projectPath error:nil];
            }
        });
    } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSUInteger prevProgress = [self projectProgress:projectId];
            NSString* mode = [self projectMode:projectId];
            MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
            [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onDownloadProjectError && onDownloadProjectError('%@', '%@', %lu, '%@')", projectId, mode, prevProgress, [error localizedDescription]]];
        });
    } progressBlock:^(double progress) {
        DLog(@"Download in progress %.2f", progress);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
            [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onDownloadProjectProgress && onDownloadProjectProgress('%@', %lu)", projectId, (unsigned long)(ceilf(progress * 100))]];
        });
    }];
}

+ (void)pauseDownloadProject:(NSString *)projectId
{
    [[self engine] pauseDownloadProject:projectId];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* mode = [self projectMode:projectId];
        MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
        [viewController.commandDelegate evalJs:[NSString stringWithFormat:@"onDownloadProjectStop && onDownloadProjectStop('%@', '%@')", projectId, mode]];
    });
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

+ (void)showProject:(NSString *)projectId codeBlock:(ReponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString* projectPath = [self projectPath:projectId];
    NSString* indexPath = [projectPath stringByAppendingPathComponent:@"index.html"];

    if ([manager fileExistsAtPath:projectPath] && [manager fileExistsAtPath:indexPath]) {
        if (codeBlock) {
            codeBlock();
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            ProjectViewController* ctrl = [[ProjectViewController alloc] init];
            ctrl.wwwFolderName = [[NSURL fileURLWithPath:projectPath] absoluteString];
            ctrl.startPage = @"index.html";

            MainViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
            [viewController presentViewController:ctrl animated:YES completion:nil];
        });
    } else {
        if (errorBlock) {
            errorBlock([NSError errorWithDomain:APP_ERROR_DOMAIN code:APP_ERROR_OPEN_FILE_CODE userInfo:@{@"error":@"Directory not found."}]);
        }
    }
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

+(NSString*)projectsInfoPath
{
    NSString *path = [[self projectsPath] stringByAppendingPathComponent:PROJECT_INFO_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)projectsContentPath
{
    NSString *path = [[self projectsPath] stringByAppendingPathComponent:PROJECT_CONTENT_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)projectPath:(NSString*)projectId
{
    return [[self projectsContentPath] stringByAppendingPathComponent:projectId];
}

+(NSString*)projectInfoPath:(NSString*)projectId
{
    return [[self projectsInfoPath] stringByAppendingPathComponent:projectId];
}

//Project mode: 0.Wait Download; 1.Wait Refresh; 2. Download or Refresh in Progress
+(NSString*)projectMode:(NSString*)projectId
{
    if ([[self engine] downloadProjectInProgress:projectId]) {
        return ENUM_NAME(ProjectMode, InProgress);
    } else {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[self projectPath:projectId]]) {
            return ENUM_NAME(ProjectMode, WaitRefersh);
        } else {
            return ENUM_NAME(ProjectMode, WaitDownload);
        }
    }
}

+(NSUInteger)projectProgress:(NSString*)projectId
{
    NSDictionary* downloadInfo = [[self engine] downloadProjectInfo:projectId];
    if (downloadInfo) {
        NSNumber *unitCompleted = [downloadInfo objectForKey:@"unitCompleted"];
        NSNumber *unitTotal = [downloadInfo objectForKey:@"unitTotal"];
        if (unitCompleted && unitTotal) {
            float progress = [unitCompleted floatValue] / [unitTotal floatValue];
            return (NSUInteger)ceilf(progress * 100);
        }
    }
    
    return 0;
}

@end