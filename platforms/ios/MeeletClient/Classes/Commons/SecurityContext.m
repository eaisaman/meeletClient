//
//  SecurityContext.m
//  CommonsLibrary
//
//  Created by yangxiao on 12-12-20.
//  Copyright (c) 2012年 xidigo. All rights reserved.
//

#import "SecurityContext.h"

@implementation SecurityContext

@synthesize details;

+(SecurityContext *) getObject {
    static SecurityContext* context = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[SecurityContext alloc] init];
        context.details = [UserDetails getDefault];
    });
    
    return context;
}
@end
