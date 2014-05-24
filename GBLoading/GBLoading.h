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
#import "GBLoadingCachingLayerProtocol.h"
#import "GBPersistentInMemoryCache.h"

@protocol GBLoadingCachingLayer;

@interface GBLoading : NSObject

+(GBLoading *)sharedLoading;

@property (assign, nonatomic) NSInteger         maxConcurrentRequests;                      // default: 6. Set NSOperationQueueDefaultMaxConcurrentOperationCount for automatic.
@property (assign, nonatomic) NSUInteger        maxInMemoryCacheCapacity;                   // default: 10MB. Set kGBStorageMemoryCapUnlimited for no memory cap.
@property (assign, nonatomic) BOOL              shouldPersistToDisk;                        // default: NO
@property (assign, nonatomic) BOOL              shouldCheckResourceFreshnessWithServer;     // default: NO. This use the ETag so make sure your remote resource has one set, otherwise it will redownload the resource every time if this property is set to YES.

-(void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller;
-(void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller;
-(BOOL)isLoadingResource:(NSString *)resource;
-(void)cancelLoadForResource:(NSString *)resource;
-(void)clearCache;
-(void)removeResourceFromCache:(NSString *)resource;

@end

