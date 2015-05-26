//
//  SecurityContext.h
//  CommonsLibrary
//
//  Created by yangxiao on 12-12-20.
//  Copyright (c) 2012年 xidigo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UserDetails.h"

@interface SecurityContext : NSObject

@property(nonatomic, retain) UserDetails* details;

+(SecurityContext *) getObject;

@end
