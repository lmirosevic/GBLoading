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

-(void)cancelLoad:(NSString *)urlString;
-(void)clearCache;
-(void)load:(NSString *)urlString withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(void)load:(NSString *)urlString withBackgroundProcessor:(GBLoadingBackgroundProcessBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;

@end

#import "StandardProcessors.h"