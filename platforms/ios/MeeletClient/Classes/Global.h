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

#define SETTINGS_BUNDLE_serverUrl_IDENTIFIER @"server_url"

@interface Global : NSObject

+ (void)initApplication;
+ (NetworkEngine*)engine;
+ (void)setLoginUser:(NSString*)loginName plainPassword:(NSString*)plainPassword userObj:(NSDictionary*)userObj;
+ (void)setLoginUser:(NSDictionary*)userObj;
+ (NSDictionary*)getLoginUser;

@end

#endif
