//
//  NetworkEngine.h
//  MeeletClient
//
//  Created by jill on 15/5/24.
//
//

#ifndef MeeletClient_NetworkEngine_h
#define MeeletClient_NetworkEngine_h

#import <Foundation/Foundation.h>
#import "CommonNetworkKit.h"
#import "ResubmittableRecordStore.h"

typedef void (^StringResponseBlock)(NSString* str);

@interface NetworkEngine : NSObject

@property (nonatomic, retain) CommonNetworkEngine *engine;
@property (nonatomic, readonly) NSString* serverUrl;
@property (nonatomic, readonly) int port;

+(ResubmittableRecordStore*)recordStore;
-(void)initEngine;
-(BOOL)isReachable;

-(CommonNetworkOperation*) doLogin:(NSString*)loginName plainPassword:(NSString*)plainPassword codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) getUser:(NSString*)loginName codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) getUserDetails:(NSString*)userFilter codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;

@end

#endif
