//
//  CommonNetworkEngine.m
//  MeeletClient
//
//  Created by jill on 15/5/25.
//
//

#import "CommonNetworkKit.h"
#import "LogMacro.h"

#ifdef __OBJC_GC__
#error CommonNetworkKit does not support Objective-C Garbage Collection
#endif

#if ! __has_feature(objc_arc)
#error CommonNetworkKit is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#import "NSString+MD5Addition.h"

#define MAX_CONCURRENT_OPERATION_COUNT 30
#define BACKEND_UPDATE_INTERVAL_IN_SECONDS 60
#define BACKEND_CLEAR_EXPIRED_ITEM_INTERVAL_IN_SECONDS 3600

static NSOperationQueue *_sharedNetworkQueue;
static NSMutableArray* _sharedEngineArray;

typedef NS_ENUM(NSUInteger, OperationCacheUpdateOptions) {
    OperationCacheNone = 0,
    OperationCacheUpdate = 1,
    OperationCacheDelete = 2
};

@interface OperationCache(Private)

- (id) initWithLocation:(NSString*)theGroupName;
- (void) write:(CommonNetworkOperation*)operation;
- (void) remove:(NSString*)forKey;
- (void) empty;

@end

@implementation OperationCache {
@private
    NSURL* _directory;
    NSMutableDictionary* _opearationsInMemory;
    dispatch_source_t backendTimer;
    dispatch_source_t clearExpiredItemTimer;
    dispatch_queue_t operationCacheQueue;
}

- (id) initWithLocation:(NSString*)theGroupName
{
    if (self = [super init]) {
        NSString* cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
        _directory = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:cachesDirectory, @"OperationCache", theGroupName, nil]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:[_directory path]]) {
            NSError* error = NULL;
            [[NSFileManager defaultManager] createDirectoryAtURL:_directory withIntermediateDirectories:YES attributes:NULL error:&error];
            if (error && error.code) {
                NSException* e = [[NSException alloc] initWithName:@"CommonNetworkEngine" reason:[NSString stringWithFormat:@"ERROR: Error occurred while creating folder and its ancestors at path %@ :%@", [_directory path], error.description] userInfo:NULL];
                @throw e;
            }
        }
        
        _opearationsInMemory = [NSMutableDictionary dictionary];
        
        operationCacheQueue = dispatch_queue_create("operation.cachequeue", DISPATCH_QUEUE_CONCURRENT);
        
        dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        backendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, backgroundQueue);
        dispatch_source_set_timer(backendTimer, DISPATCH_TIME_NOW, BACKEND_UPDATE_INTERVAL_IN_SECONDS * NSEC_PER_SEC, 60 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(backendTimer, ^{
            [self backendUpdate];
        });
        dispatch_resume(backendTimer);
        clearExpiredItemTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, backgroundQueue);
        dispatch_source_set_timer(clearExpiredItemTimer, DISPATCH_TIME_NOW, BACKEND_CLEAR_EXPIRED_ITEM_INTERVAL_IN_SECONDS * NSEC_PER_SEC, 60 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(clearExpiredItemTimer, ^{
            [self clearExpiredItem];
        });
        dispatch_resume(clearExpiredItemTimer);
    }
    return self;
}

- (void) flush
{
    DLog(@"Running flush of operations in memory at %@", now);
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    for (NSString* key in [_opearationsInMemory allKeys]) {
        NSArray* value = _opearationsInMemory[key];
        NSString* archivePath = [[_directory path] stringByAppendingPathComponent:key];
        switch ([(NSNumber*)[value objectAtIndex:0] integerValue]) {
            case OperationCacheUpdate:
                [NSKeyedArchiver archiveRootObject:[value objectAtIndex:1] toFile:archivePath];
                [_opearationsInMemory setObject:[NSArray arrayWithObjects:[NSNumber numberWithInteger:OperationCacheNone], [value objectAtIndex:1], nil] forKey:key];
                break;
            case OperationCacheDelete:
                if ([fileManager fileExistsAtPath:archivePath]) {
                    [fileManager removeItemAtPath:archivePath error:nil];
                }
                [_opearationsInMemory removeObjectForKey:key];
                break;
        }
    }
}

- (void) dealloc
{
    dispatch_suspend(backendTimer);
    dispatch_suspend(clearExpiredItemTimer);
    
    [self flush];
    
    [_opearationsInMemory removeAllObjects];
}

- (void) write:(CommonNetworkOperation*)operation
{
    dispatch_barrier_async(operationCacheQueue, ^{
        [_opearationsInMemory setObject:[NSArray arrayWithObjects:[NSNumber numberWithInteger:OperationCacheUpdate], operation, nil] forKey:operation.uniqueIdentifier];
    });
}

- (void) remove:(NSString*)forKey
{
    dispatch_barrier_async(operationCacheQueue, ^{
        [_opearationsInMemory setObject:[NSArray arrayWithObjects:[NSNumber numberWithInteger:OperationCacheDelete], nil] forKey:forKey];
    });
}

