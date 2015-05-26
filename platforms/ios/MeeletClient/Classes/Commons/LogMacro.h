//
//  LogMacro.h
//  CommonsLibrary
//
//  Created by yangxiao on 12-11-29.
//  Copyright (c) 2012年 xidigo. All rights reserved.
//

#ifndef CommonsLibrary_LogMacro_h
#define CommonsLibrary_LogMacro_h

#ifdef DEBUG
#   define DLog(fmt, ...) {NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);}
#   define ELog(err) {if(err) DLog(@"%@", err)}
#else
#   define DLog(...)
#   define ELog(err)
#endif

// ALog always displays output regardless of the DEBUG setting
#define ALog(fmt, ...) {NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);};

#endif
