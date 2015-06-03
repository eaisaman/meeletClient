//
//  CommonNetworkKit.h
//  MeeletClient
//
//  Created by jill on 15/5/25.
//
//

#ifndef MeeletClient_CommonNetworkKit_h
#define MeeletClient_CommonNetworkKit_h
#if TARGET_OS_IPHONE
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
#define DO_GCD_RETAIN_RELEASE 0
#else
#define DO_GCD_RETAIN_RELEASE 1
#endif
#endif

#define kCommonNetworkEngineOperationCountChanged @"kCommonNetworkEngineOperationCountChanged"
#define MKNETWORKCACHE_DEFAULT_COST 10
#define kMKNetworkKitDefaultUploadSizePerRequest 1024000
#define kMKNetworkKitDefaultDownloadSizePerRequest 1024000
#define kMKNetworkKitDefaultCacheDuration 60 // 1 minute
#define kMKNetworkKitDefaultImageHeadRequestDuration 3600*24*1 // 1 day (HEAD requests with eTag are sent only after expiry of this. Not that these are not RFC compliant, but needed for performance tuning)

// if your server takes longer than 30 seconds to provide real data,
// you should hire a better server developer.
// on iOS (or any mobile device), 30 seconds is already considered high.

#define kMKNetworkKitRequestTimeOutInSeconds 300

#import "NSString+NetworkKitAdditions.h"
#import "NSDictionary+RequestEncoding.h"
#import "NSDate+RFC1123.h"
#import "NSData+Base64.h"
#import "UIDevice+IdentifierAddition.h"

#import "Reachability.h"

@class CommonNetworkEngine;
@class CommonNetworkOperation;

typedef enum {
    CommonNetworkOperationStateReady = 1 << 0,
    CommonNetworkOperationStateExecuting = 1 << 1,
    CommonNetworkOperationStateFinished = 1 << 2,
    CommonNetworkOperationStateStopped = 1 << 3,
    CommonNetworkOperationStateCancelled = 1 << 4
} CommonNetworkOperationState;

typedef enum {
    HTTPBasicAuthentication = 1 << 0,
    HTTPDigestAuthentication = 1 << 1
} HTTPAuthType;

typedef void (^NKVoidBlock)(void);
typedef void (^NKIDBlock)(void);
typedef void (^NKProgressBlock)(double progress);
typedef void (^NKResponseBlock)(CommonNetworkOperation* completedOperation);
typedef void (^NKCacheBlock)(CommonNetworkOperation* operation);
typedef void (^NKCancelBlock)(CommonNetworkOperation* operation);
typedef void (^NKUrlBlock) (NSURL* url);
#if TARGET_OS_IPHONE
typedef void (^NKImageBlock) (UIImage* fetchedImage, NSURL* url);
#elif TARGET_OS_MAC
typedef void (^NKImageBlock) (NSImage* fetchedImage, NSURL* url);
#endif
typedef void (^NKErrorBlock)(CommonNetworkOperation* completedOperation, NSString* prevResponsePath, NSError* error);

typedef void (^NKAuthBlock)(NSURLAuthenticationChallenge* challenge);

typedef NSString* (^NKEncodingBlock) (NSDictionary* postDataDict);

typedef enum {
    
    NKPostDataEncodingTypeURL = 0, // default
    NKPostDataEncodingTypeJSON,
    NKPostDataEncodingTypeForm,
    NKPostDataEncodingTypePlist
} NKPostDataEncodingType;

@interface OperationCache : NSObject

- (CommonNetworkOperation*) objectForKey:(NSString*)key;

@end

#pragma mark CommonNetworkEngine
/*!
 *  @class CommonNetworkEngine
 *  @abstract Represents a subclassable Network Engine for your app
 *
 *  @discussion
 *	This class is the heart of CommonNetworkEngine
 *  You create network operations and enqueue them here
 *  CommonNetworkEngine encapsulates a Reachability object that relieves you of managing network connectivity losses
 *  CommonNetworkEngine also allows you to provide custom header fields that gets appended automatically to every request
 */
@interface CommonNetworkEngine : NSObject

+ (OperationCache*) operationCache;

+ (CommonNetworkEngine *) getObject:(NSString*) hostName;

+ (CommonNetworkEngine *) getObject:(NSString*) hostName customHeaderFields:(NSDictionary*) headers;

