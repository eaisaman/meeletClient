//
//  Global.h
//  MeeletClient
//
//  Created by jill on 15/5/24.
//
//

#ifndef MeeletClient_Global_h
#define MeeletClient_Global_h

#import "NetworkEngine.h"

#define APP_URL_SCHEME @"meeletClient"
#define APP_ERROR_DOMAIN @"meeletClientErrorDomain"
#define APP_ERROR_OPEN_FILE_CODE -1

#define SETTINGS_BUNDLE_serverUrl_IDENTIFIER @"server_url"

#define ENUM_NAME(x,v) [NSString stringWithCString:x##Name[v] encoding:NSASCIIStringEncoding]

typedef void (^ReponseBlock)(void);
typedef void (^ErrorBlock)(NSError* error);

typedef NS_ENUM(NSUInteger, ProjectMode) {
    WaitDownload = 0,
    WaitRefersh = 1,
    InProgress = 2
};

extern const char* ProjectModeName[];

@interface Global : NSObject

+ (void)initApplication;
+ (NetworkEngine*)engine;
+ (NSString*)tmpPath;
+ (NSString*)projectContentPath:(NSString*)projectId;
+ (NSString*)projectInfoPath:(NSString*)projectId;
+ (NSString*)projectsModulesPath;

+ (void)setLoginUser:(NSString*)loginName plainPassword:(NSString*)plainPassword userObj:(NSDictionary*)userObj;
+ (void)setLoginUser:(NSDictionary*)userObj;
+ (NSDictionary*)getLoginUser;
+ (NSArray*)getLocalProject;
+ (void)downloadModules;
+ (void)downloadProject:(NSString*)projectId;
+ (void)pauseDownloadProject:(NSString*)projectId;
+ (void)scanProjectCode;
+ (void)deleteLocalProject:(NSString*)projectId;
+ (void)showProject:(NSString*)projectId codeBlock:(ReponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock;

+ (BOOL)isValidObjectId:(NSString*)idStr;
+ (NSDate*)parseDateString:(NSString*)dateString;
+ (NSDictionary*)restoreJSONDate:(NSDictionary*)dict;
+ (NSString*)projectMode:(NSString*)projectId;
+ (NSUInteger)projectProgress:(NSString*)projectId;

@end

#endif
