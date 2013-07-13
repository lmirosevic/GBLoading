//
//  GBLoading.h
//  GBLoading
//
//  Created by Luka Mirosevic on 11/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^GBLoadingSuccessBlock)(id object);
typedef void(^GBLoadingFailureBlock)(BOOL isCancelled);
typedef id(^GBLoadingBackgroundProcessorBlock)(id inputObject);

@interface GBLoading : NSObject

#pragma mark - API

+(GBLoading *)sharedLoading;

-(void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(void)loadResource:(NSString *)resource withProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(BOOL)isLoadingResource:(NSString *)resource;
-(void)cancelLoadForResource:(NSString *)resource;
-(void)clearCache;

@end

#import "StandardProcessors.h"