- (CommonNetworkOperation*) objectForKey:(NSString*)key
{
    __block CommonNetworkOperation* operation = nil;
    
    dispatch_sync(operationCacheQueue, ^{
        NSArray* value = _opearationsInMemory[key];
        if (value) {
            if (value.count > 1)
                operation = [value objectAtIndex:1];
        } else {
            NSString* archivePath = [[_directory path] stringByAppendingPathComponent:key];
            if ([[NSFileManager defaultManager] fileExistsAtPath:archivePath]) {
                operation = [NSKeyedUnarchiver unarchiveObjectWithFile:archivePath];
                if (operation)
                    [_opearationsInMemory setObject:[NSArray arrayWithObjects:[NSNumber numberWithInteger:OperationCacheNone], operation, nil] forKey:key];
            }
        }
    });
    
    return operation;
}

- (void) empty
{
    dispatch_barrier_async(operationCacheQueue, ^{
        [_opearationsInMemory removeAllObjects];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[_directory path]]) {
            [[NSFileManager defaultManager] removeItemAtPath:[_directory path] error:nil];
        }
    });
}

- (NSArray*) restorableOperations
{
    __block NSMutableArray* operations = [NSMutableArray array];
    
    dispatch_sync(operationCacheQueue, ^{
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSDirectoryEnumerator* directoryEnumerator =[fileManager enumeratorAtURL:_directory includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLFileResourceTypeKey, nil] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
        for (NSURL* fileDir in directoryEnumerator) {
            NSString* fileType = nil;
            [fileDir getResourceValue:&fileType forKey:NSURLFileResourceTypeKey error:nil];
            if ([fileType isEqual:NSURLFileResourceTypeRegular]) {
                CommonNetworkOperation* operation = [NSKeyedUnarchiver unarchiveObjectWithFile:[fileDir path]];
                if (operation) {
                    if (operation.isRestorable) {
                        [operations addObject:operation];
                    } else if (operation.state != CommonNetworkOperationStateFinished) {
                        [fileManager removeItemAtPath:[fileDir path] error:nil];
                    }
                }
            }
        }
    });
    
    return operations;
}

- (void)backendUpdate
{
    dispatch_barrier_async(operationCacheQueue, ^{
        [self flush];
    });
}

-(void) clearExpiredItem {
    NSDate* now  = [NSDate date];
    DLog(@"Running clear up of expired items at %@", now);
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHH"];
    NSString* strDate = [formatter stringFromDate:now];
    
    for (CommonNetworkEngine* engine in _sharedEngineArray) {
        if ([engine isReachable]) {
            
            NSFileManager* fileManager = [NSFileManager defaultManager];
            NSDirectoryEnumerator* directoryEnumerator =[fileManager enumeratorAtURL:[NSURL fileURLWithPath:[engine expirationDirectory] isDirectory:YES] includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLFileResourceTypeKey, nil] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
            for (NSURL* subDirectory in directoryEnumerator) {
                NSString* dirType = nil;
                [subDirectory getResourceValue:&dirType forKey:NSURLFileResourceTypeKey error:nil];
                if ([dirType isEqual:NSURLFileResourceTypeDirectory] && [[subDirectory lastPathComponent] compare:strDate] == NSOrderedAscending) {
                    NSDirectoryEnumerator* symFileEnumerator =[fileManager enumeratorAtURL:subDirectory includingPropertiesForKeys:[NSArray arrayWithObject:NSURLFileResourceTypeKey] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
                    for (NSURL* symFile in symFileEnumerator) {
                        NSString* fileType = nil;
                        [symFile getResourceValue:&fileType forKey:NSURLFileResourceTypeKey error:nil];
                        if ([fileType isEqual:NSURLFileResourceTypeSymbolicLink]) {
                            NSString* originalFile = [fileManager destinationOfSymbolicLinkAtPath:[symFile path] error:nil];
                            if ([fileManager fileExistsAtPath:originalFile])
                                [fileManager removeItemAtPath:originalFile error:nil];
                        }
                    }
                    
                    [fileManager removeItemAtPath:[subDirectory path] error:nil];
                }
            }
            
        }
    }
}

@end

@interface CommonNetworkEngine (/*Private Methods*/)

@property (strong, nonatomic) Reachability *reachability;
@property (copy, nonatomic) NSDictionary *customHeaders;
@property (assign, nonatomic) Class customOperationSubclass;

#if OS_OBJECT_USE_OBJC
@property (strong, nonatomic) dispatch_queue_t backgroundCacheQueue;
@property (strong, nonatomic) dispatch_queue_t operationQueue;
#else
@property (assign, nonatomic) dispatch_queue_t backgroundCacheQueue;
@property (assign, nonatomic) dispatch_queue_t operationQueue;
#endif

/*!
 *  @abstract Initializes your network engine with a hostname
 *
 *  @discussion
 *	Creates an engine for a given host name
 *  The hostname parameter is optional
 *  The hostname, if not null, initializes a Reachability notifier.
 *  Network reachability notifications are automatically taken care of by CommonNetworkEngine
 *
 */
- (id) initWithHostName:(NSString*) hostName;

/*!
 *  @abstract Initializes your network engine with a hostname and custom header fields
 *
 *  @discussion
 *	Creates an engine for a given host name
 *  The default headers you specify here will be appened to every operation created in this engine
 *  The hostname, if not null, initializes a Reachability notifier.
 *  Network reachability notifications are automatically taken care of by CommonNetworkEngine
 *  Both parameters are optional
 *
 */
- (id) initWithHostName:(NSString*) hostName customHeaderFields:(NSDictionary*) headers;

/*!
 *  @abstract Initializes your network engine with a hostname
 *
 *  @discussion
 *	Creates an engine for a given host name
 *  The hostname parameter is optional
 *  The apiPath paramter is optional
 *  The apiPath is prefixed to every call to operationWithPath: You can use this method if your server's API location is not at the root (/)
 *  The hostname, if not null, initializes a Reachability notifier.
 *  Network reachability notifications are automatically taken care of by CommonNetworkEngine
 *
 */
- (id) initWithHostName:(NSString*) hostName apiPath:(NSString*) apiPath customHeaderFields:(NSDictionary*) headers;

@end

@implementation CommonNetworkEngine

// Network Queue is a shared singleton object.
// no matter how many instances of CommonNetworkEngine is created, there is one and only one network queue
// In theory an app should contain as many network engines as the number of domains it talks to

#pragma mark -
#pragma mark Initialization

+(void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedNetworkQueue = [[NSOperationQueue alloc] init];
        [_sharedNetworkQueue addObserver:[self self] forKeyPath:@"operationCount" options:0 context:NULL];
        [_sharedNetworkQueue setMaxConcurrentOperationCount:MAX_CONCURRENT_OPERATION_COUNT];
        
        _sharedEngineArray = [[NSMutableArray alloc] init];
    });
}

