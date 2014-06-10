//
//  GBLoadingCachingLayer.h
//  GBLoading
//
//  Created by Luka Mirosevic on 24/05/2014.
//  Copyright (c) 2014 Goonbee. All rights reserved.
//

@protocol GBLoadingCachingLayer <NSObject>
@required

-(void)cacheResource:(NSData *)resource withMeta:(id<NSCoding>)meta size:(NSUInteger)size forKey:(NSString *)resourceKey;
-(void)removeResourceForKey:(NSString *)resourceKey;
-(void)clear;
-(NSData *)getResourceDataForKey:(NSString *)resourceKey;
-(id)getResourceMetaForKey:(NSString *)resourceKey;

@end
