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

@interface GBLoading : NSObject

+(GBLoading *)sharedLoading;

-(void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller;
-(BOOL)isLoadingResource:(NSString *)resource;
-(void)cancelLoadForResource:(NSString *)resource;
-(void)clearCache;
-(void)removeResourceFromCache:(NSString *)resource;

@end