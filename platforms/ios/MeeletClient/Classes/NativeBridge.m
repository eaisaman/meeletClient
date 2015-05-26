//
//  NativeBridge.m
//  MeeletClient
//
//  Created by jill on 15/5/25.
//
//

#import "NativeBridge.h"
#import "Global.h"
#import "LogMacro.h"
#import <Pods/JSONKit/JSONKit.h>

@implementation NativeBridge

-(NSDictionary*) prevResponse:(NSString*)prevResponsePath
{
    if (prevResponsePath && [[NSFileManager defaultManager] fileExistsAtPath:prevResponsePath]) {
        NSData *prevResponseData = [NSData dataWithContentsOfFile:prevResponsePath];
        if (prevResponseData && prevResponseData.length) {
            NSString *prevResponseString =[[NSString alloc] initWithData:prevResponseData encoding:NSUTF8StringEncoding];
            
            return @{@"data":[prevResponseString objectFromJSONString]};
        }
    }
    
    return @{@"data":@{@"result":@"ERROR"}};
}

-(void) getServerUrl:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":[NSString stringWithFormat:@"http://%@:%i", [Global engine].serverUrl, [Global engine].port]}}];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) getUserDetail:(CDVInvokedUrlCommand *)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString *userFilter = command.arguments[0];
        [[Global engine] getUserDetails:userFilter codeBlock:^(NSString *record) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[record objectFromJSONString]}];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == kCFURLErrorCannotConnectToHost) {
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[self prevResponse:prevResponsePath]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                return;
            }
            
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) scanProjectCode:(CDVInvokedUrlCommand *)command
{
    
}

-(void) checkProjectExist:(CDVInvokedUrlCommand *)command
{
    
}

-(void) doLogin:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
            DLog(@"name: %@=%@;domain=%@;expires=%@\n", cookie.name, cookie.value, cookie.domain, cookie.expiresDate);
        }
        
        NSString *loginName = command.arguments[0];
        NSString *plainPassword = command.arguments[1];
        [[Global engine] doLogin:loginName plainPassword:plainPassword codeBlock:^(NSString *record) {
            NSMutableDictionary *recordDict = [@{} mutableCopy];
            [recordDict addEntriesFromDictionary:[record objectFromJSONString]];
            NSArray *arr = [recordDict objectForKey:@"resultValue"];
            
            if(arr.count) {
                NSDictionary *userObj = arr[0];
                [Global setLoginUser:loginName plainPassword:plainPassword userObj:userObj];
                
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userObj];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"User object not returned."];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) doLogout:(CDVInvokedUrlCommand*)command
{
    NSHTTPCookie *sessionCookie = nil;
    
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        if ([cookie.name isEqualToString:@"connect.sid"]) {
            sessionCookie = cookie;
        }
    }
    
    if (sessionCookie) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:sessionCookie];
    }
    
    [Global setLoginUser:nil plainPassword:nil userObj:nil];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) refreshUser:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString *loginName = command.arguments[0];
        [[Global engine] getUser:loginName codeBlock:^(NSString *record) {
            NSMutableDictionary *recordDict = [@{} mutableCopy];
            [recordDict addEntriesFromDictionary:[record objectFromJSONString]];
            NSArray *arr = [recordDict objectForKey:@"resultValue"];
            
            if(arr.count) {
                NSDictionary *userObj = arr[0];
                [Global setLoginUser:userObj];
                
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userObj];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"User object not returned."];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) restoreUserFromStorage:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":[Global getLoginUser]}}];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end