+ (CommonNetworkEngine *) getObject:(NSString*) hostName apiPath:(NSString*) apiPath customHeaderFields:(NSDictionary*) headers;

+ (BOOL) operationExists:(NSString*) operationId;

+ (void) cancelRequest:(NSURL*) url;

+ (void) cancelOperation:(CommonNetworkOperation*) operation;

+ (void) cancelOperationBeneficiary:(id<NSCopying>) beneficiary;

/*!
 *  @abstract Creates a simple GET Operation with a request URL
 *
 *  @discussion
 *	Creates an operation with the given URL path.
 *  The default headers you specified in your CommonNetworkEngine subclass gets added to the headers
 *  The HTTP Method is implicitly assumed to be GET
 *
 */

-(CommonNetworkOperation*) operationWithPath:(NSString*) path;
-(CommonNetworkOperation*) operationWithPath:(NSString*) path beneficiary:(id<NSCopying>)beneficiary;

/*!
 *  @abstract Creates a simple GET Operation with a request URL and parameters
 *
 *  @discussion
 *	Creates an operation with the given URL path.
 *  The default headers you specified in your CommonNetworkEngine subclass gets added to the headers
 *  The body dictionary in this method gets attached to the URL as query parameters
 *  The HTTP Method is implicitly assumed to be GET
 *
 */
-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body;
-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body
                             beneficiary:(id<NSCopying>)beneficiary;

/*!
 *  @abstract Creates a simple GET Operation with a request URL, parameters and HTTP Method
 *
 *  @discussion
 *	Creates an operation with the given URL path.
 *  The default headers you specified in your CommonNetworkEngine subclass gets added to the headers
 *  The params dictionary in this method gets attached to the URL as query parameters if the HTTP Method is GET/DELETE
 *  The params dictionary is attached to the body if the HTTP Method is POST/PUT
 *  The HTTP Method is implicitly assumed to be GET
 */
-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body
                              httpMethod:(NSString*)method;
-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body
                              httpMethod:(NSString*)method
                             beneficiary:(id<NSCopying>)beneficiary;

/*!
 *  @abstract Creates a simple GET Operation with a request URL, parameters, HTTP Method and the SSL switch
 *
 *  @discussion
 *	Creates an operation with the given URL path.
 *  The ssl option when true changes the URL to https.
 *  The ssl option when false changes the URL to http.
 *  The default headers you specified in your CommonNetworkEngine subclass gets added to the headers
 *  The params dictionary in this method gets attached to the URL as query parameters if the HTTP Method is GET/DELETE
 *  The params dictionary is attached to the body if the HTTP Method is POST/PUT
 *  The previously mentioned methods operationWithPath: and operationWithPath:params: call this internally
 */
-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body
                              httpMethod:(NSString*)method
                                     ssl:(BOOL) useSSL;
-(CommonNetworkOperation*) operationWithPath:(NSString*) path
                                  params:(NSDictionary*) body
                              httpMethod:(NSString*)method
                                     ssl:(BOOL) useSSL
                             beneficiary:(id<NSCopying>)beneficiary;
/*!
 *  @abstract Creates a simple GET Operation with a request URL
 *
 *  @discussion
 *	Creates an operation with the given absolute URL.
 *  The hostname of the engine is *NOT* prefixed
 *  The default headers you specified in your CommonNetworkEngine subclass gets added to the headers
 *  The HTTP method is implicitly assumed to be GET.
 */
-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString;
-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString
                                  beneficiary:(id<NSCopying>)beneficiary;
/*!
 *  @abstract Creates a simple GET Operation with a request URL and parameters
 *
 *  @discussion
 *	Creates an operation with the given absolute URL.
 *  The hostname of the engine is *NOT* prefixed
 *  The default headers you specified in your CommonNetworkEngine subclass gets added to the headers
 *  The body dictionary in this method gets attached to the URL as query parameters
 *  The HTTP method is implicitly assumed to be GET.
 */
-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString
                                       params:(NSDictionary*) body;
-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString
                                       params:(NSDictionary*) body
                                  beneficiary:(id<NSCopying>)beneficiary;