+ (CommonNetworkEngine *) getObject:(NSString*) hostName {
    NSParameterAssert(hostName);
    
    return [self getObject:hostName apiPath:nil customHeaderFields:nil];
}

+ (CommonNetworkEngine *) getObject:(NSString*) hostName customHeaderFields:(NSDictionary*) headers {
    NSParameterAssert(hostName);
    
    return [self getObject:hostName apiPath:nil customHeaderFields:headers];
}

+ (CommonNetworkEngine *) getObject:(NSString*) hostName apiPath:(NSString*) apiPath customHeaderFields:(NSDictionary*) headers {
    NSParameterAssert(hostName);
    
    __block CommonNetworkEngine* object = nil;
    [_sharedEngineArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CommonNetworkEngine* engine = (CommonNetworkEngine*) obj;
        if ([engine.hostName compare:hostName options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            object = engine;
            *stop = YES;
        }
    }];
    
    if (!object) {
        object = [[CommonNetworkEngine alloc] initWithHostName:hostName apiPath:apiPath customHeaderFields:headers];
        [_sharedEngineArray addObject:object];
    }
    
    return object;
}

+ (void) cancelRequest:(NSURL*) url
{
    for(CommonNetworkOperation *operation in _sharedNetworkQueue.operations) {
        if ([[operation readonlyRequest].URL isEqual:url]) {
            [operation cancel];
            [[self operationCache] remove:[operation uniqueIdentifier]];
            break;
        }
    }
}

+ (BOOL) operationExists:(NSString*) operationId
{
    for(CommonNetworkOperation *op in _sharedNetworkQueue.operations) {
        if ([op.uniqueIdentifier isEqual:operationId]) {
            return YES;
        }
    }
    
    return NO;
}

+ (void) cancelOperation:(CommonNetworkOperation*) operation
{
    for(CommonNetworkOperation *op in _sharedNetworkQueue.operations) {
        if ([op isEqual:operation]) {
            [op removeHandlersFromOperation:operation];
            if (![op hasHandlers]) {
                [op cancel];
                [[self operationCache] remove:[operation uniqueIdentifier]];
            }
        }
    }
}

+ (void) cancelOperationBeneficiary:(id<NSCopying>) beneficiary
{
    for(CommonNetworkOperation *op in _sharedNetworkQueue.operations) {
        [op removeHandlersFromBeneficiary:beneficiary];
        if (![op hasHandlers]) {
            [op cancel];
            [[self operationCache] remove:[op uniqueIdentifier]];
        }
    }
}

- (NSString*) cacheLinksDirectory
{
    NSString* str = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    NSString* strPath=[NSString stringWithFormat:@"%@/%@/Download/%@", str, [[NSBundle mainBundle] bundleIdentifier], self.hostName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:strPath]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:[NSURL fileURLWithPath:strPath isDirectory:YES] withIntermediateDirectories:YES attributes:NULL error:nil];
    }
    return strPath;
}

- (NSString*) expirationDirectory
{
    return [[self cacheLinksDirectory] stringByAppendingPathComponent:@"Expires"];
}

- (NSString*) cacheOnExpirirationDateDirectory:(NSDate*)expirationDate
{
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHH"];
    
    return [[self expirationDirectory] stringByAppendingPathComponent:[formatter stringFromDate:expirationDate]];
}

- (NSString*) eTagsDirectory
{
    return [[self cacheLinksDirectory] stringByAppendingPathComponent:@"ETags"];
}

