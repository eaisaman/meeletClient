//
//  CommonNetworkOperation.m
//  MeeletClient
//
//  Created by jill on 15/5/25.
//
//

#import <Foundation/Foundation.h>
#import "CommonNetworkKit.h"
#import "SecurityContext.h"
#import "LogMacro.h"

#ifdef __OBJC_GC__
#error CommonNetworkKit does not support Objective-C Garbage Collection
#endif

#if ! __has_feature(objc_arc)
#error CommonNetworkKit is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

@implementation OperationRecord

@synthesize identifier, owner, status, isTraceable, isPersistable, isRestorable, url, httpMethod, parameters, headers, userName, password, authType, stringEncoding, clientCertificate, credentialPersistence, unitCompleted, unitTotal, uploadSizePerRequest, prop1, prop2, prop3, prop4, others, createDateTime, modDateTime, boundary, postDataEncoding;

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.owner forKey:@"owner"];
    [aCoder encodeInteger:(NSInteger)self.status forKey:@"status"];
    [aCoder encodeBool:self.isTraceable forKey:@"isTraceable"];
    [aCoder encodeBool:self.isPersistable forKey:@"isPersistable"];
    [aCoder encodeBool:self.isRestorable forKey:@"isRestorable"];
    [aCoder encodeBool:self.isCacheable forKey:@"isCacheable"];
    [aCoder encodeObject:self.url forKey:@"url"];
    [aCoder encodeObject:self.httpMethod forKey:@"httpMethod"];
    [aCoder encodeObject:self.parameters forKey:@"parameters"];
    [aCoder encodeObject:self.headers forKey:@"headers"];
    [aCoder encodeObject:self.userName forKey:@"userName"];
    [aCoder encodeObject:self.password forKey:@"password"];
    [aCoder encodeInteger:(NSInteger)self.authType forKey:@"authType"];
    [aCoder encodeInteger:(NSInteger)self.stringEncoding forKey:@"stringEncoding"];
    [aCoder encodeObject:self.clientCertificate forKey:@"clientCertificate"];
    [aCoder encodeInteger:(NSInteger)self.credentialPersistence forKey:@"credentialPersistence"];
    [aCoder encodeInteger:self.unitCompleted forKey:@"unitCompleted"];
    [aCoder encodeInteger:self.unitTotal forKey:@"unitTotal"];
    [aCoder encodeObject:self.prop1 forKey:@"prop1"];
    [aCoder encodeObject:self.prop2 forKey:@"prop2"];
    [aCoder encodeObject:self.prop3 forKey:@"prop3"];
    [aCoder encodeObject:self.prop4 forKey:@"prop4"];
    [aCoder encodeObject:self.others forKey:@"others"];
    [aCoder encodeObject:self.createDateTime forKey:@"createDateTime"];
    [aCoder encodeObject:self.modDateTime forKey:@"modDateTime"];
    [aCoder encodeObject:self.boundary forKey:@"boundary"];
    [aCoder encodeInteger:self.postDataEncoding forKey:@"postDataEncoding"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.identifier = (NSString*)[aDecoder decodeObjectForKey:@"identifier"];
        self.owner = (NSString*)[aDecoder decodeObjectForKey:@"owner"];
        self.status = (CommonNetworkOperationState)[aDecoder decodeIntegerForKey:@"status"];
        self.isTraceable = [aDecoder decodeBoolForKey:@"isTraceable"];
        self.isPersistable = [aDecoder decodeBoolForKey:@"isPersistable"];
        self.isRestorable = [aDecoder decodeBoolForKey:@"isRestorable"];
        self.isCacheable = [aDecoder decodeBoolForKey:@"isCacheable"];
        self.url = (NSURL*)[aDecoder decodeObjectForKey:@"url"];
        self.httpMethod = (NSString*)[aDecoder decodeObjectForKey:@"httpMethod"];
        self.parameters = (NSDictionary*)[aDecoder decodeObjectForKey:@"parameters"];
        self.headers = (NSDictionary*)[aDecoder decodeObjectForKey:@"headers"];
        self.userName = (NSString*)[aDecoder decodeObjectForKey:@"userName"];
        self.password = (NSString*)[aDecoder decodeObjectForKey:@"password"];
        self.authType = (HTTPAuthType)[aDecoder decodeIntegerForKey:@"authType"];
        [self setStringEncoding:(NSStringEncoding)[aDecoder decodeIntegerForKey:@"stringEncoding"]];
        self.clientCertificate = (NSString*)[aDecoder decodeObjectForKey:@"clientCertificate"];
        self.credentialPersistence = (NSURLCredentialPersistence)[aDecoder decodeIntegerForKey:@"credentialPersistence"];
        self.unitCompleted = [aDecoder decodeIntegerForKey:@"unitCompleted"];
        self.unitTotal = [aDecoder decodeIntegerForKey:@"unitTotal"];
        self.prop1 = (NSString*)[aDecoder decodeObjectForKey:@"prop1"];
        self.prop2 = (NSString*)[aDecoder decodeObjectForKey:@"prop2"];
        self.prop3 = (NSString*)[aDecoder decodeObjectForKey:@"prop3"];
        self.prop4 = (NSString*)[aDecoder decodeObjectForKey:@"prop4"];
        self.others = [aDecoder decodeObjectForKey:@"others"];
        self.createDateTime = (NSDate*)[aDecoder decodeObjectForKey:@"createDateTime"];
        self.modDateTime = (NSDate*)[aDecoder decodeObjectForKey:@"modDateTime"];
        self.boundary= (NSString*)[aDecoder decodeObjectForKey:@"boundary"];
        self.postDataEncoding = [aDecoder decodeIntegerForKey:@"postDataEncoding"];
    }
    
    return self;
}

-(BOOL) isEqual:(id)object {
    if ([object isKindOfClass:[OperationRecord class]]) {
        OperationRecord *anotherObject = (OperationRecord*) object;
        return [self.identifier isEqualToString:anotherObject.identifier];
    }
    
    return NO;
}

@end

@interface CommonNetworkOperation (/*Private Methods*/) {
@private
    NSString* _uniqueId;
    int _state;
    NSMutableData * _cachedResponse;
    NSUInteger _actualDataLength;
}

@property (strong, nonatomic) NSURLConnection *connection;
@property (strong, nonatomic) NSMutableURLRequest *request;
@property (strong, nonatomic) NSHTTPURLResponse *response;
@property (strong, nonatomic) NSMutableDictionary *responseHeaders;

@property (strong, nonatomic) NSMutableArray *filesToBePosted;

@property (copy, nonatomic) NSString *username;
@property (copy, nonatomic) NSString *password;
@property (assign, nonatomic) HTTPAuthType authType;

@property (nonatomic, strong) NSMutableDictionary *responseBlocks;
@property (nonatomic, strong) NSMutableDictionary *errorBlocks;

// For method POST's use
@property (nonatomic, strong) NSMutableDictionary *uploadProgressChangedHandlers;

// For method GET's use
@property (nonatomic, strong) NSMutableDictionary *downloadProgressChangedHandlers;
@property (nonatomic, strong) NSMutableDictionary* filesToBeSaved;

@property (nonatomic, copy) NKCacheBlock cacheHandlingBlock;

@property (nonatomic, copy) NKCancelBlock cancelHandlingBlock;

#if TARGET_OS_IPHONE
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskId;
#endif

@property (strong, nonatomic) NSError *error;

@property (strong, nonatomic, readonly) OperationRecord* operationRecord;

@property (strong, nonatomic) NSMutableDictionary *requestParameters;

- (id)initWithURLString:(NSString *)aURLString
                 params:(NSDictionary *)body
             httpMethod:(NSString *)method beneficiary:(id<NSCopying>)beneficiary;

-(NSData*) bodyData;

-(NSString*) encodedPostDataString;
- (void) showLocalNotification;

@end

@implementation CommonNetworkOperation

static NSURL* downloadTempDirectory;

+(void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self getDownloadTempDirectory];
    });
}