/*!
 *  @abstract Creates a simple Operation with a request URL, parameters and HTTP Method
 *
 *  @discussion
 *	Creates an operation with the given absolute URL.
 *  The hostname of the engine is *NOT* prefixed
 *  The default headers you specified in your CommonNetworkEngine subclass gets added to the headers
 *  The params dictionary in this method gets attached to the URL as query parameters if the HTTP Method is GET/DELETE
 *  The params dictionary is attached to the body if the HTTP Method is POST/PUT
 *	This method can be over-ridden by subclasses to tweak the operation creation mechanism.
 *  You would typically over-ride this method to create a subclass of CommonNetworkOperation (if you have one). After you create it, you should call [super prepareHeaders:operation] to attach any custom headers from super class.
 *  @seealso
 *  prepareHeaders:
 */
-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString
                                       params:(NSDictionary*) body
                                   httpMethod:(NSString*) method;
-(CommonNetworkOperation*) operationWithURLString:(NSString*) urlString
                                       params:(NSDictionary*) body
                                   httpMethod:(NSString*) method
                                  beneficiary:(id<NSCopying>)beneficiary;
/*!
 *  @abstract adds the custom default headers
 *
 *  @discussion
 *	This method adds custom default headers to the factory created CommonNetworkOperation.
 *	This method can be over-ridden by subclasses to add more default headers if necessary.
 *  You would typically over-ride this method if you have over-ridden operationWithURLString:params:httpMethod:.
 *  @seealso
 *  operationWithURLString:params:httpMethod:
 */
-(void) prepareHeaders:(CommonNetworkOperation*) operation;

#if TARGET_OS_IPHONE
- (CommonNetworkOperation*)fileAtURL:(NSURL *)url completionHandler:(NKUrlBlock) fileFetchedBlock errorHandler:(NKErrorBlock) errorBlock;
- (CommonNetworkOperation*)fileAtURL:(NSURL *)url completionHandler:(NKUrlBlock) fileFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary;
- (CommonNetworkOperation*)fileAtURL:(NSURL *)url completionHandler:(NKUrlBlock) fileFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary startImmediately:(BOOL)startImmediately;

/*!
 *  @abstract Handy helper method for fetching images
 *
 *  @discussion
 *	Creates an operation with the given image URL.
 *  The hostname of the engine is *NOT* prefixed.
 *  The image is returned to the caller via NKImageBlock callback block.
 */
- (CommonNetworkOperation*)imageAtURL:(NSURL *)url onCompletion:(NKImageBlock) imageFetchedBlock DEPRECATED_ATTRIBUTE;

/*!
 *  @abstract Handy helper method for fetching images in the background
 *
 *  @discussion
 *	Creates an operation with the given image URL.
 *  The hostname of the engine is *NOT* prefixed.
 *  The image is returned to the caller via NKImageBlock callback block. This image is resized as per the size and decompressed in background.
 *  @seealso
 *  imageAtUrl:onCompletion:
 */
- (CommonNetworkOperation*)imageAtURL:(NSURL *)url completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock;
- (CommonNetworkOperation*)imageAtURL:(NSURL *)url completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary;
- (CommonNetworkOperation*)imageAtURL:(NSURL *)url completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary startImmediately:(BOOL)startImmediately;

/*!
 *  @abstract Handy helper method for fetching images asynchronously in the background
 *
 *  @discussion
 *	Creates an operation with the given image URL.
 *  The hostname of the engine is *NOT* prefixed.
 *  The image is returned to the caller via NKImageBlock callback block. This image is resized as per the size and decompressed in background.
 *  @seealso
 *  imageAtUrl:onCompletion:
 */
- (CommonNetworkOperation*)imageAtURL:(NSURL *)url size:(CGSize) size completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock;
- (CommonNetworkOperation*)imageAtURL:(NSURL *)url size:(CGSize) size completionHandler:(NKImageBlock) imageFetchedBlock errorHandler:(NKErrorBlock) errorBlock beneficiary:(id<NSCopying>)beneficiary;
#endif

/*!
 *  @abstract Enqueues your operation into the shared queue
 *
 *  @discussion
 *	The operation you created is enqueued to the shared queue. If the response for this operation was previously cached, the cached data will be returned.
 *  @seealso
 *  enqueueOperation:forceReload:
 */
-(void) enqueueOperation:(CommonNetworkOperation*) request;