- (id) init {
    
    return [self initWithHostName:nil];
}

- (id) initWithHostName:(NSString*) hostName {
    
    return [self initWithHostName:hostName apiPath:nil customHeaderFields:nil];
}

- (id) initWithHostName:(NSString*) hostName apiPath:(NSString*) apiPath customHeaderFields:(NSDictionary*) headers {
    
    if((self = [super init])) {
        
        self.apiPath = apiPath;
        //        self.backgroundCacheQueue = dispatch_queue_create("com.mknetworkkit.cachequeue", DISPATCH_QUEUE_SERIAL);
        self.operationQueue = dispatch_queue_create("com.mknetworkkit.operationqueue", DISPATCH_QUEUE_SERIAL);
        
        if(hostName) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(reachabilityChanged:)
                                                         name:kReachabilityChangedNotification
                                                       object:nil];
            
            self.hostName = hostName;
            self.reachability = [Reachability reachabilityWithHostname:self.hostName];
            [self.reachability startNotifier];
        }
        
        if(headers[@"User-Agent"] == nil) {
            
            NSMutableDictionary *newHeadersDict = [headers mutableCopy];
            NSString *userAgentString = [NSString stringWithFormat:@"%@/%@",
                                         [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleNameKey],
                                         [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey]];
            newHeadersDict[@"User-Agent"] = userAgentString;
            self.customHeaders = newHeadersDict;
        } else {
            self.customHeaders = [headers mutableCopy];
        }
        
        self.customOperationSubclass = [CommonNetworkOperation class];
        
    }
    
    return self;
}

- (id) initWithHostName:(NSString*) hostName customHeaderFields:(NSDictionary*) headers {
    
    return [self initWithHostName:hostName apiPath:nil customHeaderFields:headers];
}

-(BOOL) isEqual:(id)object {
    if ([object isKindOfClass:[CommonNetworkEngine class]]) {
        CommonNetworkEngine* anotherObject = (CommonNetworkEngine*) object;
        
        return self.hostName?[self.hostName isEqualToString:anotherObject.hostName]:NO;
    } else if ([object isKindOfClass:[NSString class]]) {
        return self.hostName?[self.hostName isEqualToString:(NSString*)object]:NO;
    }
    
    return NO;
}

-(NSString*)getCachedItem:(CommonNetworkOperation*)operation {
    NSString *cachedPath = [self getNonExpiredItem:operation];
    
    if (!cachedPath)
        cachedPath = [self getEtagCachedItem:operation];
    
    return cachedPath;
}

-(NSString*)getNonExpiredItem:(CommonNetworkOperation*)operation {
    if ([operation.HTTPMethod isEqualToString:@"GET"]) {
        NSString* str = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) objectAtIndex:0];
        NSString* path = [str stringByAppendingPathComponent:operation.uniqueIdentifier];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            return path;
    }
    
    return nil;
}

-(NSString*)getEtagCachedItem:(CommonNetworkOperation*)operation {
    if ([operation.HTTPMethod isEqualToString:@"GET"]) {
        NSString* symFilePath = [[self eTagsDirectory] stringByAppendingPathComponent:operation.uniqueIdentifier];
        NSFileManager *manager = [NSFileManager new];
        
        if ([manager fileExistsAtPath:symFilePath]) {
            NSString* etaggedFilePath = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:symFilePath error:nil];
            
            if (etaggedFilePath && [manager fileExistsAtPath:etaggedFilePath]) {
                return etaggedFilePath;
            } else {
                [manager removeItemAtPath:symFilePath error:nil];
            }
        }
    }
    
    return nil;
}

#pragma mark -
#pragma mark Memory Mangement

-(void) dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
#elif TARGET_OS_MAC
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
#endif
    
    [_sharedEngineArray removeObject:self];
}

+(void) dealloc {
    
    [_sharedNetworkQueue removeObserver:[self self] forKeyPath:@"operationCount"];
    [_sharedEngineArray removeAllObjects];
}

#pragma mark -
#pragma mark KVO for network Queue

+ (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == _sharedNetworkQueue && [keyPath isEqualToString:@"operationCount"]) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kCommonNetworkEngineOperationCountChanged
                                                            object:[NSNumber numberWithInteger:(NSInteger)[_sharedNetworkQueue operationCount]]];
#if TARGET_OS_IPHONE
        [UIApplication sharedApplication].networkActivityIndicatorVisible =
        ([_sharedNetworkQueue.operations count] > 0);
#endif
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object
                               change:change context:context];
    }
}

#pragma mark -
#pragma mark Reachability related

-(void) reachabilityChanged:(NSNotification*) notification
{
    if([self.reachability currentReachabilityStatus] == NotReachable)
    {
        DLog(@"Server [%@] is not reachable", self.hostName);
        
        [self freezeOperations];
    }
    
    if(self.reachabilityChangedHandler) {
        self.reachabilityChangedHandler([self.reachability currentReachabilityStatus]);
    }
}

