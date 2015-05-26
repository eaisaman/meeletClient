//
//  ResubmittableRecordStore.h
//  CommonsLibrary
//
//  Created by yangxiao on 13-4-16.
//  Copyright (c) 2013年 xidigo. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ResubmittableRecordAction) {
    Add = 0,
    Update = 1,
    Delete = 2
};

#define ResubmittableRecordNotification @"ResubmittableRecordNotification"

@interface ResubmittableRecord : NSObject<NSCoding>

@property(nonatomic, strong) id<NSCoding> object;
@property(nonatomic, strong) NSString* owner;
@property(nonatomic, strong) NSString* parentId;
@property(nonatomic, strong) NSString* parentType;
@property(nonatomic, strong) NSString* recordId;
@property(nonatomic, strong) NSString* recordType;
@property(nonatomic, assign) ResubmittableRecordAction action;

@end

@interface ResubmittableRecordStore : NSObject

- (id)initWithLocation:(NSString*)location;
- (void)submitRecord:(NSString*)owner parentType:(NSString*)parentType parentId:(NSString*)parentId recordType:(NSString*)recordType recordId:(NSString*)recordId action:(ResubmittableRecordAction)action record:(id<NSCoding>)record;
- (void)removeRecord:(NSString*)owner recordType:(NSString*)recordType recordId:(NSString*)recordId;
- (void)removeRecord:(NSString*)owner recordType:(NSString*)recordType parentType:(NSString*)parentType parentId:(NSString*)parentId;
- (NSArray*)findRecords:(NSString*)owner parentType:(NSString*)parentType parentId:(NSString*)parentId recordType:(NSString*)recordType;
- (NSArray*)findRecords:(NSString*)owner recordType:(NSString*)recordType;
- (void)save;
- (void)startNotification;
- (void)stopNotification;

@end