/*!
 *  @abstract Enqueues your operation into the shared queue.
 *
 *  @discussion
 *	The operation you created is enqueued to the shared queue.
 *  When forceReload is NO, this method behaves like enqueueOperation:
 *  When forceReload is YES, No cached data will be returned even if cached data is available.
 *  @seealso
 *  enqueueOperation:
 */
-(void) enqueueOperation:(CommonNetworkOperation*) operation forceReload:(BOOL) forceReload;

/*!
 *  @abstract HostName of the engine
 *  @property readonlyHostName
 *
 *  @discussion
 *	Returns the host name of the engine
 *  This property is readonly cannot be updated.
 *  You normally initialize an engine with its hostname using the initWithHostName:customHeaders: method
 */
@property (readonly, copy, nonatomic) NSString *readonlyHostName;

/*!
 *  @abstract Port Number that should be used by URL creating factory methods
 *  @property portNumber
 *
 *  @discussion
 *	Set a port number for your engine if your remote URL mandates it.
 *  This property is optional and you DON'T have to specify the default HTTP port 80
 */
@property (assign, nonatomic) int portNumber;

/*!
 *  @abstract Sets an api path if it is different from root URL
 *  @property apiPath
 *
 *  @discussion
 *	You can use this method to set a custom path to the API location if your server's API path is different from root (/)
 *  This property is optional
 */
@property (copy, nonatomic) NSString* apiPath;

/*!
 *  @abstract Handler that you implement to monitor reachability changes
 *  @property reachabilityChangedHandler
 *
 *  @discussion
 *	The framework calls this handler whenever the reachability of the host changes.
 *  The default implementation freezes the queued operations and stops network activity
 *  You normally don't have to implement this unless you need to show a HUD notifying the user of connectivity loss
 */
@property (copy, nonatomic) void (^reachabilityChangedHandler)(NetworkStatus ns);

/*!
 *  @abstract Registers an associated operation subclass
 *
 *  @discussion
 *	When you override both CommonNetworkEngine and CommonNetworkOperation, you might want the engine's factory method
 *  to prepare operations of your CommonNetworkOperation subclass. To create your own CommonNetworkOperation subclasses from the factory method, you can register your CommonNetworkOperation subclass using this method.
 *  This method is optional. If you don't use, factory methods in CommonNetworkEngine creates CommonNetworkOperation objects.
 */
-(void) registerOperationSubclass:(Class) aClass;

-(void) saveCache;

/*!
 *  @abstract Cache Directory In Memory Cost
 *
 *  @discussion
 *	This method can be over-ridden by subclasses to provide an alternative in memory cache size.
 *  By default, MKNetworkKit caches 10 recent requests in memory
 *  The default size is 10
 *  Overriding this method is optional
 */
-(int) cacheMemoryCost;

/*!
 *  @abstract Enable Caching
 *
 *  @discussion
 *	This method should be called explicitly to enable caching for this engine.
 *  By default, MKNetworkKit doens't cache your requests.
 *  The cacheMemoryCost and cacheDirectoryName will be used when you turn caching on using this method.
 */
-(void) useCache;

/*!
 *  @abstract Empties previously cached data
 *
 *  @discussion
 *	This method is a handy helper that you can use to clear cached data.
 *  By default, MKNetworkKit doens't cache your requests. Use this only when you enabled caching
 *  @seealso
 *  useCache
 */
+(void) emptyCache;

/*!
 *  @abstract Checks current reachable status
 *
 *  @discussion
 *	This method is a handy helper that you can use to check for network reachability.
 */
-(BOOL) isReachable;

-(NSString*)getCachedItem:(CommonNetworkOperation*)operation;

- (void) stopDownload:(NSString *)path params:(NSDictionary*) body;

- (void) freezeOperations;

- (void) checkAndRestoreFrozenOperations;

- (NSString*) expirationDirectory;

@property (copy, nonatomic) NSString *hostName;

@end

#pragma mark OperationRecord

@interface OperationRecord : NSObject<NSCoding>

