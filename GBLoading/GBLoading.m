//
//  GBLoading.m
//  GBLoading
//
//  Created by Luka Mirosevic on 11/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import "GBLoading.h"

#import "GBLoadingCachingLayerProtocol.h"
#import "GBPersistentInMemoryCache.h"

#import <GBStorage/GBStorage.h>

static NSUInteger const kDefaultMaxConcurrentRequests =                                     6;
#define kDefaultMaxInMemoryCacheCapacity                                                    kGBStorageMemoryCapUnlimited
static BOOL const kDefaultShouldPersistToDisk =                                             NO;
static BOOL const kDefaultShouldCheckResourceFreshnessWithServer =                          NO;
static BOOL const kDefaultShouldFallbackToPotentiallyStaleCachedResourceInCaseOfError =     YES;

@interface GBLoadingEgressHandler : NSObject

@property (copy, nonatomic) GBLoadingSuccessBlock                                           success;
@property (copy, nonatomic) GBLoadingFailureBlock                                           failure;

@property (assign, nonatomic) GBLoadingState                                                state;
@property (assign, nonatomic) BOOL                                                          isCompleted;

+ (GBLoadingEgressHandler *)egressHandlerWithSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
- (id)initWithSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;

- (void)executeWithOptionalProcessedObject:(id)processedObject;

@end

@implementation GBLoadingEgressHandler

+ (GBLoadingEgressHandler *)egressHandlerWithSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    return [[self alloc] initWithSuccess:success failure:failure];
}

- (id)initWithSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    if (self = [super init]) {
        self.success = success;
        self.failure = failure;
        self.state = GBLoadingStateNormal;
        self.isCompleted = NO;
    }
    
    return self;
}

- (void)executeWithOptionalProcessedObject:(id)processedObject {
    self.isCompleted = YES;
    
    switch (self.state) {
        case GBLoadingStateNormal: {
            if (self.success) self.success(processedObject);
        } break;
            
        case GBLoadingStateFailure: {
            if (self.failure) self.failure(NO);
        } break;
            
        case GBLoadingStateCancellation: {
            if (self.failure) self.failure(YES);
        } break;
    }
}

@end

@interface GBLoadingCanceller ()

@property (weak, nonatomic) GBLoadingEgressHandler                                          *egressHandler;

@end

@implementation GBLoadingCanceller

#pragma mark - API

- (void)cancel {
    if (!self.egressHandler.isCompleted) {
        self.egressHandler.state = GBLoadingStateCancellation;
    }
}

#pragma mark - util

+ (GBLoadingCanceller *)_cancellerWithEgressHandler:(GBLoadingEgressHandler *)egressHandler {
    return [[self alloc] _initWithEgressHandler:egressHandler];
}

- (id)_initWithEgressHandler:(GBLoadingEgressHandler *)egressHandler {
    if (self = [super init]) {
        self.egressHandler = egressHandler;
    }
    
    return self;
}

@end

@interface GBLoading ()

@property (strong, nonatomic) GBPersistentInMemoryCache                                     *cache;
@property (strong, nonatomic) NSMutableDictionary                                           *handlerQueues;
@property (strong, nonatomic) NSOperationQueue                                              *loadOperationQueue;

@end

@implementation GBLoading

#pragma mark - memory

+ (instancetype)sharedLoading {
    static GBLoading *_sharedLoading;
    @synchronized(self) {
        if (!_sharedLoading) {
            _sharedLoading = [self new];
        }
    }
    
    return _sharedLoading;
}

- (id)init {
    if (self = [super init]) {
        self.cache = [GBPersistentInMemoryCache new];
        self.handlerQueues = [NSMutableDictionary new];
        self.loadOperationQueue = [NSOperationQueue new];
        self.loadOperationQueue.maxConcurrentOperationCount = kDefaultMaxConcurrentRequests;
        self.maxInMemoryCacheCapacity = kDefaultMaxInMemoryCacheCapacity;
        self.shouldPersistToDisk = kDefaultShouldPersistToDisk;
        self.shouldCheckResourceFreshnessWithServer = kDefaultShouldCheckResourceFreshnessWithServer;
        self.shouldFallbackToPotentiallyStaleCachedResourceInCaseOfError = kDefaultShouldFallbackToPotentiallyStaleCachedResourceInCaseOfError;
    }
    return self;
}

