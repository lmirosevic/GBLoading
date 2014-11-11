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
 +(instancetype)sharedLoading;

/**
 Create an instance which has its own state.
 */
- (id)init;

/**
 Load a resource.
 */
- (void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;

/**
 Load a resource.
 */
- (void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller;

/**
 Load a resource.
 */
- (void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;

/**
 Load a resource.
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
 Expunges the entire cache. This also deletes disk copies.
 */
- (void)clearCache;

/**
 Expunges a specific resource from the cache. This also deletes disk copies.
 */
- (void)removeResourceFromCache:(NSString *)resource;

@end

