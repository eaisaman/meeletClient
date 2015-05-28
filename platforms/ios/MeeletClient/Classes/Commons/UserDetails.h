//
//  UserDetails.h
//  CommonsLibrary
//
//  Created by yangxiao on 12-12-20.
//  Copyright (c) 2012年 xidigo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserDetails : NSObject

@property(nonatomic, retain) NSString* loginName;
@property(nonatomic, retain) NSString* plainPassword;
@property(nonatomic, retain) id detailsObject;

+(UserDetails*) getDefault;

@end
