//
//  GBPersistentInMemoryCache.h
//  GBLoading
//
//  Created by Luka Mirosevic on 24/05/2014.
//  Copyright (c) 2014 Goonbee. All rights reserved.
//

#import "GBLoadingCachingLayerProtocol.h"

@interface GBPersistentInMemoryCache : NSObject <GBLoadingCachingLayer>

@property (assign, nonatomic) NSUInteger        maxInMemoryCacheCapacity;
@property (assign, nonatomic) BOOL              shouldPersistToDisk;

@end