+(NSURL*) getDownloadTempDirectory {
    if (!downloadTempDirectory) {
        NSString* str = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) objectAtIndex:0];
        NSURL* tempUrl = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:str, [[NSBundle mainBundle] bundleIdentifier], @"Temp", nil]];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[tempUrl path]]) {
            NSError* error = NULL;
            [[NSFileManager defaultManager] createDirectoryAtURL:tempUrl withIntermediateDirectories:YES attributes:NULL error:&error];
            if (error && error.code) {
                NSException* e = [[NSException alloc] initWithName:@"COMMONS" reason:[NSString stringWithFormat:@"ERROR: Error occurred while creating folder and its ancestors at path %@ :%@", [tempUrl path], error.description] userInfo:NULL];
                @throw e;
            }
        }
        
        downloadTempDirectory = tempUrl;
    }
    
    
    return downloadTempDirectory;
}

+(NSString*) formatDateString:(NSDate*) date
{
    static NSDateFormatter* formatter = nil;
    static NSRegularExpression *regex = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];

        regex = [NSRegularExpression regularExpressionWithPattern:@"GMT([-|+][0-9]{2})[:]?([0-9]{2})$" options:NSRegularExpressionCaseInsensitive error:nil];
    });
    
    NSString* timeStr = [formatter stringFromDate:date];
    timeStr = [[regex stringByReplacingMatchesInString:timeStr options:0 range:NSMakeRange(0, timeStr.length) withTemplate:@"$1:$2"] mutableCopy];
    
    return timeStr;
}

- (OperationRecord*) operationRecord {
    OperationRecord* record = [[OperationRecord alloc] init];
    
    record.identifier = self.uniqueIdentifier;
    record.owner = [SecurityContext getObject].details.loginName;
    record.status = self.state;
    record.unitCompleted = self.unitCompleted;
    record.unitTotal = self.unitTotal;
    record.uploadSizePerRequest = self.uploadSizePerRequest;
    record.url = self.url;
    record.httpMethod = self.request.HTTPMethod;
    record.userName = self.username;
    record.password = self.password;
    record.authType = self.authType;
    record.headers = self.requestHeaders;
    record.parameters = self.requestParameters;
    record.stringEncoding = self.stringEncoding;
    record.clientCertificate = self.clientCertificate;
    record.credentialPersistence = self.credentialPersistence;
    record.boundary = self.boundary;
    record.postDataEncoding = self.postDataEncoding;
    
    NSDate* now = [NSDate date];
    record.createDateTime = now;
    record.modDateTime = now;
    
    return record;
}

- (id)getBeneficiary
{
    return _beneficiary?_beneficiary:[[NSBundle mainBundle] bundleIdentifier];
}

-(void) removeHandlersFromBeneficiary:(id<NSCopying>)beneficiary
{
    [self.responseBlocks removeObjectForKey:beneficiary];
    [self.errorBlocks removeObjectForKey:beneficiary];
    [self.uploadProgressChangedHandlers removeObjectForKey:beneficiary];
    [self.downloadProgressChangedHandlers removeObjectForKey:beneficiary];
    [self.filesToBeSaved removeObjectForKey:beneficiary];
}

- (NSMutableArray*)handlersForKey:(NSMutableDictionary*)dict key:(id)key
{
    NSMutableArray* handlers = [dict objectForKey:key];
    if (!handlers) {
        handlers = [NSMutableArray array];
        [dict setObject:handlers forKey:key];
    }
    
    return handlers;
}

//===========================================================
// + (BOOL)automaticallyNotifiesObserversForKey:
//
//===========================================================
+ (BOOL)automaticallyNotifiesObserversForKey: (NSString *)theKey
{
    BOOL automatic;
    
    if ([theKey isEqualToString:@"postDataEncoding"]) {
        automatic = NO;
    } else {
        automatic = [super automaticallyNotifiesObserversForKey:theKey];
    }
    
    return automatic;
}

//===========================================================
//  postDataEncoding
//===========================================================

- (void)setPostDataEncoding:(NKPostDataEncodingType)aPostDataEncoding
{
    _postDataEncoding = aPostDataEncoding;
    
    NSString *charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(self.stringEncoding));
    
    switch (self.postDataEncoding) {
            
        case NKPostDataEncodingTypeURL: {
            [self addHeaders:@{@"Content-Type":[NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset]}];
        }
            break;
        case NKPostDataEncodingTypeJSON: {
            [self addHeaders:@{@"Content-Type":[NSString stringWithFormat:@"application/json; charset=%@", charset]}];
        }
            break;
        case NKPostDataEncodingTypeForm: {
            [self addHeaders:@{@"Content-Type":[NSString stringWithFormat:@"multipart/form-data; charset=%@; boundary=%@", charset, self.boundary]}];
        }
            break;
        case NKPostDataEncodingTypePlist: {
            [self addHeaders:@{@"Content-Type":[NSString stringWithFormat:@"application/x-plist; charset=%@", charset]}];
        }
            
        default:
            break;
    }
}

-(NSString*) encodedPostDataString {
    
    NSString *returnValue = @"";
    
    if(self.postDataEncoding == NKPostDataEncodingTypeURL)
        returnValue = [self.requestParameters urlEncodedKeyValueString];
    else if(self.postDataEncoding == NKPostDataEncodingTypeJSON)
        returnValue = [self.requestParameters jsonEncodedKeyValueString];
    else if(self.postDataEncoding == NKPostDataEncodingTypePlist)
        returnValue = [self.requestParameters plistEncodedKeyValueString];
    return returnValue;
}

-(NSURL*) url {
    
    return [self.request URL];
}

-(NSURLRequest*) readonlyRequest {
    
    return [self.request copy];
}

-(NSHTTPURLResponse*) readonlyResponse {
    
    return [self.response copy];
}

- (NSDictionary *) readonlyPostDictionary {
    
    return [self.requestParameters copy];
}

-(NSString*) HTTPMethod {
    
    return self.request.HTTPMethod;
}

-(NSInteger) HTTPStatusCode {
    
    if(self.response)
        return self.response.statusCode;
    else
        return 0;
}

-(BOOL) isEqual:(id)object {
    
    if([self.request.HTTPMethod isEqualToString:@"GET"] || [self.request.HTTPMethod isEqualToString:@"HEAD"]) {
        
        CommonNetworkOperation *anotherObject = (CommonNetworkOperation*) object;
        return ([[self uniqueIdentifier] isEqualToString:[anotherObject uniqueIdentifier]]);
    }
    
    return NO;
}

-(NSString*) uniqueIdentifier {
    if (_uniqueId)
        return _uniqueId;
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@ %@", self.request.HTTPMethod, self.url];
    
    if (self.requestParameters && self.requestParameters.count)
        [str appendFormat:@"?%@", [self.requestParameters urlEncodedKeyValueString]];
    
    if (self.filesToBePosted && self.filesToBePosted.count)
        [str appendString:[self.filesToBePosted componentsJoinedByString:@","]];
    
    if(self.username || self.password) {
        
        [str appendFormat:@" [%@:%@]",
         self.username ? self.username : @"",
         self.password ? self.password : @""];
    }
    
    _uniqueId = [str md5];
    return _uniqueId;
}

-(CommonNetworkOperationState) state {
    
    return (CommonNetworkOperationState)_state;
}

