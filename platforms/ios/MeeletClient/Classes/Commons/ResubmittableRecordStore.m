//
//  ResubmittableRecordStore.m
//  CommonsLibrary
//
//  Created by yangxiao on 13-4-16.
//  Copyright (c) 2013年 xidigo. All rights reserved.
//

#import "ResubmittableRecordStore.h"
#import "LogMacro.h"

#define BACKEND_PUBLISH_RECORD_INTERVAL_IN_SECONDS 20

@implementation ResubmittableRecord

@synthesize owner, parentId, parentType, recordId, recordType, object, action;

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.owner forKey:@"owner"];
    [aCoder encodeObject:self.parentId forKey:@"parentId"];
    [aCoder encodeObject:self.parentType forKey:@"parentType"];
    [aCoder encodeObject:self.recordId forKey:@"recordId"];
    [aCoder encodeObject:self.recordType forKey:@"recordType"];
    [aCoder encodeObject:self.object forKey:@"object"];
    [aCoder encodeInt32:self.action forKey:@"action"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.owner = (NSString*)[aDecoder decodeObjectForKey:@"owner"];
        self.parentId = (NSString*)[aDecoder decodeObjectForKey:@"parentId"];
        self.parentType = (NSString*)[aDecoder decodeObjectForKey:@"parentType"];
        self.recordId = (NSString*)[aDecoder decodeObjectForKey:@"recordId"];
        self.recordType = (NSString*)[aDecoder decodeObjectForKey:@"recordType"];
        self.object = [aDecoder decodeObjectForKey:@"object"];
        self.action = (ResubmittableRecordAction)[aDecoder decodeInt32ForKey:@"action"];
    }
    
    return self;
}

@end

@implementation ResubmittableRecordStore {
    NSManagedObjectModel* _model;
    NSManagedObjectContext* _context;
    NSPersistentStoreCoordinator* _coordinator;
    NSEntityDescription* _entity;
    dispatch_source_t backendTimer;
}

- (id)initWithLocation:(NSString*)location
{
    if (self = [super init]) {
        dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        backendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, backgroundQueue);
        dispatch_source_set_timer(backendTimer, DISPATCH_TIME_NOW +  10 * NSEC_PER_SEC, BACKEND_PUBLISH_RECORD_INTERVAL_IN_SECONDS * NSEC_PER_SEC, 60 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(backendTimer, ^{
            [self publishRecords];
        });

        _model = [[NSManagedObjectModel alloc] init];

        _entity = [[NSEntityDescription alloc] init];
        [_entity setName:@"ResubmittableRecord"];
        
        NSMutableArray* attributes = [NSMutableArray array];
        NSAttributeDescription *attribute = [[NSAttributeDescription alloc] init];
        [attribute setName:@"parentId"];
        [attribute setAttributeType:NSStringAttributeType];
        [attribute setDefaultValue:@""];
        [attribute setOptional:YES];
        [attribute setIndexed:YES];
        [attributes addObject:attribute];
        
        attribute = [[NSAttributeDescription alloc] init];
        [attribute setName:@"parentType"];
        [attribute setAttributeType:NSStringAttributeType];
        [attribute setDefaultValue:@""];
        [attribute setOptional:YES];
        [attribute setIndexed:YES];
        [attributes addObject:attribute];
        
        attribute = [[NSAttributeDescription alloc] init];
        [attribute setName:@"recordId"];
        [attribute setAttributeType:NSStringAttributeType];
        [attribute setOptional:NO];
        [attribute setIndexed:YES];
        [attributes addObject:attribute];
        
        attribute = [[NSAttributeDescription alloc] init];
        [attribute setName:@"recordType"];
        [attribute setAttributeType:NSStringAttributeType];
        [attribute setOptional:NO];
        [attribute setIndexed:YES];
        [attributes addObject:attribute];
        
        attribute = [[NSAttributeDescription alloc] init];
        [attribute setName:@"owner"];
        [attribute setAttributeType:NSStringAttributeType];
        [attribute setOptional:NO];
        [attribute setIndexed:YES];
        [attributes addObject:attribute];

        attribute = [[NSAttributeDescription alloc] init];
        [attribute setName:@"object"];
        [attribute setAttributeType:NSBinaryDataAttributeType];
        [attribute setOptional:YES];
        [attribute setStoredInExternalRecord:YES];
        [attributes addObject:attribute];
        
        attribute = [[NSAttributeDescription alloc] init];
        [attribute setName:@"action"];
        [attribute setAttributeType:NSInteger16AttributeType];
        [attribute setOptional:NO];
        [attribute setIndexed:YES];
        [attributes addObject:attribute];
        
        [_entity setProperties:attributes];
        [_model setEntities:[NSArray arrayWithObject:_entity]];
        
        _coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];
        
        NSError *error = nil;
        if (![_coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:location] options:nil error:&error]) {
            DLog(@"Unresolved error %@", error);

            _model = nil;
            _coordinator = nil;
        } else {
            _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [_context setPersistentStoreCoordinator:_coordinator];
        }
    }
    
    return self;
}