#pragma mark Freezing operations (Called when network connectivity fails)
-(void) freezeOperations {
    
    for(CommonNetworkOperation *operation in _sharedNetworkQueue.operations) {
        
        if(!self.hostName) return;
        
        // freeze only operations that belong to this server
        if([[[operation url] absoluteString] rangeOfString:self.hostName].location == NSNotFound) continue;
        
        [operation operationFailedWithError:[NSError errorWithDomain:NSURLErrorDomain code:-1004 userInfo:nil]];
        [operation stop];
    }
}

-(void) checkAndRestoreFrozenOperations {
    NSArray* operations = [[CommonNetworkEngine operationCache] restorableOperations];
    NSMutableArray* toBeAdded = [NSMutableArray array];
    
    for (CommonNetworkOperation* operation in operations) {
        NSUInteger index = [_sharedNetworkQueue.operations indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            CommonNetworkOperation* item = (CommonNetworkOperation*) obj;
            return [item.uniqueIdentifier isEqualToString:operation.uniqueIdentifier];
        }];
        
        if(index == NSNotFound) {
            [toBeAdded addObject:operation];
        }
    }
    
    for (CommonNetworkOperation* operation in toBeAdded) {
        [_sharedNetworkQueue addOperation:operation];
    }
}

-(NSString*) readonlyHostName {
    
    return [_hostName copy];
}

-(BOOL) isReachable {
    
    return ([self.reachability currentReachabilityStatus] != NotReachable);
}

#pragma mark -
#pragma mark Create methods

-(void) registerOperationSubclass:(Class) aClass {
    
    self.customOperationSubclass = aClass;
}

-(CommonNetworkOperation*) operationWithPath:(NSString*) path {
    
    return [self operationWithPath:path params:nil];
}

-(CommonNetworkOperation*) operationWithPath:(NSString*) path beneficiary:(id<NSCopying>)beneficiary {
    
    return [self operationWithPath:path params:nil beneficiary:beneficiary];
}

-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body {
    
    return [self operationWithPath:path
                            params:body
                        httpMethod:@"GET"];
}

-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body beneficiary:(id<NSCopying>)beneficiary {
    
    return [self operationWithPath:path
                            params:body
                        httpMethod:@"GET"
                       beneficiary:beneficiary];
}

-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body
                              httpMethod:(NSString*)method  {
    
    return [self operationWithPath:path params:body httpMethod:method ssl:NO];
}

-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body
                              httpMethod:(NSString*)method beneficiary:(id<NSCopying>)beneficiary  {
    
    return [self operationWithPath:path params:body httpMethod:method ssl:NO beneficiary:beneficiary];
}

-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body
                              httpMethod:(NSString*)method
                                     ssl:(BOOL) useSSL {
    return [self operationWithPath:path params:body httpMethod:method ssl:useSSL beneficiary:nil];
}

-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body
                              httpMethod:(NSString*)method
                                     ssl:(BOOL) useSSL  beneficiary:(id<NSCopying>)beneficiary {
    if(self.hostName == nil) {
        
        DLog(@"Hostname is nil, use operationWithURLString: method to create absolute URL operations");
        return nil;
    }
    
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@://%@", useSSL ? @"https" : @"http", self.hostName];
    
    if(self.portNumber != 0)
        [urlString appendFormat:@":%d", self.portNumber];
    
    if(self.apiPath)
        [urlString appendFormat:@"/%@", self.apiPath];
    
    [urlString appendFormat:@"/%@", path];
    
    return [self operationWithURLString:urlString params:body httpMethod:method beneficiary:beneficiary];
}

-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString {
    
    return [self operationWithURLString:urlString params:nil httpMethod:@"GET"];
}

-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString beneficiary:(id<NSCopying>)beneficiary {
    
    return [self operationWithURLString:urlString params:nil httpMethod:@"GET" beneficiary:beneficiary];
}

-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString
                                       params:(NSDictionary*) body {
    
    return [self operationWithURLString:urlString params:body httpMethod:@"GET"];
}

-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString
                                       params:(NSDictionary*) body beneficiary:(id<NSCopying>)beneficiary {
    
    return [self operationWithURLString:urlString params:body httpMethod:@"GET" beneficiary:beneficiary];
}

-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString
                                       params:(NSDictionary*) body
                                   httpMethod:(NSString*)method {
    return [self operationWithURLString:urlString params:body httpMethod:method beneficiary:nil];
}

-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString
                                       params:(NSDictionary*) body
                                   httpMethod:(NSString*)method beneficiary:(id<NSCopying>)beneficiary {
    
    CommonNetworkOperation *operation = [[self.customOperationSubclass alloc] initWithURLString:urlString params:body httpMethod:method beneficiary:beneficiary];
    
    [self prepareHeaders:operation];
    
    return operation;
}

-(void) prepareHeaders:(CommonNetworkOperation*) operation {
    
    [operation addHeaders:self.customHeaders];
}

-(void) enqueueOperation:(CommonNetworkOperation*) operation {
    
    [self enqueueOperation:operation forceReload:NO];
}