@property (strong, nonatomic) NSString* identifier;
@property (strong, nonatomic) NSString* owner;
@property (assign, nonatomic) CommonNetworkOperationState status;
@property (nonatomic, assign) BOOL isTraceable; //Whether to keep the operation state even if it completes. Default NO.
@property (nonatomic, assign) BOOL isPersistable; //Whether to save the operation state. Default NO.
@property (nonatomic, assign) BOOL isRestorable; //Whether to restore the operation when network is available. Default NO.
@property (nonatomic, assign) BOOL isCacheable; //Whether to cache the response. Default NO.
@property (strong, nonatomic) NSURL* url;
@property (strong, nonatomic) NSString* httpMethod;
@property (strong, nonatomic) NSDictionary* parameters;
@property (strong, nonatomic) NSDictionary* headers;
@property (strong, nonatomic) NSString* userName;
@property (strong, nonatomic) NSString* password;
@property (assign, nonatomic) HTTPAuthType authType;
@property (assign, nonatomic) NSStringEncoding stringEncoding;
@property (strong, nonatomic) NSString* clientCertificate;
@property (nonatomic, assign) NSURLCredentialPersistence credentialPersistence;
@property (assign, nonatomic) NSUInteger unitCompleted;
@property (assign, nonatomic) NSUInteger unitTotal;
@property (assign, nonatomic) NSUInteger uploadSizePerRequest;
@property (strong, nonatomic) NSString* prop1;
@property (strong, nonatomic) NSString* prop2;
@property (strong, nonatomic) NSString* prop3;
@property (strong, nonatomic) NSString* prop4;
@property (strong, nonatomic) id<NSCoding> others;
@property (strong, nonatomic) NSDate* createDateTime;
@property (strong, nonatomic) NSDate* modDateTime;
@property (assign, nonatomic) NKPostDataEncodingType postDataEncoding;
@property (strong, nonatomic) NSString* boundary;
@end

#pragma mark CommonNetworkOperation
/*!
 *  @class CommonNetworkOperation
 *  @abstract Represents a single unique network operation.
 *
 *  @discussion
 *	You normally create an instance of this class using the methods exposed by CommonNetworkEngine
 *  Created operations are enqueued into the shared queue on CommonNetworkEngine
 *  CommonNetworkOperation encapsulates both request and response
 *  Printing a CommonNetworkOperation prints out a cURL command that can be copied and pasted directly on terminal
 *  Oerations are serialized when network connectivity is lost and performed when connection is restored
 */
@interface CommonNetworkOperation : NSOperation<NSCoding> {
}

/*!
 *  @abstract Get the beneficiary component associated with the operation
 *  @property beneficiary
 *
 *  This property gives a way to fetch the operation by the component which is defined by category class and not able to
 *  hold the reference to the operation in its memeber. Any operation that has reference to the component is created for
 *  it, can be cancelled if it is deemed to be unnecessary.
 */
@property (nonatomic, strong, getter = getBeneficiary) id beneficiary;

/*!
 *  @abstract Request URL Property
 *  @property url
 *
 *  @discussion
 *	Returns the operation's URL
 *  This property is readonly cannot be updated.
 *  To create an operation with a specific URL, use the operationWithURLString:params:httpMethod:
 */
@property (nonatomic, copy, readonly) NSURL *url;

/*!
 *  @abstract The internal request object
 *  @property readonlyRequest
 *
 *  @discussion
 *	Returns the operation's actual request object
 *  This property is readonly cannot be modified.
 *  To create an operation with a new request, use the operationWithURLString:params:httpMethod:
 */
@property (nonatomic, strong, readonly) NSURLRequest *readonlyRequest;

/*!
 *  @abstract The internal HTTP Response Object
 *  @property readonlyResponse
 *
 *  @discussion
 *	Returns the operation's actual response object
 *  This property is readonly cannot be updated.
 */
@property (nonatomic, strong, readonly) NSHTTPURLResponse *readonlyResponse;

/*!
 *  @abstract The internal HTTP Post data values
 *  @property readonlyPostDictionary
 *
 *  @discussion
 *	Returns the operation's post data dictionary
 *  This property is readonly cannot be updated.
 *  Rather, updating this post dictionary doesn't have any effect on the CommonNetworkOperation.
 *  Use the addHeaders method to add post data parameters to the operation.
 *
 *  @seealso
 *   addHeaders:
 */
@property (nonatomic, copy, readonly) NSDictionary *readonlyPostDictionary;

/*!
 *  @abstract The internal request object's method type
 *  @property HTTPMethod
 *
 *  @discussion
 *	Returns the operation's method type
 *  This property is readonly cannot be modified.
 *  To create an operation with a new method type, use the operationWithURLString:params:httpMethod:
 */
@property (nonatomic, copy, readonly) NSString *HTTPMethod;