-(void) setState:(CommonNetworkOperationState)newState {
    
    switch (newState) {
        case CommonNetworkOperationStateReady:
            [self willChangeValueForKey:@"isReady"];
            break;
        case CommonNetworkOperationStateExecuting:
            [self willChangeValueForKey:@"isReady"];
            [self willChangeValueForKey:@"isExecuting"];
            break;
        case CommonNetworkOperationStateFinished:
            [self willChangeValueForKey:@"isExecuting"];
            [self willChangeValueForKey:@"isFinished"];
            break;
        case CommonNetworkOperationStateStopped:
            [self willChangeValueForKey:@"isExecuting"];
            [self willChangeValueForKey:@"isFinished"];
            break;
        case CommonNetworkOperationStateCancelled:
            [self willChangeValueForKey:@"isExecuting"];
            [self willChangeValueForKey:@"isFinished"];
            break;
    }
    
    _state = newState;
    
    switch (newState) {
        case CommonNetworkOperationStateReady:
            [self didChangeValueForKey:@"isReady"];
            break;
        case CommonNetworkOperationStateExecuting:
            [self didChangeValueForKey:@"isReady"];
            [self didChangeValueForKey:@"isExecuting"];
            break;
        case CommonNetworkOperationStateFinished:
            [self didChangeValueForKey:@"isExecuting"];
            [self didChangeValueForKey:@"isFinished"];
            break;
        case CommonNetworkOperationStateStopped:
            [self didChangeValueForKey:@"isExecuting"];
            [self didChangeValueForKey:@"isFinished"];
            break;
        case CommonNetworkOperationStateCancelled:
            [self didChangeValueForKey:@"isExecuting"];
            [self didChangeValueForKey:@"isFinished"];
            break;
    }
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.operationRecord forKey:@"operationRecord"];
    
    [encoder encodeObject:self.filesToBeSaved forKey:@"filesToBeSaved"];
    [encoder encodeObject:self.filesToBePosted forKey:@"filesToBePosted"];
}

- (void)createConnectionFromRequest:(NSMutableURLRequest*) request
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURLConnection* prevConnection = self.connection;
        self.connection = nil;
        
        if (prevConnection) {
            [prevConnection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            [prevConnection cancel];
        }
        
        [self.requestHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [request setValue:(NSString*) obj forHTTPHeaderField:key];
        }];
        
        if (self.etag && [self.etag length]) {
            [request setValue:self.etag forHTTPHeaderField:@"If-None-Match"];
        }
        
        self.connection = [[NSURLConnection alloc] initWithRequest:request
                                                          delegate:self
                                                  startImmediately:NO];
        
        [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                   forMode:NSRunLoopCommonModes];
        
        [self.connection start];
    });
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        OperationRecord* record = [decoder decodeObjectForKey:@"operationRecord"];
        
        [self setState:record.status];
        self.username = record.userName;
        self.password = record.password;
        self.authType = record.authType;
        self.requestHeaders = [NSMutableDictionary dictionaryWithDictionary:record.headers];
        self.requestParameters = [NSMutableDictionary dictionaryWithDictionary:record.parameters];
        [self setStringEncoding:record.stringEncoding];
        self.clientCertificate = record.clientCertificate;
        self.credentialPersistence = record.credentialPersistence;
        self.uploadSizePerRequest = record.uploadSizePerRequest;
        
        self.filesToBeSaved = [decoder decodeObjectForKey:@"filesToBeSaved"];
        self.filesToBePosted = [decoder decodeObjectForKey:@"filesToBePosted"];
        
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:record.url
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                           timeoutInterval:kMKNetworkKitRequestTimeOutInSeconds];
        [request setHTTPMethod:record.httpMethod];
        self.request = request;
        
        self.isTraceable = record.isTraceable;
        self.isPersistable = record.isPersistable;
        self.isRestorable = record.isRestorable;
        self.isCacheable = record.isCacheable;
        self.unitCompleted = record.unitCompleted;
        self.unitTotal = record.unitTotal;
        self.boundary = record.boundary;
        self.postDataEncoding = record.postDataEncoding;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CommonNetworkOperation *theCopy = [[[self class] allocWithZone:zone] init];  // use designated initializer
    
    theCopy.postDataEncoding = self.postDataEncoding;
    theCopy.boundary = self.boundary;
    theCopy.uploadSizePerRequest = self.uploadSizePerRequest;
    theCopy.isTraceable = self.isTraceable;
    theCopy.isPersistable = self.isPersistable;
    theCopy.isRestorable = self.isRestorable;
    theCopy.isCacheable = self.isCacheable;
    [theCopy setStringEncoding:self.stringEncoding];
    theCopy.authType = self.authType;
    
    [theCopy setConnection:[self.connection copy]];
    [theCopy setRequest:[self.request copy]];
    [theCopy setResponse:[self.response copy]];
    [theCopy setFilesToBeSaved:[self.filesToBeSaved copy]];
    [theCopy setFilesToBePosted:[self.filesToBePosted copy]];
    [theCopy setUsername:[self.username copy]];
    [theCopy setPassword:[self.password copy]];
    [theCopy setClientCertificate:[self.clientCertificate copy]];
    [theCopy setResponseBlocks:[self.responseBlocks copy]];
    [theCopy setErrorBlocks:[self.errorBlocks copy]];
    [theCopy setState:self.state];
    [theCopy setUploadProgressChangedHandlers:[self.uploadProgressChangedHandlers copy]];
    [theCopy setDownloadProgressChangedHandlers:[self.downloadProgressChangedHandlers copy]];
    [theCopy setCacheHandlingBlock:self.cacheHandlingBlock];
    [theCopy setCancelHandlingBlock:self.cancelHandlingBlock];
    [theCopy setCredentialPersistence:self.credentialPersistence];
    
    theCopy.requestHeaders = [NSMutableDictionary dictionaryWithDictionary:self.requestHeaders];
    theCopy.requestParameters = [NSMutableDictionary dictionaryWithDictionary:self.requestParameters];
    theCopy.unitCompleted = self.unitCompleted;
    theCopy.unitTotal = self.unitTotal;
    
    theCopy.filesToBeSaved = [self.filesToBeSaved copy];
    
    return theCopy;
}

-(void) dealloc {
    
    [_connection cancel];
    _connection = nil;
}

-(NSDate*) expiresOnDate {
    if ([self.HTTPMethod isEqualToString:@"GET"]) {
        NSString *expiresOn = self.responseHeaders[@"Expires"];
        if(expiresOn) {
            return [NSDate dateFromRFC1123:expiresOn];
        }
        
        NSString *cacheControl = self.responseHeaders[@"Cache-Control"]; // max-age, must-revalidate, no-cache
        if (cacheControl) {
            NSArray *cacheControlEntities = [cacheControl componentsSeparatedByString:@","];
            
            for(NSString *substring in cacheControlEntities) {
                
                if([substring rangeOfString:@"max-age"].location != NSNotFound) {
                    
                    // do some processing to calculate expiresOn
                    NSString *maxAge = nil;
                    NSArray *array = [substring componentsSeparatedByString:@"="];
                    if([array count] > 1)
                        maxAge = array[1];
                    
                    return [[NSDate date] dateByAddingTimeInterval:[maxAge intValue]];
                }
            }
        }
    }
    
    return nil;
}

-(void) setDownloadSizePerRequest:(NSUInteger)value {
    _downloadSizePerRequest = value;
    
    if ([self.HTTPMethod isEqualToString:@"GET"]) {
        [self addHeaders:@{@"Range":[NSString stringWithFormat:@"bytes=%d-%d", (int)self.unitCompleted, (int)(self.unitCompleted + self.downloadSizePerRequest - 1)],
                           @"HTTP_RANGE":[NSString stringWithFormat:@"bytes=%d-%d", (int)self.unitCompleted, (int)(self.unitCompleted + self.downloadSizePerRequest - 1)],
                           @"X-RequestId":[[UIDevice currentDevice] uniqueDeviceIdentifier]}];
    }
}

-(void) updateHandlersFromOperation:(CommonNetworkOperation*) operation {
    [self.responseBlocks addEntriesFromDictionary:operation.responseBlocks];
    [self.errorBlocks addEntriesFromDictionary:operation.errorBlocks];
    [self.uploadProgressChangedHandlers addEntriesFromDictionary:operation.uploadProgressChangedHandlers];
    [self.downloadProgressChangedHandlers addEntriesFromDictionary:operation.downloadProgressChangedHandlers];
    
    [self.filesToBeSaved addEntriesFromDictionary:operation.filesToBeSaved];
}