-(void) setHandlers:(CommonNetworkOperation*) operation
{
    [operation setCacheHandler:^(CommonNetworkOperation* operation) {
        //        dispatch_async(self.backgroundCacheQueue, ^{
        if ([operation.HTTPMethod isEqualToString:@"GET"] && operation.isCacheable) {
            NSDate* expiresOnDate = [operation expiresOnDate];
            NSString* etag = [[operation.readonlyResponse allHeaderFields] objectForKey:@"etag"];
            etag = [etag stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            NSString* str = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) objectAtIndex:0];
            
            if (expiresOnDate) {
                NSString* cachedFilePath = [str stringByAppendingPathComponent:operation.uniqueIdentifier];
                if (![operation hasFileToBeSaved]) {
                    [[operation responseData] writeToFile:cachedFilePath atomically:YES];
                }
                [self classifySymbolicFileOnExpirationDate:expiresOnDate originalFile:cachedFilePath];
            } else if (etag) {
                NSString* etaggedFilePath = [str stringByAppendingPathComponent:[NSString stringWithFormat:@"e-%@.tag", etag]];
                if (![operation hasFileToBeSaved]) {
                    [[operation responseData] writeToFile:etaggedFilePath atomically:YES];
                }
                [self classifySymbolicFileOnETag:etag uniqueIdentifier:operation.uniqueIdentifier originalFile:etaggedFilePath];
            }
            
            operation.cachedItemPath = [self getCachedItem:operation];
        }
        
        
        if (operation.isPersistable) {
            NSString *uniqueId = [operation uniqueIdentifier];
            if (!operation.isTraceable && operation.state == CommonNetworkOperationStateFinished) {
                [[CommonNetworkEngine operationCache] remove:uniqueId];
                return;
            }
            [[CommonNetworkEngine operationCache] write:operation];
        }
        //        });
    }];
    
    [operation setCancelHandler:^(CommonNetworkOperation* operation) {
        //        dispatch_async(self.backgroundCacheQueue, ^{
        NSString *uniqueId = [operation uniqueIdentifier];
        [[CommonNetworkEngine operationCache] remove:uniqueId];
        //        });
    }];
    
    if ([operation.HTTPMethod isEqualToString:@"GET"]) {
        [operation onDownloadProgressChanged:^(double progress) {
            //            dispatch_async(self.backgroundCacheQueue, ^{
            if (operation.isPersistable)
                [[CommonNetworkEngine operationCache] write:operation];
            //            });
        }];
    } else if([operation.HTTPMethod isEqualToString:@"POST"])
        [operation onUploadProgressChanged:^(double progress) {
            //            dispatch_async(self.backgroundCacheQueue, ^{
            if (operation.isPersistable)
                [[CommonNetworkEngine operationCache] write:operation];
            //            });
        }];
}

-(void) removeCachedItem:(CommonNetworkOperation*)operation
{
    NSString *cachedItemPath = [self getCachedItem:operation];
    NSFileManager *manager = [NSFileManager new];
    if ([manager fileExistsAtPath:cachedItemPath]) {
        [manager removeItemAtPath:cachedItemPath error:nil];
    }
    
    NSString* strPath=[[self eTagsDirectory] stringByAppendingPathComponent:operation.uniqueIdentifier];
    if ([manager fileExistsAtPath:strPath]) {
        [manager removeItemAtPath:strPath error:nil];
    }
}

-(void) enqueueOperation:(CommonNetworkOperation*) operation forceReload:(BOOL) forceReload {
    
    NSParameterAssert(operation != nil);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        CommonNetworkOperation* newOperation = operation;
        [self setHandlers:newOperation];
        
        NSString *uniqueId = [newOperation uniqueIdentifier];
        
        if(!forceReload) {
            operation.cachedItemPath = [self getCachedItem:operation];
            
            NSString* nonExpiredItemPath = [self getNonExpiredItem:newOperation];
            if (nonExpiredItemPath && [[NSFileManager defaultManager] fileExistsAtPath:nonExpiredItemPath]) {
                [newOperation operationSucceeded];
                return;
            }
            
            CommonNetworkOperation* cachedOperation = (CommonNetworkOperation*)[[CommonNetworkEngine operationCache] objectForKey:uniqueId];
            
            if (cachedOperation) {
                if (cachedOperation.state == CommonNetworkOperationStateFinished) {
                    [newOperation setCacheHandler:nil];
                    [newOperation operationSucceeded];
                    return;
                } else {
                    [newOperation updateOperationBasedOnPreviousOperation:cachedOperation];
                }
            }
        } else {
            [self removeCachedItem:newOperation];
            [[CommonNetworkEngine operationCache] remove:uniqueId];
        }
        
        dispatch_sync(self.operationQueue, ^{
            
            NSArray *operations = _sharedNetworkQueue.operations;
            NSUInteger index = [operations indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                CommonNetworkOperation* item = (CommonNetworkOperation*) obj;
                return [item.uniqueIdentifier isEqualToString:uniqueId];
            }];
            
            if(index != NSNotFound) {
                
                CommonNetworkOperation *queuedOperation = (CommonNetworkOperation*) (operations)[index];
                
                [queuedOperation updateHandlersFromOperation:newOperation];
                if(queuedOperation.state == CommonNetworkOperationStateFinished) {
                    [newOperation setCancelHandler:nil];
                    [newOperation operationSucceeded];
                }
                
                return;
            }
            
            if(newOperation.state != CommonNetworkOperationStateFinished || forceReload) {
                newOperation.state = CommonNetworkOperationStateReady;
                if (!forceReload) {
                    NSString* etaggedFilePath = [self getEtagCachedItem:newOperation];
                    if (etaggedFilePath && [[NSFileManager defaultManager] fileExistsAtPath:etaggedFilePath]) {
                        newOperation.etag = [[etaggedFilePath stringByDeletingPathExtension] lastPathComponent];
                        newOperation.etag = [[etaggedFilePath stringByDeletingPathExtension] lastPathComponent];
                        
                        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^e-(.+)" options:NSRegularExpressionCaseInsensitive error:nil];
                        NSArray *matcheRanges = [regex matchesInString:newOperation.etag options:0 range:NSMakeRange(0, newOperation.etag.length)];
                        if (matcheRanges && matcheRanges.count) {
                            NSTextCheckingResult *regResult = [matcheRanges objectAtIndex:0];
                            newOperation.etag = [newOperation.etag substringWithRange:[regResult rangeAtIndex:1]];
                        }
                    }
                }
                [_sharedNetworkQueue addOperation:newOperation];
            }
        });
        
        if([self.reachability currentReachabilityStatus] == NotReachable)
            [self freezeOperations];
    });
}