- (void)submitRecord:(NSString*)owner parentType:(NSString*)parentType parentId:(NSString*)parentId recordType:(NSString*)recordType recordId:(NSString*)recordId action:(ResubmittableRecordAction)action record:(id<NSCoding>)record
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:_entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"owner = '%@' AND parentType = '%@' AND parentId = '%@' AND recordType = '%@' AND recordId = '%@'", owner, parentType, parentId, recordType, recordId]]];
    NSArray* arr = [_context executeFetchRequest:fetchRequest error:nil];
    NSManagedObject *managedObject = nil;
    
    if (action == Delete) {
        for (NSManagedObject* a in arr) {
            [_context deleteObject:a];
        }
        
        managedObject = [NSEntityDescription insertNewObjectForEntityForName:@"ResubmittableRecord" inManagedObjectContext:_context];
    } else {
        if (arr.count) {
            if (action == Update)
                managedObject = arr[0];
        } else {
            managedObject = [NSEntityDescription insertNewObjectForEntityForName:@"ResubmittableRecord" inManagedObjectContext:_context];
        }
    }

    if (managedObject) {
        [managedObject setValue:owner forKey:@"owner"];
        [managedObject setValue:parentId forKey:@"parentId"];
        [managedObject setValue:parentType forKey:@"parentType"];
        [managedObject setValue:recordId forKey:@"recordId"];
        [managedObject setValue:recordType forKey:@"recordType"];
        [managedObject setPrimitiveValue:[NSNumber numberWithUnsignedInt:action] forKey:@"action"];
        [managedObject setValue:[NSKeyedArchiver archivedDataWithRootObject:record] forKey:@"object"];
    }
}

- (void)removeRecord:(NSString*)owner recordType:(NSString*)recordType recordId:(NSString*)recordId
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:_entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"owner = '%@' AND recordType = '%@' AND recordId = '%@'", owner, recordType, recordId]]];
    NSError* error = nil;
    NSArray* arr = [_context executeFetchRequest:fetchRequest error:&error];

    if (error && error.code)
        DLog(@"Fetching records has error:%@", error);

    for (NSManagedObject* a in arr) {
        [_context deleteObject:a];
    }
}

- (void)removeRecord:(NSString*)owner recordType:(NSString*)recordType parentType:(NSString*)parentType parentId:(NSString*)parentId
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:_entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"owner = '%@' AND parentType = '%@' AND parentId = '%@'", owner, parentType, parentId]]];
    NSError* error = nil;
    NSArray* arr = [_context executeFetchRequest:fetchRequest error:&error];
    
    if (error && error.code)
        DLog(@"Fetching records has error:%@", error);
    
    for (NSManagedObject* a in arr) {
        [_context deleteObject:a];
    }
}