- (void)dealloc {        
    self.cache = nil;
    
    //process all handler queues
    for (NSString *resource in self.handlerQueues) {
        //set all their states to failed
        [self _markAllEgressHandlersForResource:resource asBeingInState:GBLoadingStateFailure];
        
        //execute them all
        [self _processEgressQueueForResource:resource withOptionalProcessedObject:nil];
    }
    //now it's safe to remove them all
    self.handlerQueues = nil;
    
    self.loadOperationQueue = nil;
}

#pragma mark - CA

- (void)setMaxInMemoryCacheCapacity:(NSUInteger)maxInMemoryCacheCapacity {
    self.cache.maxInMemoryCacheCapacity = maxInMemoryCacheCapacity;
}

- (NSUInteger)maxInMemoryCacheCapacity {
    return self.cache.maxInMemoryCacheCapacity;
}

- (void)setMaxConcurrentRequests:(NSInteger)maxConcurrentRequests {
    self.loadOperationQueue.maxConcurrentOperationCount = maxConcurrentRequests;
}

- (NSInteger)maxConcurrentRequests {
    return self.loadOperationQueue.maxConcurrentOperationCount;
}

- (void)setShouldPersistToDisk:(BOOL)shouldPersistToDisk {
    self.cache.shouldPersistToDisk = shouldPersistToDisk;
}

- (BOOL)shouldPersistToDisk {
    return self.cache.shouldPersistToDisk;
}

#pragma mark - API

- (void)removeResourceFromCache:(NSString *)resource {
    if ([self _isValidResourceString:resource]) {
        [self.cache removeResourceForKey:resource];
    }
}

- (void)clearCache {
    [self.cache clear];
}

- (void)cancelLoadForResource:(NSString *)resource {
    if ([self _isValidResourceString:resource]) {
        [self _cancelLoadForResource:resource];
    }
}

- (BOOL)isResourceInCache:(NSString *)resource {
    if ([self _isValidResourceString:resource]) {
        return ([self.cache getResourceDataForKey:resource] != nil);
    }
    else {
        return NO;
    }
}

- (id)cachedObjectForResource:(NSString *)resource {
    if ([self _isValidResourceString:resource]) {
        return [self.cache getResourceDataForKey:resource];
    }
    else {
        return nil;
    }
}

- (BOOL)isLoadingResource:(NSString *)resource {
    if ([self _isValidResourceString:resource]) {
        return [self _isLoadingResource:resource];
    }
    else {
        return NO;
    }
}

- (void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    [self loadResource:resource withBackgroundProcessor:nil success:success failure:failure canceller:nil];
}