#if TARGET_OS_IPHONE

- (CommonNetworkOperation*)fileAtURL:(NSURL *)url completionHandler:(NKUrlBlock) fileFetchedBlock errorHandler:(NKErrorBlock) errorBlock {
    return [self fileAtURL:url completionHandler:fileFetchedBlock errorHandler:errorBlock beneficiary:nil];
}

- (CommonNetworkOperation*)fileAtURL:(NSURL *)url completionHandler:(NKUrlBlock) fileFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary {
    return [self fileAtURL:url completionHandler:fileFetchedBlock errorHandler:errorBlock beneficiary:beneficiary startImmediately:YES];
}

- (CommonNetworkOperation*)fileAtURL:(NSURL *)url completionHandler:(NKUrlBlock) fileFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary startImmediately:(BOOL)startImmediately {
    if (url == nil) {
        return nil;
    }
    
    CommonNetworkOperation *op = [self operationWithURLString:[url absoluteString] beneficiary:beneficiary];
    op.isCacheable = YES;
    
    NSString* cachedFilePath = [self getCachedItem:op];
    
    if (cachedFilePath && [[NSFileManager defaultManager] fileExistsAtPath:cachedFilePath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            fileFetchedBlock([NSURL fileURLWithPath:cachedFilePath]);
        });
        
        return nil;
    }
    
    [op addCompletionHandler:^(CommonNetworkOperation *completedOperation) {
        fileFetchedBlock([NSURL fileURLWithPath:completedOperation.cachedItemPath]);
        
    } errorHandler:^(CommonNetworkOperation *completedOperation, NSString* prevResponsePath, NSError *error) {
        
        errorBlock(completedOperation, prevResponsePath, error);
    }];
    
    if (startImmediately)
        [self enqueueOperation:op forceReload:NO];
    
    return op;
}

- (CommonNetworkOperation*)imageAtURL:(NSURL *)url completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock {
    return [self imageAtURL:url completionHandler:imageFetchedBlock errorHandler:errorBlock beneficiary:nil];
}

- (CommonNetworkOperation*)imageAtURL:(NSURL *)url completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary {
    return [self imageAtURL:url completionHandler:imageFetchedBlock errorHandler:errorBlock beneficiary:beneficiary startImmediately:YES];
}

- (CommonNetworkOperation*)imageAtURL:(NSURL *)url completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary startImmediately:(BOOL)startImmediately {
    if (url == nil) {
        return nil;
    }
    
    CommonNetworkOperation *op = [self operationWithURLString:[url absoluteString] beneficiary:beneficiary];
    op.isCacheable = YES;
    
    NSString* str = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    NSString* cachedFilePath = [str stringByAppendingPathComponent:op.uniqueIdentifier];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachedFilePath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            imageFetchedBlock([UIImage imageWithContentsOfFile:cachedFilePath],
                              url);
        });
        
        return nil;
    }
    
    [op addCompletionHandler:^(CommonNetworkOperation *completedOperation) {
        imageFetchedBlock([completedOperation responseImage],
                          url);
        
    } errorHandler:^(CommonNetworkOperation *completedOperation, NSString* prevResponsePath, NSError *error) {
        
        errorBlock(completedOperation, prevResponsePath, error);
    }];
    
    if (startImmediately)
        [self enqueueOperation:op forceReload:NO];
    
    return op;
}

- (CommonNetworkOperation*)imageAtURL:(NSURL *)url size:(CGSize) size completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock {
    return [self imageAtURL:url size:size completionHandler:imageFetchedBlock errorHandler:errorBlock beneficiary:nil];
}