-(void) removeHandlersFromOperation:(CommonNetworkOperation*) operation {
    for (id key in [operation.responseBlocks allKeys]) {
        NSMutableArray* handlers = [self.responseBlocks objectForKey:key];
        if (handlers) {
            [handlers removeObjectsInArray:(NSMutableArray*)[operation.responseBlocks objectForKey:key]];
            if (!handlers.count)
                [self.responseBlocks removeObjectForKey:key];
        }
    }
    
    for (id key in [operation.errorBlocks allKeys]) {
        NSMutableArray* handlers = [self.errorBlocks objectForKey:key];
        if (handlers) {
            [handlers removeObjectsInArray:(NSMutableArray*)[operation.errorBlocks objectForKey:key]];
            if (!handlers.count)
                [self.errorBlocks removeObjectForKey:key];
        }
    }
    
    for (id key in [operation.uploadProgressChangedHandlers allKeys]) {
        NSMutableArray* handlers = [self.uploadProgressChangedHandlers objectForKey:key];
        if (handlers) {
            [handlers removeObjectsInArray:(NSMutableArray*)[operation.uploadProgressChangedHandlers objectForKey:key]];
            if (!handlers.count)
                [self.uploadProgressChangedHandlers removeObjectForKey:key];
        }
    }
    
    for (id key in [operation.downloadProgressChangedHandlers allKeys]) {
        NSMutableArray* handlers = [self.downloadProgressChangedHandlers objectForKey:key];
        if (handlers) {
            [handlers removeObjectsInArray:(NSMutableArray*)[operation.downloadProgressChangedHandlers objectForKey:key]];
            if (!handlers.count)
                [self.downloadProgressChangedHandlers removeObjectForKey:key];
        }
    }
    
    for (id key in [operation.filesToBeSaved allKeys]) {
        NSMutableArray* handlers = [self.filesToBeSaved objectForKey:key];
        if (handlers) {
            [handlers removeObjectsInArray:(NSMutableArray*)[operation.filesToBeSaved objectForKey:key]];
            if (!handlers.count)
                [self.filesToBeSaved removeObjectForKey:key];
        }
    }
}

-(BOOL) hasHandlers
{
    return self.responseBlocks.count;
}

-(void) updateOperationBasedOnPreviousOperation:(CommonNetworkOperation*)operation {
    
    self.unitCompleted = operation.unitCompleted;
    self.unitTotal = operation.unitTotal;
    
    [operation.requestHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self.requestHeaders setValue:obj forKey:key];
    }];
    
    if ([self.HTTPMethod isEqualToString:@"GET"]) {
        [self addHeaders:@{@"Range":[NSString stringWithFormat:@"bytes=%d-%d", (int)self.unitCompleted, (int)(self.unitCompleted + self.downloadSizePerRequest - 1)],
                           @"HTTP_RANGE":[NSString stringWithFormat:@"bytes=%d-%d", (int)self.unitCompleted, (int)(self.unitCompleted + self.downloadSizePerRequest - 1)],
                           }];
    }
    
    self.requestParameters = [NSMutableDictionary dictionaryWithDictionary:operation.requestParameters];
    
    [self setStringEncoding:operation.stringEncoding];
    self.clientCertificate = operation.clientCertificate;
    self.credentialPersistence = operation.credentialPersistence;
    self.postDataEncoding = operation.postDataEncoding;
    self.username = operation.username;
    self.password = operation.password;
    self.authType = operation.authType;
}

-(void) setUsername:(NSString*) username password:(NSString*) password {
    
    self.username = username;
    self.password = password;
}

-(void) setBasicAuthUsername:(NSString*) username password:(NSString*) password {
    
    [self setUsername:username password:password];
    self.authType = HTTPBasicAuthentication;
    NSString *base64EncodedString = [[[NSString stringWithFormat:@"%@:%@", self.username, self.password] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedString];
    
    [self setAuthorizationHeaderValue:base64EncodedString forAuthType:@"Basic"];
}

-(void) setDigestAuthUsername:(NSString*) username password:(NSString*) password {
    [self setUsername:username password:password];
    self.authType = HTTPDigestAuthentication;
}

-(void) addCompletionHandler:(NKResponseBlock)response errorHandler:(NKErrorBlock)error {
    
    [[self handlersForKey:self.responseBlocks key:self.beneficiary] addObject:[response copy]];
    [[self handlersForKey:self.errorBlocks key:self.beneficiary] addObject:[error copy]];
}

-(void) onUploadProgressChanged:(NKProgressBlock) uploadProgressBlock {
    
    [[self handlersForKey:self.uploadProgressChangedHandlers key:self.beneficiary] addObject:[uploadProgressBlock copy]];
}

-(void) onDownloadProgressChanged:(NKProgressBlock) downloadProgressBlock {
    
    [[self handlersForKey:self.downloadProgressChangedHandlers key:self.beneficiary] addObject:[downloadProgressBlock copy]];
}

-(void) setFileToBeSaved:(NSURL*) fileUrl {
    NSParameterAssert(self.state == CommonNetworkOperationStateReady);
    
    [[self handlersForKey:self.filesToBeSaved key:self.beneficiary] removeAllObjects];
    [[self handlersForKey:self.filesToBeSaved key:self.beneficiary] addObject:fileUrl];

    NSFileManager *manger = [NSFileManager defaultManager];
    if ([manger fileExistsAtPath:[fileUrl path]]) {
        NSDictionary* attrs = [manger attributesOfItemAtPath:[fileUrl path] error:nil];
        if (attrs != nil) {
            NSDate *downloadTime = (NSDate*)[attrs objectForKey: NSFileCreationDate];
            
            [self addHeaders:@{@"if-modified-since":[CommonNetworkOperation formatDateString:downloadTime]}];
        }
    }

    NSURL* infoUrl = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:[[CommonNetworkOperation getDownloadTempDirectory] path], [NSString stringWithFormat:@"%@.download", [self uniqueIdentifier]], nil]];
    
    if ([manger fileExistsAtPath:[infoUrl path]]) {
        NSDictionary* infoDict = [NSDictionary dictionaryWithContentsOfFile:[infoUrl path]];
        
        if (infoDict) {
            NSNumber* nsUnitTotal = (NSNumber*)[infoDict objectForKey:@"unitTotal"];
            if (nsUnitTotal) {
                _unitTotal = [nsUnitTotal integerValue];
            }
            
            NSNumber* nsUnitCompleted = (NSNumber*)[infoDict objectForKey:@"unitCompleted"];
            if (nsUnitCompleted) {
                _unitCompleted = [nsUnitCompleted integerValue];
                
                [self addHeaders:@{@"Range":[NSString stringWithFormat:@"bytes=%d-%d", (int)self.unitCompleted, (int)(self.unitCompleted + self.downloadSizePerRequest - 1)],
                                   @"HTTP_RANGE":[NSString stringWithFormat:@"bytes=%d-%d", (int)self.unitCompleted, (int)(self.unitCompleted + self.downloadSizePerRequest - 1)],
                                   }];
            }
            
        }
    }
}

-(BOOL) hasFileToBeSaved
{
    return [self.filesToBeSaved count];
}

-(BOOL) hasFileToBeSaved:(NSURL*) fileUrl
{
    return [[self handlersForKey:self.filesToBeSaved key:self.beneficiary] indexOfObject:fileUrl] != NSNotFound;
}

- (id)initWithURLString:(NSString *)aURLString
                 params:(NSDictionary *)params
             httpMethod:(NSString *)method beneficiary:(id<NSCopying>)beneficiary