- (void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller {
    [self loadResource:resource withBackgroundProcessor:nil success:success failure:failure canceller:canceller];
}

- (void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    [self loadResource:resource withBackgroundProcessor:processor success:success failure:failure canceller:nil];
}

- (void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller {
    // if the resource is a valid URL
    if ([self _isValidResourceString:resource]) {
        // proceed with loading the resource
        [self _loadResource:resource withBackgroundProcessor:processor success:success failure:failure canceller:canceller];
    }
    // the resource URL was invalid
    else {
        // immediately call the failure handler
        if (failure) failure(NO);
    }
}

#pragma mark - Private

- (BOOL)_isValidResourceString:(NSString *)resource {
    BOOL isString = [resource isKindOfClass:NSString.class];
    BOOL isNonEmpty = resource.length > 0;
    BOOL isValidURL = [NSURL URLWithString:resource] != nil;
    
    return (isString && isNonEmpty && isValidURL);
}

- (void)_markAllEgressHandlersForResource:(NSString *)resource asBeingInState:(GBLoadingState)state {
    for (GBLoadingEgressHandler *egressHandler in self.handlerQueues[resource]) {
        egressHandler.state = state;
    }
}

- (BOOL)_isLoadingResource:(NSString *)resource {
    //we know it's loading if there is anything in the queue, because once a load finishes we always clear the entire queue
    BOOL areEgressHandlersEnqueued = ([self _egressQueueForResource:resource].count > 0);

    return (areEgressHandlersEnqueued);
}

- (void)_cancelLoadForResource:(NSString *)resource {
    //we just set the cancelled flag on all our enqueued resources, this might mask a failure, however the client probably doesn't care at this point since he clearly no longer wants the object for the resource
    for (GBLoadingEgressHandler *egressHandler in [self _egressQueueForResource:resource]) {
        egressHandler.state = GBLoadingStateCancellation;
    }
}

- (void)_loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller {
    //first check if this resource is already being loaded
    BOOL isLoadingResource = [self _isLoadingResource:resource];
    
    //in any case we need an egress handler
    GBLoadingEgressHandler *egressHandler = [GBLoadingEgressHandler egressHandlerWithSuccess:success failure:failure];
    
    //and we always want to enqueue it (because we always want the client to know what happened)
    [self _enqueueEgressHandler:egressHandler forResource:resource];
    
    //if the caller wants a canceller object, we should give him one
    if (canceller) {
        *canceller = [GBLoadingCanceller _cancellerWithEgressHandler:egressHandler];
    }
    
    //we now optionally kick off a fetchAndProcess
    if (!isLoadingResource) {
        [self _fetchAndProcessResource:resource withProcessor:processor];
    }
    else {
        //in this case we don't have to do anything, because the entire queue will get called once the already running fetch finishes
    }
}

- (void)_fetchAndProcessResource:(NSString *)resource withProcessor:(GBLoadingBackgroundProcessorBlock)processor {
    //we can assume the values coming in are valid, our principle is: we trust our private methods, but we don't trust the public ones
    
    //->bg thread
    [self.loadOperationQueue addOperationWithBlock:^{
        NSData *data;
        NSHTTPURLResponse *response;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:resource]];
        [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];// this forces NSURLConnection not to cache stuff, that's ok as we're manually caching ourselves
        
        if (self.shouldCheckResourceFreshnessWithServer) {
            // get the version of the cached resource, if any
            NSString *eTag = [self.cache getResourceMetaForKey:resource];
            
            // attempt to load resource with the ETag set
            if (eTag) [request setValue:eTag forHTTPHeaderField:@"If-None-Match"];
            
            NSError *error;
            data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            
            // if the status is 304... or in case of error with laxed requirements...
            if (response.statusCode == 304 || (error && self.shouldFallbackToPotentiallyStaleCachedResourceInCaseOfError)) {
                // it means server didn't return any data, so get the locally cached data for the resource
                data = [self.cache getResourceDataForKey:resource];
            }
            // else if got some data
            else if (data) {
                // get the resource
                // noop, it's already been gotten (into *data)

                // get ETag
                NSString *freshETag = response.allHeaderFields[@"ETag"];
                
                // cache it
                [self.cache cacheResource:data withMeta:freshETag size:data.length forKey:resource];
            }
        }
        else {
            // attempt to fetch from cache
            data = [self.cache getResourceDataForKey:resource];
            
            // if we don't have it in the cache...
            if (!data) {
                // go get it from the server
                data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
                
                // if we got something...
                if (data) {
                    // add it to the cache
                    [self.cache cacheResource:data withMeta:nil size:data.length forKey:resource];
                }
            }
        }

        // process the data if there is a processor set
        id object;
        if (processor) {
            object = processor(data);
        }
        else {
            object = data;
        }

        //->fg thread
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            // if we don't have anything now, then mark the resource as failed
            if (!object) {
                //if we don't have a processed object, then it's safe to say we failed by marking all egress handlers as such
                [self _markAllEgressHandlersForResource:resource asBeingInState:GBLoadingStateFailure];
            }
            
            //process the queue
            [self _processEgressQueueForResource:resource withOptionalProcessedObject:object];
        }];
    }];
}

- (void)_processEgressQueueForResource:(NSString *)resource withOptionalProcessedObject:(id)processedObject {
    //process everything on the queue
    for (GBLoadingEgressHandler *egressHandler in [self _egressQueueForResource:resource]) {
        [egressHandler executeWithOptionalProcessedObject:processedObject];
    }
    
    //empty the queue
    [self _emptyQueueForResource:resource];
}

- (void)_enqueueEgressHandler:(GBLoadingEgressHandler *)egressHandler forResource:(NSString *)resource {
    [[self _egressQueueForResource:resource] addObject:egressHandler];
}

- (NSMutableArray *)_egressQueueForResource:(NSString *)resource {
    id egressQeueu = self.handlerQueues[resource];
    
    //create it if it doesn't exist
    if (!egressQeueu) {
        egressQeueu = [NSMutableArray new];
        self.handlerQueues[resource] = egressQeueu;
    }
    
    return egressQeueu;
}

- (void)_emptyQueueForResource:(NSString *)resource {
    [self.handlerQueues removeObjectForKey:resource];
}

@end