- (NSArray*)findRecords:(NSString*)owner parentType:(NSString*)parentType parentId:(NSString*)parentId recordType:(NSString*)recordType
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:_entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"owner = '%@' AND parentType = '%@' AND parentId = '%@' AND recordType = '%@'", owner, parentType, parentId, recordType]]];

    NSError* error = nil;
    NSArray* arr = [_context executeFetchRequest:fetchRequest error:&error];
    
    if (error && error.code)
        DLog(@"Fetching records has error:%@", error);
    
    NSMutableArray* result = [NSMutableArray array];
    for (NSManagedObject* managedObject in arr) {
        ResubmittableRecord* record = [[ResubmittableRecord alloc] init];
        record.owner = [managedObject valueForKey:@"owner"];
        record.parentType = [managedObject valueForKey:@"parentType"];
        record.parentId = [managedObject valueForKey:@"parentId"];
        record.recordType = [managedObject valueForKey:@"recordType"];
        record.recordId = [managedObject valueForKey:@"recordId"];
        record.object = [NSKeyedUnarchiver unarchiveObjectWithData:[managedObject valueForKey:@"object"]];
        record.action = [(NSNumber*)[managedObject primitiveValueForKey:@"action"] unsignedIntValue];
        
        [result addObject:record];
    }
    
    return result;
}

- (NSArray*)findRecords:(NSString*)owner recordType:(NSString*)recordType
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:_entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"owner = '%@' AND recordType = '%@'", owner, recordType]]];
    
    NSError* error = nil;
    NSArray* arr = [_context executeFetchRequest:fetchRequest error:&error];
    
    if (error && error.code)
        DLog(@"Fetching records has error:%@", error);

    NSMutableArray* result = [NSMutableArray array];
    for (NSManagedObject* managedObject in arr) {
        ResubmittableRecord* record = [[ResubmittableRecord alloc] init];
        record.owner = [managedObject valueForKey:@"owner"];
        record.parentType = [managedObject valueForKey:@"parentType"];
        record.parentId = [managedObject valueForKey:@"parentId"];
        record.recordType = [managedObject valueForKey:@"recordType"];
        record.recordId = [managedObject valueForKey:@"recordId"];
        record.object = [NSKeyedUnarchiver unarchiveObjectWithData:[managedObject valueForKey:@"object"]];
        record.action = [(NSNumber*)[managedObject primitiveValueForKey:@"action"] unsignedIntValue];
        
        [result addObject:record];
    }
    
    return result;
}

- (void)save
{
    NSError *error = nil;

    if ([_context hasChanges]) {
        if (![_context save:&error]) {
            DLog(@"Unresolved error %@", error);
        }
    }
}

- (void)publishRecords
{
    DLog(@"Running publishing resubmittable records at backend at %@", [NSDate date]);

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:_entity];
    
    NSError* error = nil;
    NSArray* arr = [_context executeFetchRequest:fetchRequest error:&error];
    
    if (error && error.code)
        DLog(@"Fetching records has error:%@", error);
    
    NSMutableArray* records = [NSMutableArray array];
    for (NSManagedObject* managedObject in arr) {
        ResubmittableRecord* record = [[ResubmittableRecord alloc] init];
        record.owner = [managedObject valueForKey:@"owner"];
        record.parentType = [managedObject valueForKey:@"parentType"];
        record.parentId = [managedObject valueForKey:@"parentId"];
        record.recordType = [managedObject valueForKey:@"recordType"];
        record.recordId = [managedObject valueForKey:@"recordId"];
        record.object = [NSKeyedUnarchiver unarchiveObjectWithData:[managedObject valueForKey:@"object"]];
        record.action = [(NSNumber*)[managedObject primitiveValueForKey:@"action"] unsignedIntValue];
        
        [records addObject:record];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:ResubmittableRecordNotification
                                                            object:records];
    });
}

- (void)startNotification
{
    dispatch_resume(backendTimer);
}

- (void)stopNotification
{
    dispatch_suspend(backendTimer);
}

@end