- (CommonNetworkOperation*)imageAtURL:(NSURL *)url size:(CGSize) size completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary {
    if (url == nil) {
        return nil;
    }
    
    CommonNetworkOperation *op = [self operationWithURLString:[url absoluteString] beneficiary:beneficiary];
    op.isCacheable = YES;
    
    NSString* str = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    NSString* cachedFilePath = [str stringByAppendingPathComponent:op.uniqueIdentifier];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachedFilePath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            imageFetchedBlock([UIImage imageWithContentsOfFile:cachedFilePath],
                              url);
        });
        return nil;
    }
    
    [op setFileToBeSaved:[NSURL fileURLWithPath:cachedFilePath]];
    
    [op addCompletionHandler:^(CommonNetworkOperation *completedOperation) {
        [completedOperation decompressedResponseImageOfSize:size
                                          completionHandler:^(UIImage *decompressedImage) {
                                              
                                              imageFetchedBlock(decompressedImage,
                                                                url);
                                          }];
    } errorHandler:^(CommonNetworkOperation *completedOperation, NSString* prevResponsePath, NSError *error) {
        
        errorBlock(completedOperation, prevResponsePath, error);
        DLog(@"%@", error);
    }];
    
    [self enqueueOperation:op forceReload:NO];
    
    return op;
    
}

- (CommonNetworkOperation*)imageAtURL:(NSURL *)url size:(CGSize) size onCompletion:(NKImageBlock) imageFetchedBlock {
    
    return [self imageAtURL:url size:size completionHandler:imageFetchedBlock errorHandler:^(CommonNetworkOperation* op, NSString* prevResponsePath, NSError* error){}];
}

#endif

- (CommonNetworkOperation*)imageAtURL:(NSURL *)url onCompletion:(NKImageBlock) imageFetchedBlock
{
    return [self imageAtURL:url completionHandler:imageFetchedBlock errorHandler:^(CommonNetworkOperation* op, NSString* prevResponsePath, NSError* error){}];
}

- (void)classifySymbolicFileOnExpirationDate:(NSDate*)expirationDate originalFile:(NSString*) originalFile
{
    NSFileManager *manager = [NSFileManager new];
    
    if ([manager fileExistsAtPath:originalFile]) {
        if (expirationDate) {
            NSString* strPath=[self cacheOnExpirirationDateDirectory:expirationDate];
            NSURL* dataDirectory = [NSURL fileURLWithPath:strPath isDirectory:YES];
            
            if (![manager fileExistsAtPath:[dataDirectory path]]) {
                NSError* error = NULL;
                [manager createDirectoryAtURL:dataDirectory withIntermediateDirectories:YES attributes:NULL error:&error];
                if (error && error.code) {
                    DLog(@"ERROR: Error occurred while creating folder and its ancestors at path %@ :%@", [dataDirectory path], error.description);
                    return;
                }
            }
            
            NSString* symPath = [strPath stringByAppendingPathComponent:[originalFile lastPathComponent]];
            if ([manager fileExistsAtPath:symPath]) {
                [manager removeItemAtPath:symPath error:nil];
            }
            
            [manager createSymbolicLinkAtPath:symPath withDestinationPath:originalFile error:nil];
        }
    }
}

- (void)classifySymbolicFileOnETag:(NSString*)etag uniqueIdentifier:(NSString*)uniqueIdentifier originalFile:(NSString*) originalFile
{
    NSFileManager *manager = [NSFileManager new];
    
    if ([manager fileExistsAtPath:originalFile]) {
        if (etag) {
            NSString* strPath=[self eTagsDirectory];
            NSURL* dataDirectory = [NSURL fileURLWithPath:strPath isDirectory:YES];
            
            if (![manager fileExistsAtPath:[dataDirectory path]]) {
                NSError* error = NULL;
                [manager createDirectoryAtURL:dataDirectory withIntermediateDirectories:YES attributes:NULL error:&error];
                if (error && error.code) {
                    DLog(@"ERROR: Error occurred while creating folder and its ancestors at path %@ :%@", [dataDirectory path], error.description);
                    return;
                }
            }
            
            NSString* symPath = [strPath stringByAppendingPathComponent:uniqueIdentifier];
            
            if ([manager fileExistsAtPath:symPath]) {
                [manager removeItemAtPath:symPath error:nil];
            }
            [[NSFileManager defaultManager] createSymbolicLinkAtPath:symPath withDestinationPath:originalFile error:nil];
        }
    }
}

#pragma mark -
#pragma mark Cache related
+(OperationCache*) operationCache {
    static OperationCache* c = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        c = [[OperationCache alloc] initWithLocation:@"CommonNetworkEngine.Operation"];
    });
    
    return c;
}

+(void) emptyCache {
    [[CommonNetworkEngine operationCache] empty];
}

-(int) cacheMemoryCost {
    
    return MKNETWORKCACHE_DEFAULT_COST;
}

-(void) saveCache {
}

-(void) useCache {
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveCache)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveCache)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveCache)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
#elif TARGET_OS_MAC
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveCache)
                                                 name:NSApplicationWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveCache)
                                                 name:NSApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveCache)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
    
#endif
}

@end