{
    if((self = [super init])) {
        
        if (!beneficiary) {
            beneficiary = [[NSBundle mainBundle] bundleIdentifier];
        }
        _beneficiary = beneficiary;
        self.responseBlocks = [NSMutableDictionary dictionary];
        self.errorBlocks = [NSMutableDictionary dictionary];
        self.filesToBePosted = [NSMutableArray array];
        
        self.uploadProgressChangedHandlers = [NSMutableDictionary dictionary];
        self.downloadProgressChangedHandlers = [NSMutableDictionary dictionary];
        
        self.credentialPersistence = NSURLCredentialPersistenceForSession;
        self.requestHeaders = [NSMutableDictionary dictionary];
        self.requestParameters = [NSMutableDictionary dictionary];
        self.filesToBeSaved = [NSMutableDictionary dictionary];
        self.isTraceable = NO;
        self.isPersistable = NO;
        self.isRestorable = NO;
        self.isCacheable = NO;
        self.boundary = [NSString uniqueString];
        
        NSURL *finalURL = nil;
        
        if(params)
            [self.requestParameters addEntriesFromDictionary:params];
        
        self.stringEncoding = NSUTF8StringEncoding; // use a delegate to get these values later
        
        if (params && [params count]) {
            
            finalURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", aURLString,
                                             [self encodedPostDataString]]];
        } else {
            finalURL = [NSURL URLWithString:aURLString];
        }
        
        self.request = [NSMutableURLRequest requestWithURL:finalURL
                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                           timeoutInterval:kMKNetworkKitRequestTimeOutInSeconds];
        
        [self.request setHTTPMethod:method];
        self.postDataEncoding = NKPostDataEncodingTypeURL;
        self.uploadSizePerRequest = kMKNetworkKitDefaultUploadSizePerRequest;
        self.downloadSizePerRequest = kMKNetworkKitDefaultDownloadSizePerRequest;
        [self addHeaders:@{@"Cache-Control":@"no-cache"}];
        
        self.state = CommonNetworkOperationStateReady;
    }
    
    return self;
}

-(void) addHeaders:(NSDictionary*) headersDictionary {
    
    [headersDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self.requestHeaders setValue:obj forKey:key];
    }];
}

-(void) setAuthorizationHeaderValue:(NSString*) token forAuthType:(NSString*) authType {
    
    [self addHeaders:@{@"Authorization":[NSString stringWithFormat:@"%@ %@", authType, token]}];
}
/*
 Printing a CommonNetworkOperation object is printed in curl syntax
 */

-(NSString*) description {
    
    NSMutableString *displayString = [NSMutableString stringWithFormat:@"%@\nRequest\n-------\n%@",
                                      [[NSDate date] descriptionWithLocale:[NSLocale currentLocale]],
                                      [self curlCommandLineString]];
    
    NSString *responseString = [self responseString];
    if([responseString length] > 0) {
        [displayString appendFormat:@"\n--------\nResponse\n--------\n%@\n", responseString];
    }
    
    return displayString;
}

-(NSString*) curlCommandLineString
{
    __block NSMutableString *displayString = [NSMutableString stringWithFormat:@"curl -X %@", self.request.HTTPMethod];
    
    if([self.filesToBePosted count] == 0) {
        [[self.request allHTTPHeaderFields] enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop)
         {
             [displayString appendFormat:@" -H \"%@: %@\"", key, val];
         }];
    }
    
    [displayString appendFormat:@" \"%@\"",  self.url];
    
    if ([self.request.HTTPMethod isEqualToString:@"POST"] || [self.request.HTTPMethod isEqualToString:@"PUT"]) {
        
        NSString *option = [self.filesToBePosted count] == 0 ? @"-d" : @"-F";
        if(self.postDataEncoding == NKPostDataEncodingTypeURL) {
            [self.requestParameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                
                [displayString appendFormat:@" %@ \"%@=%@\"", option, key, obj];
            }];
        } else {
            [displayString appendFormat:@" -d \"%@\"", [self encodedPostDataString]];
        }
        
        
        [self.filesToBePosted enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            
            NSDictionary *thisFile = (NSDictionary*) obj;
            [displayString appendFormat:@" -F \"%@=@%@;type=%@\"", thisFile[@"name"],
             thisFile[@"filepath"], thisFile[@"mimetype"]];
        }];
    }
    
    return displayString;
}

-(void) addFile:(NSString*) filePath forKey:(NSString*) key {
    
    [self addFile:filePath forKey:key mimeType:@"application/octet-stream"];
}

-(void) addFile:(NSString*) filePath forKey:(NSString*) key mimeType:(NSString*) mimeType {
    
    NSDictionary *dict = @{@"filepath": filePath,
                           @"name": key,
                           @"mimetype": mimeType};
    
    [self.filesToBePosted addObject:dict];
}

-(NSData*) bodyData {
    
    NSMutableData *body = [NSMutableData data];
    _actualDataLength = 0;
    __block NSUInteger totalLength = 0;
    __block NSUInteger since = self.unitCompleted;
    __block NSInteger leftOver = self.uploadSizePerRequest;
    
    __block NSUInteger parametersLength = 0;
    [self.requestParameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        
        NSString *thisFieldString = [NSString stringWithFormat:
                                     @"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@",
                                     self.boundary, key, obj];
        NSData* data = [thisFieldString dataUsingEncoding:[self stringEncoding]];
        parametersLength += data.length;
        
        [body appendData:data];
        [body appendData:[@"\r\n" dataUsingEncoding:[self stringEncoding]]];
    }];
    
    //By default the limit of post data size per request is larger than the size of post parameters's body
    totalLength += parametersLength;
    if (since) {
        since -= parametersLength;
        body = [NSMutableData data];
    } else {
        leftOver = MAX(leftOver - parametersLength, 0);
        _actualDataLength += body.length;
    }
    
    if (leftOver > 0) {
        [self.filesToBePosted enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            
            NSDictionary *thisFile = (NSDictionary*) obj;
            
            NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:thisFile[@"filepath"] error:nil];
            NSUInteger fileSize = [[fileAttributes objectForKey:NSFileSize] integerValue];
            totalLength += fileSize;
            
            if (leftOver > 0) {
                if (since > fileSize) {
                    since -= fileSize;
                } else {
                    NSUInteger dataLength = MIN(fileSize - since, leftOver);
                    
                    NSString *thisFieldString = [NSString stringWithFormat:
                                                 @"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\nContent-Type: %@\r\nContent-Transfer-Encoding: binary\r\nRange: bytes %d-%d/%d\r\n\r\n",
                                                 self.boundary,
                                                 thisFile[@"name"],
                                                 [thisFile[@"filepath"] lastPathComponent],
                                                 thisFile[@"mimetype"],
                                                 (int)since,
                                                 (int)(since + dataLength),
                                                 (int)fileSize];
                    
                    [body appendData:[thisFieldString dataUsingEncoding:[self stringEncoding]]];
                    
                    NSFileHandle* fileHandle = [NSFileHandle fileHandleForReadingAtPath:thisFile[@"filepath"]];
                    [fileHandle seekToFileOffset:since];
                    [body appendData:[fileHandle readDataOfLength:dataLength]];
                    [fileHandle closeFile];
                    
                    [body appendData:[@"\r\n" dataUsingEncoding:[self stringEncoding]]];
                    
                    leftOver -= dataLength;
                    _actualDataLength += dataLength;
                    if (since + dataLength == fileSize)
                        since = 0;
                }
            }
        }];
    }
    
    [body appendData: [[NSString stringWithFormat:@"--%@--\r\n", self.boundary] dataUsingEncoding:self.stringEncoding]];
    
    self.unitTotal = totalLength;
    
    [self addHeaders:@{@"Content-Length":[NSString stringWithFormat:@"%lu", (unsigned long) [body length]]}];
    
    return body;
}

-(void) setCacheHandler:(NKCacheBlock) cacheHandler {
    
    self.cacheHandlingBlock = cacheHandler;
}

-(void) setCancelHandler:(NKCancelBlock) cancelHandlingBlock {
    
    self.cancelHandlingBlock = cancelHandlingBlock;
}


-(void) setUnitCompleted:(NSUInteger)unitCompleted
{
    _unitCompleted = unitCompleted;
    
    if ([self.HTTPMethod isEqualToString:@"GET"]) {
        [self setDownloadInfo:@"unitCompleted" value:[NSNumber numberWithUnsignedLong:unitCompleted]];
        
        [self addHeaders:@{@"Range":[NSString stringWithFormat:@"bytes=%d-%d", (int)unitCompleted, (int)(self.unitCompleted + self.downloadSizePerRequest - 1)],
                           @"HTTP_RANGE":[NSString stringWithFormat:@"bytes=%d-%d", (int)self.unitCompleted, (int)(self.unitCompleted + self.downloadSizePerRequest - 1)],
                           }];
    }
}

-(void) setUnitTotal:(NSUInteger)unitTotal
{
    _unitTotal = unitTotal;
    
    [self setDownloadInfo:@"unitTotal" value:[NSNumber numberWithUnsignedLong:unitTotal]];
}

