//
//  Global.m
//  MeeletClient
//
//  Created by jill on 15/5/25.
//
//

#import <Foundation/Foundation.h>
#import "Global.h"
#import "UserDetails.h"
#import "SecurityContext.h"
#import <Pods/JSONKit/JSONKit.h>

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

+(void)initApplication
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self restoreLoginUser];
        [[self engine] initEngine];
    });
}

+ (void)setLoginUser:(NSString*)loginName plainPassword:(NSString*)plainPassword userObj:(NSDictionary *)userObj
{
    if (loginName && loginName.length) {
        UserDetails* details = [[UserDetails alloc] init];
        details.userName = loginName;
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
    NSAssert(![userName isEqualToString:[UserDetails getDefault].userName], [NSString stringWithFormat:@"Invalid user name, maybe not log on."]);
    
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
        details.userName = [userDict objectForKey:@"loginName"];
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

+(NSString*)userFilePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:[SecurityContext getObject].details.userName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

@end