/*!
 *  @abstract The internal response object's status code
 *  @property HTTPStatusCode
 *
 *  @discussion
 *	Returns the operation's response's status code.
 *  Returns 0 when the operation has not yet started and the response is not available.
 *  This property is readonly cannot be modified.
 */
@property (nonatomic, assign, readonly) NSInteger HTTPStatusCode;

/*!
 *  @abstract Post Data Encoding Type Property
 *  @property postDataEncoding
 *
 *  @discussion
 *  Specifies which type of encoding should be used to encode post data.
 *  NKPostDataEncodingTypeURL is the default which defaults to application/x-www-form-urlencoded
 *  NKPostDataEncodingTypeJSON uses JSON encoding.
 *
 *
 */
@property (nonatomic, assign, setter = setPostDataEncoding:) NKPostDataEncodingType postDataEncoding;

/*!
 *  @abstract String Encoding Property
 *  @property stringEncoding
 *
 *  @discussion
 *  Specifies which type of encoding should be used to encode URL strings
 */
@property (nonatomic, assign) NSStringEncoding stringEncoding;

/*!
 *  @abstract Error object
 *  @property error
 *
 *  @discussion
 *	If the network operation results in an error, this will hold the response error, otherwise it will be nil
 */
@property (nonatomic, readonly, strong) NSError *error;

@property (strong, nonatomic) NSMutableDictionary *requestHeaders;

@property (nonatomic, assign) CommonNetworkOperationState state;

@property (assign, nonatomic) NSUInteger uploadSizePerRequest;

@property (assign, nonatomic) NSUInteger downloadSizePerRequest;

@property (nonatomic, assign) BOOL isPersistable;

@property (nonatomic, assign) BOOL isRestorable;

@property (nonatomic, assign) BOOL isTraceable;

@property (nonatomic, assign) BOOL isCacheable;

@property (nonatomic, readonly) NSDate* expiresOnDate;

@property (nonatomic, assign) NSUInteger unitCompleted;

@property (nonatomic, assign) NSUInteger unitTotal;

@property (nonatomic, readonly) NSDictionary* downloadInfo;

@property (nonatomic, strong) NSString* boundary;

@property (nonatomic, strong) NSString* etag;

@property (nonatomic, strong) NSString* cachedItemPath;

/*!
 *  @abstract Authentication methods
 *
 *  @discussion
 *	If your request needs to be authenticated, set your username and password using this method.
 */
-(void) setUsername:(NSString*) name password:(NSString*) password;

-(void) setBasicAuthUsername:(NSString*) username password:(NSString*) password;

-(void) setDigestAuthUsername:(NSString*) username password:(NSString*) password;

/*!
 *  @abstract Authentication methods (Client Certificate)
 *  @property clientCertificate
 *
 *  @discussion
 *	If your request needs to be authenticated using a client certificate, set the certificate path here
 */
@property (copy, nonatomic) NSString *clientCertificate;

/*!
 *  @abstract Custom authentication handler
 *  @property authHandler
 *
 *  @discussion
 *	If your request needs to be authenticated using a custom method (like a Web page/HTML Form), add a block method here
 *  and process the NSURLAuthenticationChallenge
 */
@property (nonatomic, copy) NKAuthBlock authHandler;

/*!
 *  @abstract controls persistence of authentication credentials
 *  @property credentialPersistence
 *
 *  @discussion
 *  The default value is set to NSURLCredentialPersistenceForSession, change it to NSURLCredentialPersistenceNone to avoid caching issues (isse #35)
 */
@property (nonatomic, assign) NSURLCredentialPersistence credentialPersistence;
#if TARGET_OS_IPHONE

/*!
 *  @abstract notification that has to be shown when an error occurs and the app is in background
 *  @property localNotification
 *
 *  @discussion
 *  The default value nil. No notification is shown when an error occurs.
 *  To show a notification when the app is in background and the network operation running in background fails,
 *  set this parameter to a UILocalNotification object
 */
@property (nonatomic, strong) UILocalNotification *localNotification;

/*!
 *  @abstract Shows a local notification when an error occurs
 *  @property shouldShowLocalNotificationOnError
 *
 *  @discussion
 *  The default value NO. No notification is shown when an error occurs.
 *  When set to YES, MKNetworkKit shows the NSError localizedDescription text as a notification when the app is in background and the network operation ended in error.
 *  To customize the local notification text, use the property localNotification
 
 *  @seealso
 *  localNotification
 */