-(void) setDownloadInfo:(NSString*) key value:(id)value
{
    if ([self.request.HTTPMethod isEqualToString:@"GET"]) {
        NSURL* infoUrl = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:[[CommonNetworkOperation getDownloadTempDirectory] path], [NSString stringWithFormat:@"%@.download", [self uniqueIdentifier]], nil]];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[infoUrl path]]) {
            [[NSFileManager defaultManager] createFileAtPath:[infoUrl path] contents:nil attributes:nil];
        }
        
        NSMutableDictionary* infoDict = [NSMutableDictionary dictionary];
        [infoDict addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:[infoUrl path]]];
        
        [infoDict setObject:value forKey:key];
        [infoDict writeToURL:infoUrl atomically:YES];
    }
}

-(void) removeDownloadInfo {
    if ([self.request.HTTPMethod isEqualToString:@"GET"]) {
        NSURL* infoUrl = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:[[CommonNetworkOperation getDownloadTempDirectory] path], [NSString stringWithFormat:@"%@.download", [self uniqueIdentifier]], nil]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[infoUrl path]]) {
            [[NSFileManager defaultManager] removeItemAtURL:infoUrl error:nil];
        }
    }
}

-(NSDictionary*) downloadInfo
{
    if ([self.request.HTTPMethod isEqualToString:@"GET"]) {
        NSURL* infoUrl = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:[[CommonNetworkOperation getDownloadTempDirectory] path], [NSString stringWithFormat:@"%@.download", [self uniqueIdentifier]], nil]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[infoUrl path]]) {
            NSMutableDictionary* infoDict = [NSMutableDictionary dictionary];
            [infoDict addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:[infoUrl path]]];
            
            return infoDict;
        }
    }
    
    return nil;
}

#pragma mark -
#pragma Main method
-(void) main {
    
    @autoreleasepool {
        [self start];
    }
}

- (void) start
{
    
#if TARGET_OS_IPHONE
    self.backgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stop];
        });
    }];
    
#endif
    
    if (([self.request.HTTPMethod isEqualToString:@"POST"] || [self.request.HTTPMethod isEqualToString:@"PUT"]) && !self.request.HTTPBodyStream) {
        
        [self.request setHTTPBody:[self bodyData]];
    }
    
    [self createConnectionFromRequest:self.request];
    
    [self operationStart];
}

#pragma -
#pragma mark NSOperation stuff

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isReady {
    
    return (self.state == CommonNetworkOperationStateReady && [super isReady]);
}

- (BOOL)isFinished
{
    return (self.state == CommonNetworkOperationStateFinished || self.state == CommonNetworkOperationStateStopped || self.state == CommonNetworkOperationStateCancelled);
}

- (BOOL)isExecuting {
    
    return (self.state == CommonNetworkOperationStateExecuting);
}

- (void) dispose {
    @synchronized(self) {
        if (self.connection) {
            [self.connection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            [self.connection cancel];
            self.connection = nil;
        }
        
        if (self.responseBlocks) {
            [self.responseBlocks removeAllObjects];
            self.responseBlocks = nil;
        }
        
        if (self.errorBlocks) {
            [self.errorBlocks removeAllObjects];
            self.errorBlocks = nil;
        }
        
        if (self.uploadProgressChangedHandlers) {
            [self.uploadProgressChangedHandlers removeAllObjects];
            self.uploadProgressChangedHandlers = nil;
        }
        
        if (self.downloadProgressChangedHandlers) {
            [self.downloadProgressChangedHandlers removeAllObjects];
            self.downloadProgressChangedHandlers = nil;
        }
        
        self.authHandler = nil;
        
        self.cacheHandlingBlock = nil;
        self.cancelHandlingBlock = nil;
    }
}

- (void) stop {
    
    if([self isFinished])
        return;
    
#if TARGET_OS_IPHONE
    dispatch_async(dispatch_get_main_queue(), ^{
        [self operationStop];
        
        [self dispose];
        
        if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskId];
            self.backgroundTaskId = UIBackgroundTaskInvalid;
            [super cancel];
        }
    });
#endif
}

-(void) cancel {
    
    if([self isFinished]) {
        [self operationCancel];
        return;
    }
    
#if TARGET_OS_IPHONE
    dispatch_async(dispatch_get_main_queue(), ^{
        [self operationCancel];
        
        [self dispose];
        
        if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskId];
            self.backgroundTaskId = UIBackgroundTaskInvalid;
            [super cancel];
        }
    });
#endif
}

