//
//  NativeBridge.h
//  MeeletClient
//
//  Created by jill on 15/5/25.
//
//

#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

@interface NativeBridge : CDVPlugin

-(void) getServerUrl:(CDVInvokedUrlCommand*)command;
-(void) getUserDetail:(CDVInvokedUrlCommand*)command;
-(void) scanProjectCode:(CDVInvokedUrlCommand*)command;
-(void) checkProjectMode:(CDVInvokedUrlCommand*)command;
-(void) doLogin:(CDVInvokedUrlCommand*)command;
-(void) doLogout:(CDVInvokedUrlCommand*)command;
-(void) refreshUser:(CDVInvokedUrlCommand*)command;
-(void) restoreUserFromStorage:(CDVInvokedUrlCommand*)command;
-(void) getProject:(CDVInvokedUrlCommand*)command;
-(void) exitPage:(CDVInvokedUrlCommand*)command;
-(void) downloadModules:(CDVInvokedUrlCommand*)command;
-(void) downloadProject:(CDVInvokedUrlCommand*)command;
-(void) pauseDownloadProject:(CDVInvokedUrlCommand*)command;
-(void) getLocalProject:(CDVInvokedUrlCommand*)command;
-(void) deleteLocalProject:(CDVInvokedUrlCommand*)command;
-(void) showProject:(CDVInvokedUrlCommand*)command;

@end