@property (nonatomic, assign) BOOL shouldShowLocalNotificationOnError;
#endif

-(void) removeHandlersFromBeneficiary:(id<NSCopying>)beneficiary;

/*!
 *  @abstract Add additional header parameters
 *
 *  @discussion
 *	If you ever need to set additional headers after creating your operation, you this method.
 *  You normally set default headers to the engine and they get added to every request you create.
 *  On specific cases where you need to set a new header parameter for just a single API call, you can use this
 */
-(void) addHeaders:(NSDictionary*) headersDictionary;

/*!
 *  @abstract Sets the authorization header after prefixing it with a given auth type
 *
 *  @discussion
 *	If you need to set the HTTP Authorization header, you can use this convinience method.
 *  This method internally calls addHeaders:
 *  The authType parameter is a string that you can prefix to your auth token to tell your server what kind of authentication scheme you want to use. HTTP Basic Authentication uses the string "Basic" for authType
 *  To use HTTP Basic Authentication, consider using the method setUsername:password:basicAuth: instead.
 *
 *  Example
 *  [op setToken:@"abracadabra" forAuthType:@"Token"] will set the header value to
 *  "Authorization: Token abracadabra"
 *
 *  @seealso
 *  setUsername:password:basicAuth:
 *  addHeaders:
 */
-(void) setAuthorizationHeaderValue:(NSString*) token forAuthType:(NSString*) authType;

/*!
 *  @abstract Attaches a file to the request
 *
 *  @discussion
 *	This method lets you attach a file to the request
 *  The method has a side effect. It changes the HTTPMethod to "POST" regardless of what it was before.
 *  It also changes the post format to multipart/form-data
 *  The mime-type is assumed to be application/octet-stream
 */
-(void) addFile:(NSString*) filePath forKey:(NSString*) key;

/*!
 *  @abstract Attaches a file to the request and allows you to specify a mime-type
 *
 *  @discussion
 *	This method lets you attach a file to the request
 *  The method has a side effect. It changes the HTTPMethod to "POST" regardless of what it was before.
 *  It also changes the post format to multipart/form-data
 */
-(void) addFile:(NSString*) filePath forKey:(NSString*) key mimeType:(NSString*) mimeType;

/*!
 *  @abstract adds a block Handler for completion and error
 *
 *  @discussion
 *	This method sets your completion and error blocks. If your operation's response data was previously called,
 *  the completion block will be called almost immediately with the cached response. You can check if the completion
 *  handler was invoked with a cached data or with real data by calling the isCachedResponse method.
 *
 *  @seealso
 *  onCompletion:onError:
 */
-(void) addCompletionHandler:(NKResponseBlock) response errorHandler:(NKErrorBlock) error;

/*!
 *  @abstract Block Handler for tracking upload progress
 *
 *  @discussion
 *	This method can be used to update your progress bars when an upload is in progress.
 *  The value range of the progress is 0 to 1.
 *
 */
-(void) onUploadProgressChanged:(NKProgressBlock) uploadProgressBlock;

/*!
 *  @abstract Block Handler for tracking download progress
 *
 *  @discussion
 *	This method can be used to update your progress bars when a download is in progress.
 *  The value range of the progress is 0 to 1.
 *
 */
-(void) onDownloadProgressChanged:(NKProgressBlock) downloadProgressBlock;

/*!
 *  @abstract Helper method to retrieve the contents as a NSString
 *
 *  @discussion
 *	This method is used for accessing the downloaded data. If the operation is still in progress, the method returns nil instead of partial data. To access partial data, use a downloadStream. The method also converts the responseData to a NSString using the stringEncoding specified in the operation
 *
 *  @seealso
 *  addDownloadStream:
 *  stringEncoding
 */
-(NSString*)responseString;

/*!
 *  @abstract Helper method to print the request as a cURL command
 *
 *  @discussion
 *	This method is used for displaying the request you created as a cURL command
 *
 */
-(NSString*) curlCommandLineString;

-(NSData*) responseData;

/*!
 *  @abstract Helper method to retrieve the contents as a NSString encoded using a specific string encoding
 *
 *  @discussion
 *	This method is used for accessing the downloaded data. If the operation is still in progress, the method returns nil instead of partial data. To access partial data, use a downloadStream. The method also converts the responseData to a NSString using the stringEncoding specified in the parameter
 *
 *  @seealso
 *  addDownloadStream:
 *  stringEncoding
 */