#pragma mark -
#pragma mark NSURLConnection delegates

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (self.connection != connection)
        return;
    
    [self stop];
    [self operationFailedWithError:error];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if (self.connection != connection)
        return;
    
    if ([challenge previousFailureCount] == 0) {
        
        if ((challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate) && self.clientCertificate) {
            
            NSData *certData = [[NSData alloc] initWithContentsOfFile:self.clientCertificate];
            
#warning method not implemented. Don't use client certicate authentication for now.
            SecIdentityRef myIdentity = nil;  // ???
            
            SecCertificateRef myCert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);
            SecCertificateRef certArray[1] = { myCert };
            CFArrayRef myCerts = CFArrayCreate(NULL, (void *)certArray, 1, NULL);
            CFRelease(myCert);
            NSURLCredential *credential = [NSURLCredential credentialWithIdentity:myIdentity
                                                                     certificates:(__bridge NSArray *)myCerts
                                                                      persistence:NSURLCredentialPersistencePermanent];
            CFRelease(myCerts);
            [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
        }
        else if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
#warning method not tested. proceed at your own risk
            SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
            SecTrustResultType result;
            SecTrustEvaluate(serverTrust, &result);
            
            if(result == kSecTrustResultProceed) {
                
                [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
            }
            else if(result == kSecTrustResultConfirm) {
                
                // ask user
                BOOL userOkWithWrongCert = NO; // (ACTUALLY CHEAT., DON'T BE A F***ING BROWSER, USERS ALWAYS TAP YES WHICH IS RISKY)
                if(userOkWithWrongCert) {
                    
                    // Cert not trusted, but user is OK with that
                    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
                } else {
                    
                    // Cert not trusted, and user is not OK with that. Don't proceed
                    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
                }
            }
            else {
                
                // invalid or revoked certificate
                [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
                //[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
            }
        }
        else if (self.authHandler) {
            
            // forward the authentication to the view controller that created this operation
            // If this happens for NSURLAuthenticationMethodHTMLForm, you have to
            // do some shit work like showing a modal webview controller and close it after authentication.
            // I HATE THIS.
            self.authHandler(challenge);
        }
        else {
            [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        }
    } else {
        //  apple proposes to cancel authentication, which results in NSURLErrorDomain error -1012, but we prefer to trigger a 401
        //        [[challenge sender] cancelAuthenticationChallenge:challenge];
        [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if (self.connection != connection)
        return;
    
    self.response = (NSHTTPURLResponse*) response;
    self.responseHeaders = [NSMutableDictionary dictionaryWithDictionary:self.response.allHeaderFields];
    
    // if you attach a stream to the operation, MKNetworkKit will not cache the response.
    // Streams are usually "big data chunks" that doesn't need caching anyways.
    
    if (self.response.statusCode == 200 || self.response.statusCode == 206) {
        _cachedResponse = nil;
        
        if([self.request.HTTPMethod isEqualToString:@"GET"]) {
        } else if([self.request.HTTPMethod isEqualToString:@"POST"]) {
            if([self.filesToBePosted count] > 0) {
                self.unitCompleted += _actualDataLength;
                
                if (self.unitCompleted == self.unitTotal) {
                    [self operationSucceeded];
                } else {
                    [self operationProgress:self.unitCompleted total:self.unitTotal];
                    
                    if (self.state == CommonNetworkOperationStateExecuting) {
                        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:self.request.URL
                                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                                           timeoutInterval:kMKNetworkKitRequestTimeOutInSeconds];
                        
                        [request setHTTPMethod:@"POST"];
                        [request setHTTPBody:[self bodyData]];
                        self.request = request;
                        
                        [self addHeaders:@{@"Cache-Control":@"no-cache"}];
                        
                        [self createConnectionFromRequest:request];
                    }
                }
            }
        }
    } else if (self.response.statusCode == 401) {
        NSObject* authHeader = [self.responseHeaders objectForKey:@"WWW-Authenticate"];
        
        if (self.username && self.password && self.authType == HTTPDigestAuthentication) {
            
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (self.connection != connection)
        return;
    
    if (self.response.statusCode == 200 || self.response.statusCode == 206) {
        NSDictionary *httpHeaders = [self.response allHeaderFields];
        DLog(@"GET Received HTTP Headers \n%@", httpHeaders);
        
        NSString* strContentLength = httpHeaders[@"Content-Length"];
        NSInteger contentLength = [strContentLength integerValue];
        
        if (contentLength) {
            NSData* d = [data copy];
            
            if (_cachedResponse)
                [_cachedResponse appendData:d];
            else
                _cachedResponse = [NSMutableData dataWithData:d];
        }
        
        if([self.request.HTTPMethod isEqualToString:@"GET"]) {
            if (_cachedResponse.length > 0) {
                NSString* strContentRange = httpHeaders[@"Content-Range"];
                NSArray *contentRangeEntities = [strContentRange componentsSeparatedByString:@"/"];
                if (contentRangeEntities && contentRangeEntities.count > 1) {
                    NSString* fileSize = contentRangeEntities[1];
                    self.unitTotal = [fileSize integerValue];
                } else {
                    self.unitTotal = contentLength;
                }
                
                if (_cachedResponse.length == contentLength) {
                    if (self.unitCompleted < self.unitTotal) {
                        [self.filesToBeSaved enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                            NSArray* files = (NSArray*) obj;
                            for (NSURL* fileUrl in files) {
                                NSURL* tempUrl = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:[[CommonNetworkOperation getDownloadTempDirectory] path], [fileUrl lastPathComponent], nil]];
                                
                                if (![[NSFileManager defaultManager] fileExistsAtPath:[tempUrl path]]) {
                                    [[NSFileManager defaultManager] createFileAtPath:[tempUrl path] contents:nil attributes:nil];
                                }
                                
                                NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:[tempUrl path]];
                                [fileHandle seekToFileOffset:self.unitCompleted];
                                [fileHandle writeData:_cachedResponse];
                                [fileHandle closeFile];
                            }
                        }];
                        self.unitCompleted += _cachedResponse.length;
                        [self operationProgress:self.unitCompleted total:self.unitTotal];
                        
                        if (self.unitCompleted == self.unitTotal) {
                            [self.filesToBeSaved enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                                NSArray* files = (NSArray*) obj;
                                for (NSURL* fileUrl in files) {
                                    NSURL* tempUrl = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:[[CommonNetworkOperation getDownloadTempDirectory] path], [fileUrl lastPathComponent], nil]];
                                    
                                    NSInteger len = [fileUrl pathComponents].count;
                                    NSURL* folder = [NSURL fileURLWithPathComponents:[[fileUrl pathComponents] subarrayWithRange:NSMakeRange(0, len - 1)]];
                                    if (![[NSFileManager defaultManager] fileExistsAtPath:[folder path]]) {
                                        [[NSFileManager defaultManager] createDirectoryAtPath:[folder path] withIntermediateDirectories:YES attributes:nil error:nil];
                                    }
                                    
                                    if (self.isCacheable) {
                                        NSDate* expiresOnDate = [self expiresOnDate];
                                        NSString *etag = [self.responseHeaders objectForKey:@"etag"];
                                        etag = [etag stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                                        NSString* str = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) objectAtIndex:0];
                                        
                                        if (expiresOnDate) {
                                            NSString* cachedFilePath = [str stringByAppendingPathComponent:self.uniqueIdentifier];
                                            [[NSFileManager defaultManager] copyItemAtURL:tempUrl toURL:[NSURL fileURLWithPath:cachedFilePath] error:nil];
                                        } else if (etag) {
                                            NSString* etaggedFilePath = [str stringByAppendingPathComponent:[NSString stringWithFormat:@"e-%@.etag", etag]];
                                            [[NSFileManager defaultManager] copyItemAtURL:tempUrl toURL:[NSURL fileURLWithPath:etaggedFilePath] error:nil];
                                        }
                                    }
                                    
                                    [[NSFileManager defaultManager] moveItemAtURL:tempUrl toURL:fileUrl error:nil];
                                }
                            }];
                            
                            [self operationSucceeded];
                        }
                    }
                    
                    if (self.unitCompleted < self.unitTotal) {
                        if (self.state == CommonNetworkOperationStateExecuting) {
                            NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:self.request.URL
                                                                                   cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                                               timeoutInterval:kMKNetworkKitRequestTimeOutInSeconds];
                            
                            [request setHTTPMethod:@"GET"];
                            
                            [self addHeaders:@{@"Cache-Control":@"no-cache",
                                               @"Range":[NSString stringWithFormat:@"bytes=%d-%d", (int)(self.unitCompleted), (int)(self.unitCompleted + self.downloadSizePerRequest - 1)],
                                               @"HTTP_RANGE":[NSString stringWithFormat:@"bytes=%d-%d", (int)self.unitCompleted, (int)(self.unitCompleted + self.downloadSizePerRequest)],
                                               @"X-RequestId":[[UIDevice currentDevice] uniqueDeviceIdentifier] }];
                            
                            self.request = request;
                            
                            [self createConnectionFromRequest:request];
                        }
                    }
                } else {
                    [self operationProgress:self.unitCompleted+_cachedResponse.length total:self.unitTotal];
                }
            }
        } else {
            if(![self.filesToBePosted count]) {
                if (_cachedResponse.length == contentLength)
                    [self operationSucceeded];
            }
        }
    }
}

// http://stackoverflow.com/questions/1446509/handling-redirects-correctly-with-nsurlconnection
- (NSURLRequest *)connection: (NSURLConnection *)inConnection
             willSendRequest: (NSURLRequest *)inRequest
            redirectResponse: (NSURLResponse *)inRedirectResponse;
{
    if (self.connection != inConnection)
        return inRequest;
    
    if (inRedirectResponse) {
        NSMutableURLRequest *r = [self.request mutableCopy];
        [r setURL: [inRequest URL]];
        
        return r;
    } else {
        return inRequest;
    }
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (self.connection != connection)
        return;
    
    if (self.state != CommonNetworkOperationStateExecuting)
        return;
    
    if (self.response.statusCode == 200 || self.response.statusCode == 206) {
        if ([self.HTTPMethod isEqualToString:@"GET"]) {
            NSDictionary *httpHeaders = [self.response allHeaderFields];
            NSString* strContentLength = httpHeaders[@"Content-Length"];
            if (strContentLength) {
                NSInteger contentLength = [strContentLength integerValue];
                
                if (!contentLength)
                    [self operationFailedWithError:[NSError errorWithDomain:@"MKNetworkKitErrorDomain"
                                                                       code:-1
                                                                   userInfo:[NSDictionary dictionaryWithObject:@"HTTP GET returns result of zero content length." forKey:NSLocalizedDescriptionKey]]];
            }
        }
    } else if (self.response.statusCode >= 300 && self.response.statusCode < 400) {
        
        if(self.response.statusCode == 301) {
            DLog(@"%@ has moved to %@", self.url, [self.response.URL absoluteString]);
        }
        else if(self.response.statusCode == 304) {
            DLog(@"%@ not modified", self.url);
        }
        else if(self.response.statusCode == 307) {
            DLog(@"%@ temporarily redirected", self.url);
        }
        else {
            DLog(@"%@ returned status %d", self.url, (int) self.response.statusCode);
        }
        [self operationSucceeded];
        
    } else if (self.response.statusCode >= 400 && self.response.statusCode < 600) {
        
        [self operationFailedWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                           code:self.response.statusCode
                                                       userInfo:self.response.allHeaderFields]];
    }
}

#pragma mark -
#pragma mark Our methods to get data

