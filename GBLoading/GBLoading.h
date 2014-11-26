//
//  GBLoading.h
//  GBLoading
//
//  Created by Luka Mirosevic on 11/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GBLoading_Types.h"
#import "GBLoading_StandardProcessors.h"
#import "GBLoadingCanceller.h"

@protocol GBLoadingCachingLayer;

@interface GBLoading : NSObject

/**
 Sets how many concurrent requests are allowed to run simultaneously.
 
 Set NSOperationQueueDefaultMaxConcurrentOperationCount for automatic.
 
 Default: 6
 */
@property (assign, nonatomic) NSInteger         maxConcurrentRequests;

/**
 Sets the in memory cache capacity, once exceeded, old items will be expunged. "Old items" is intentionally vague here.
 
 Default: kGBStorageMemoryCapUnlimited
 */
@property (assign, nonatomic) NSUInteger        maxInMemoryCacheCapacity;

/**
 Set whether downloaded resources should be cached to disk.
 
 Default: NO
 */
@property (assign, nonatomic) BOOL              shouldPersistToDisk;

/**
 When set to YES, the library will ping the server to make sure the resource is fresh and if so use the one from the local cache with no data transferred from the server other than a freshness acknwledgement (this works using the ETag so make sure your remote resources have them set, otherwise it will end up redownloading the resource every time, even if it's already in the cache). When set to NO, the library will consult the local cache for the resource first, and if it finds it will immediately return it with no server hop, otherwise it will go fetch the resources, this mode is useful for static content with a fingerprinted URL whose content will never change (like heavy images).
 
 Default: NO
 */
@property (assign, nonatomic) BOOL              shouldCheckResourceFreshnessWithServer;

/**
 When shouldCheckResourceFreshnessWithServer is set to YES, the server must always return either a 200 or 304 status with either the latest resource or a confirmation that it is already available before a resource can be retruned. Setting this property to YES laxes the strictness on that condition and will cause a potentially stale cached version of the resource to be returned in favour of returning nil when freshness cannot be guaranteed.

 Default: YES
 */
@property (assign, nonatomic) BOOL              shouldFallbackToPotentiallyStaleCachedResourceInCaseOfError;


/**
 Shared instance as singleton. You can also create your own instances using `init`.
 */
 + (instancetype)sharedLoading;

/**
 Create an instance which has its own state.
 */
- (id)init;

/**
 Load a resource.
 */
- (void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;

/**
 Load a resource. You can call -[cancel] on the canceller to stop the load, this will immediately call the failure block with the `cancelled` flag set to YES. The download for the resource will still continue in the background and subsequent loads will benefit from the cache.
 */
- (void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller;

/**
 Load a resource. Includes a process block which converts the rawData into an object and returns it in the success block.
 */
- (void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;

/**
 Load a resource. Includes both a processor and a canceller.
 */
- (void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller;

/**
 Check whether a resource is loading.
 */
- (BOOL)isLoadingResource:(NSString *)resource;

/**
 Cancels a resource load. The failure block will be called with the `cancelled` flag set to YES.
 */
- (void)cancelLoadForResource:(NSString *)resource;

/**
 Returns YES if the resource is in the cache. In memory cache and on disk cache are not differentiated.
 */
- (BOOL)isResourceInCache:(NSString *)resource;

/**
 Returns the cached data for the resource. Returns nil if the resource is not in the cache.
 */
- (id)cachedObjectForResource:(NSString *)resource;

/**
 Expunges the entire cache. This also deletes disk copies. This clears the cache for all GBLoading instances, since the cache is shared.
 */
- (void)clearCache;

/**
 Expunges a specific resource from the cache. This also deletes disk copies. This operation applies to the cache for all GBLoading instances.
 */
- (void)removeResourceFromCache:(NSString *)resource;

@end

// Roadmap:
//  Allow client to choose whether to choose between storing the processed objects in the cache, vs the raw data. Memory vs CPU tradeoff here.
//  Add support for siloed caches between GBLoading instances.
//  As a sideeffect of the above two: named singletons.