-(NSString*) responseStringWithEncoding:(NSStringEncoding) encoding;

/*!
 *  @abstract Helper method to retrieve the contents as a UIImage
 *
 *  @discussion
 *	This method is used for accessing the downloaded data as a UIImage. If the operation is still in progress, the method returns nil instead of a partial image. To access partial data, use a downloadStream. If the response is not a valid image, this method returns nil. This method doesn't obey the response mime type property. If the server response with a proper image data but set the mime type incorrectly, this method will still be able access the response as an image.
 *
 *  @seealso
 *  addDownloadStream:
 */
#if TARGET_OS_IPHONE
-(UIImage*) responseImage;
-(void) decompressedResponseImageOfSize:(CGSize) size completionHandler:(void (^)(UIImage *decompressedImage)) imageDecompressionHandler;
#elif TARGET_OS_MAC
-(NSImage*) responseImage;
-(NSXMLDocument*) responseXML;
#endif

/*!
 *  @abstract Helper method to retrieve the contents as a NSDictionary or NSArray depending on the JSON contents
 *
 *  @discussion
 *	This method is used for accessing the downloaded data as a NSDictionary or an NSArray. If the operation is still in progress, the method returns nil. If the response is not a valid JSON, this method returns nil.
 *
 *  @seealso
 *  responseJSONWithCompletionHandler:
 
 *  @availability
 *  iOS 5 and above or Mac OS 10.7 and above
 */
-(id) responseJSON;

/*!
 *  @abstract Helper method to retrieve the contents as a NSDictionary or NSArray depending on the JSON contents in the background
 *
 *  @discussion
 *	This method is used for accessing the downloaded data as a NSDictionary or an NSArray. If the operation is still in progress, the method returns nil. If the response is not a valid JSON, this method returns nil. The difference between this and responseJSON is that, this method decodes JSON in the background.
 *
 *  @availability
 *  iOS 5 and above or Mac OS 10.7 and above
 */
-(void) responseJSONWithCompletionHandler:(void (^)(id jsonObject)) jsonDecompressionHandler;
/*!
 *  @abstract Overridable custom method where you can add your custom business logic error handling
 *
 *  @discussion
 *	This optional method can be overridden to do custom error handling. Be sure to call [super operationSucceeded] at the last.
 *  For example, a valid HTTP response (200) like "Item not found in database" might have a custom business error code
 *  You can override this method and called [super failWithError:customError]; to notify that HTTP call was successful but the method
 *  ended as a failed call
 *
 */
-(void) operationSucceeded;

/*!
 *  @abstract Overridable custom method where you can add your custom business logic error handling
 *
 *  @discussion
 *	This optional method can be overridden to do custom error handling. Be sure to call [super operationSucceeded] at the last.
 *  For example, a invalid HTTP response (401) like "Unauthorized" might be a valid case in your app.
 *  You can override this method and called [super operationSucceeded]; to notify that HTTP call failed but the method
 *  ended as a success call. For example, Facebook login failed, but to your business implementation, it's not a problem as you
 *  are going to try alternative login mechanisms.
 *
 */
-(void) operationFailedWithError:(NSError*) error;

// internal methods called by CommonNetworkEngine only.
// Don't touch
-(void) setCacheHandler:(NKCacheBlock) cacheHandler;
-(void) setCancelHandler:(NKCancelBlock) cancelHandler;
-(void) updateHandlersFromOperation:(CommonNetworkOperation*) operation;
-(void) removeHandlersFromOperation:(CommonNetworkOperation*) operation;
-(BOOL) hasHandlers;
-(void) updateOperationBasedOnPreviousOperation:(CommonNetworkOperation*)operation;
-(NSString*) uniqueIdentifier;

- (id)initWithURLString:(NSString *)aURLString
                 params:(NSDictionary *)params
             httpMethod:(NSString *)method beneficiary:(id<NSCopying>)beneficiary;

-(void) setFileToBeSaved:(NSURL*) fileUrl;
-(BOOL) hasFileToBeSaved;
-(BOOL) hasFileToBeSaved:(NSURL*) fileUrl;
-(void) stop;
@end

#endif
