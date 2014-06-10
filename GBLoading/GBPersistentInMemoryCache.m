//
//  GBPersistentInMemoryCache.m
//  GBLoading
//
//  Created by Luka Mirosevic on 24/05/2014.
//  Copyright (c) 2014 Goonbee. All rights reserved.
//

#import "GBPersistentInMemoryCache.h"

#import <GBStorage/GBStorage.h>

static NSString * const kStorageNamespaceData =             @"GBLoading.DiskCache.Data";
static NSString * const kStorageNamespaceMeta =             @"GBLoading.DiskCache.Meta";

@implementation GBPersistentInMemoryCache

#pragma mark - CA

-(void)setMaxInMemoryCacheCapacity:(NSUInteger)maxInMemoryCacheCapacity {
    GBStorage(kStorageNamespaceData).maxInMemoryCacheCapacity = maxInMemoryCacheCapacity;
}

-(NSUInteger)maxInMemoryCacheCapacity {
    return GBStorage(kStorageNamespaceData).maxInMemoryCacheCapacity;
}

#pragma mark - GBLoadingCachingLayer

-(void)cacheResource:(NSData *)resource withMeta:(id<NSCoding>)meta size:(NSUInteger)size forKey:(NSString *)resourceKey {
    [GBStorage(kStorageNamespaceData) setObject:resource forKey:resourceKey withSize:resource.length persistImmediately:self.shouldPersistToDisk];
    if (meta) [GBStorage(kStorageNamespaceMeta) setObject:meta forKey:resourceKey withSize:0 persistImmediately:self.shouldPersistToDisk];
}

-(void)removeResourceForKey:(NSString *)resourceKey {
    [GBStorage(kStorageNamespaceData) removePermanently:resourceKey];
    [GBStorage(kStorageNamespaceMeta) removePermanently:resourceKey];
}

-(void)clear {
    [GBStorage(kStorageNamespaceData) removeAllPermanently];
    [GBStorage(kStorageNamespaceMeta) removeAllPermanently];
}

-(NSData *)getResourceDataForKey:(NSString *)resourceKey {
    return GBStorage(kStorageNamespaceData)[resourceKey];
}

-(id)getResourceMetaForKey:(NSString *)resourceKey {
    return GBStorage(kStorageNamespaceMeta)[resourceKey];
}

@end
