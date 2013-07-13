//
//  GBLoading.h
//  GBLoading
//
//  Created by Luka Mirosevic on 11/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^GBLoadingSuccessBlock)(id object);
typedef void(^GBLoadingFailureBlock)();
typedef id(^GBLoadingBackgroundProcessBlock)(id inputObject);

@interface GBLoading : NSObject

#pragma mark - API

+(GBLoading *)sharedLoading;

-(void)cancelLoadWithUniqueIdentifier:(id)loadIdentifier;
-(void)clearCache;
-(void)loadResource:(NSString *)urlString withUniqueIdentifier:(id)loadIdentifier success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(void)loadResource:(NSString *)urlString withUniqueIdentifier:(id)loadIdentifier backgroundProcessor:(GBLoadingBackgroundProcessBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(BOOL)isLoadingForUniqueIdentifier:(id)uniqueIdentifier;

@end

#import "StandardProcessors.h"