-(NSData*) responseData {
    if (_cachedResponse && _cachedResponse.length)
        return _cachedResponse;
    
    if (self.cachedItemPath && [[NSFileManager defaultManager] fileExistsAtPath:self.cachedItemPath]) {
        return [[NSFileManager defaultManager] contentsAtPath:self.cachedItemPath];
    }
    
    return [NSData data];
}

-(NSString*)responseString {
    
    return [self responseStringWithEncoding:self.stringEncoding];
}

-(NSString*) responseStringWithEncoding:(NSStringEncoding) encoding {
    
    return [[NSString alloc] initWithData:[self responseData] encoding:encoding];
}

#if TARGET_OS_IPHONE
-(UIImage*) responseImage {
    
    return [UIImage imageWithData:[self responseData]];
}

-(void) decompressedResponseImageOfSize:(CGSize) size completionHandler:(void (^)(UIImage *decompressedImage)) imageDecompressionHandler {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        __block CGSize targetSize = size;
        UIImage *image = [self responseImage];
        CGImageRef imageRef = image.CGImage;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);
        BOOL sameSize = NO;
        if (CGSizeEqualToSize(targetSize, CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef)))) {
            targetSize = CGSizeMake(1, 1);
            sameSize = YES;
        }
        
        size_t imageWidth = (size_t)targetSize.width;
        size_t imageHeight = (size_t)targetSize.height;
        
        CGContextRef context = CGBitmapContextCreate(NULL,
                                                     imageWidth,
                                                     imageHeight,
                                                     8,
                                                     // Just always return width * 4 will be enough
                                                     imageWidth * 4,
                                                     // System only supports RGB, set explicitly
                                                     colorSpace,
                                                     // Makes system don't need to do extra conversion when displayed.
                                                     alphaInfo | kCGBitmapByteOrder32Little);
        CGColorSpaceRelease(colorSpace);
        if (!context) {
            return;
        }
        
        
        CGRect rect = (CGRect){CGPointZero, {imageWidth, imageHeight}};
        CGContextDrawImage(context, rect, imageRef);
        if (sameSize) {
            CGContextRelease(context);
            dispatch_async(dispatch_get_main_queue(), ^{
                imageDecompressionHandler(image);
            });
            return;
        }
        CGImageRef decompressedImageRef = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        
        static float scale = 0.0f;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            scale = [UIScreen mainScreen].scale;
        });
        
        UIImage *decompressedImage = [[UIImage alloc] initWithCGImage:decompressedImageRef scale:scale orientation:image.imageOrientation];
        CGImageRelease(decompressedImageRef);
        dispatch_async(dispatch_get_main_queue(), ^{
            imageDecompressionHandler(decompressedImage);
        });
    });
}

#elif TARGET_OS_MAC
-(NSImage*) responseImage {
    
    return [[NSImage alloc] initWithData:[self responseData]];
}

-(NSXMLDocument*) responseXML {
    
    return [[NSXMLDocument alloc] initWithData:[self responseData] options:0 error:nil];
}
#endif

-(id) responseJSON {
    
    NSError *error = nil;
    id returnValue = [NSJSONSerialization JSONObjectWithData:[self responseData] options:0 error:&error];
    if(error) DLog(@"JSON Parsing Error: %@", error);
    return returnValue;
}

-(void) responseJSONWithCompletionHandler:(void (^)(id jsonObject)) jsonDecompressionHandler {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSError *error = nil;
        id returnValue = [NSJSONSerialization JSONObjectWithData:[self responseData] options:0 error:&error];
        if(error) {
            
            DLog(@"JSON Parsing Error: %@", error);
            jsonDecompressionHandler(nil);
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            jsonDecompressionHandler(returnValue);
        });
    });
}

-(void) showLocalNotification {
#if TARGET_OS_IPHONE
    
    if(self.localNotification) {
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:self.localNotification];
    } else if(self.shouldShowLocalNotificationOnError) {
        
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        
        localNotification.alertBody = [self.error localizedDescription];
        localNotification.alertAction = NSLocalizedString(@"Dismiss", @"");
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    }
#endif
}

-(void) operationSucceeded {
    if (self.state == CommonNetworkOperationStateFinished) {
        return;
    }
    
    DLog(@"%@ operation finished:[%@]", self.request.HTTPMethod, self.request.URL);
    self.state = CommonNetworkOperationStateFinished;
    
    [self removeDownloadInfo];
    
    if (self.cacheHandlingBlock) {
        self.cacheHandlingBlock(self);
    }
    
    for (NSMutableArray* handlers in [self.responseBlocks allValues]) {
        for(NKResponseBlock responseBlock in handlers)
            responseBlock(self);
    }
}

-(void) operationFailedWithError:(NSError*) error {
    if (self.state == CommonNetworkOperationStateStopped) {
        return;
    }
    
    DLog(@"%@, [%@]", self, [error localizedDescription]);
    self.state = CommonNetworkOperationStateStopped;
    
    self.error = error;
    
    for (id key in [self.errorBlocks allKeys]) {
        NSMutableArray* handlers = [self.errorBlocks objectForKey:key];
        if (handlers) {
            for(NKErrorBlock errorBlock in handlers)
                errorBlock(self, self.cachedItemPath, error);
        }
    }
    
#if TARGET_OS_IPHONE
    DLog(@"State: %d", (int)[[UIApplication sharedApplication] applicationState]);
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
        [self showLocalNotification];
#endif
    
}

-(void) operationStart {
    if (self.state == CommonNetworkOperationStateExecuting) {
        return;
    }
    
    DLog(@"%@ operation started:[%@]", self.request.HTTPMethod, self.request.URL);
    self.state = CommonNetworkOperationStateExecuting;
    
    double progress = 0;
    if (self.unitCompleted != 0 && self.unitTotal != 0)
        progress = (double)self.unitCompleted / (double)self.unitTotal;
    
    if([self.request.HTTPMethod isEqualToString:@"GET"]) {
        for (NSMutableArray* handlers in [self.downloadProgressChangedHandlers allValues]) {
            for(NKProgressBlock downloadProgressBlock in handlers)
                downloadProgressBlock(progress);
        }
    } else if([self.request.HTTPMethod isEqualToString:@"POST"]) {
        for (NSMutableArray* handlers in [self.uploadProgressChangedHandlers allValues]) {
            for(NKProgressBlock uploadProgressBlock in handlers)
                uploadProgressBlock(progress);
        }
    }
}

-(void) operationStop {
    if (self.state == CommonNetworkOperationStateStopped) {
        return;
    }
    
    DLog(@"%@ operation stopped:[%@]", self.request.HTTPMethod, self.request.URL);
    self.state = CommonNetworkOperationStateStopped;
    
    if (self.cacheHandlingBlock) {
        self.cacheHandlingBlock(self);
    }
}

-(void) operationCancel {
    if (self.state == CommonNetworkOperationStateCancelled) {
        return;
    }
    
    DLog(@"%@ operation cancelled:[%@]", self.request.HTTPMethod, self.request.URL);
    self.state = CommonNetworkOperationStateCancelled;
    
    [self removeDownloadInfo];
    
    if (self.cancelHandlingBlock) {
        self.cancelHandlingBlock(self);
    }
}

-(void) operationProgress:(NSUInteger)completed total:(NSUInteger)total {
    double progress = (double)completed / (double)total;
    
    DLog(@"%@ operation is under progress:[%.2f]", self.request.HTTPMethod, progress);
    
    if (self.cacheHandlingBlock) {
        self.cacheHandlingBlock(self);
    }
    
    if([self.request.HTTPMethod isEqualToString:@"GET"]) {
        for (NSMutableArray* handlers in [self.downloadProgressChangedHandlers allValues]) {
            for(NKProgressBlock downloadProgressBlock in handlers)
                downloadProgressBlock(progress);
        }
    } else if([self.request.HTTPMethod isEqualToString:@"POST"]) {
        for (NSMutableArray* handlers in [self.uploadProgressChangedHandlers allValues]) {
            for(NKProgressBlock uploadProgressBlock in handlers)
                uploadProgressBlock(progress);
        }
    }
}

@end
