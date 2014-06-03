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

+(instancetype)sharedLoading;

@property (assign, nonatomic) NSInteger         maxConcurrentRequests;                      // default: 6. Set NSOperationQueueDefaultMaxConcurrentOperationCount for automatic.
@property (assign, nonatomic) NSUInteger        maxInMemoryCacheCapacity;                   // default: kGBStorageMemoryCapUnlimited
@property (assign, nonatomic) BOOL              shouldPersistToDisk;                        // default: NO
@property (assign, nonatomic) BOOL              shouldCheckResourceFreshnessWithServer;     // default: NO. When set to YES, the library will ping the server to make sure the resource is fresh and if so use the one from the local cache with no data transferred from the server other than a freshness acknwledgement (this works using the ETag so make sure your remote resources have them set, otherwise it will end up redownloading the resource every time, even if it's already in the cache). When set to NO, the library will consult the local cache for the resource first, and if it finds it will immediately return it with no server hop, otherwise it will go fetch the resources, this mode is useful for static content with a fingerprinted URL whose content will never change (like heavy images).

-(id)init;

-(void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller;
-(void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller;
-(BOOL)isLoadingResource:(NSString *)resource;
-(void)cancelLoadForResource:(NSString *)resource;
-(void)clearCache;
-(void)removeResourceFromCache:(NSString *)resource;

@end

