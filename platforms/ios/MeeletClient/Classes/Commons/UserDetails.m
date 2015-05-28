//
//  UserDetails.m
//  CommonsLibrary
//
//  Created by yangxiao on 12-12-20.
//  Copyright (c) 2012年 xidigo. All rights reserved.
//

#import "UserDetails.h"

@implementation UserDetails

@synthesize loginName, plainPassword, detailsObject;

+ (UserDetails*) getDefault
{
    static UserDetails* defaultUserDetails = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultUserDetails = [[UserDetails alloc] init];
        defaultUserDetails.loginName = @"DEFAULT";
        defaultUserDetails.detailsObject = nil;
    });
    
    return defaultUserDetails;
}
@end
