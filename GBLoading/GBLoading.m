//
//  GBLoading.m
//  GBLoading
//
//  Created by Luka Mirosevic on 11/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import "GBLoading.h"

#import <UIKit/UIKit.h>

static BOOL const kDefaultShouldAlwaysReProcess =       NO;

@interface GBLoading ()

@property (strong, nonatomic) NSMutableDictionary       *cache;
@property (strong, nonatomic) NSMutableDictionary       *inFlightLoads;
@property (strong, nonatomic) NSOperationQueue          *operationQueue;
@property (assign, atomic) BOOL                         shouldAlwaysReProcess;//in case of a cache hit, should the processor function be called again on the original data returned from the network or can we cache the processed result?. IMPORTANT: call this once before making any loads, changing this after having loaded resources results in undefined behaviour; create other instances of GBLoading if you need to mix and match.

@end

@implementation GBLoading

#pragma mark - memory

+(GBLoading *)sharedLoading {
    static GBLoading *_sharedLoading;
    @synchronized(self) {
        if (!_sharedLoading) {
            _sharedLoading = [self new];
        }
    }
    
    return _sharedLoading;
}

-(id)init {
    if (self = [super init]) {
        self.cache = [NSMutableDictionary new];
        self.inFlightLoads = [NSMutableDictionary new];
        self.operationQueue = [NSOperationQueue new];
        self.shouldAlwaysReProcess = kDefaultShouldAlwaysReProcess;
    }
    return self;
}

-(void)dealloc {
    [self.operationQueue cancelAllOperations];
    self.cache = nil;
    self.inFlightLoads = nil;
}

#pragma mark - API

-(void)cancelLoadWithUniqueIdentifier:(id)loadIdentifier {
    if (!loadIdentifier) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a loadIdentifier" userInfo:nil];
    
    [self _cancelLoadWithUniqueIdentifier:loadIdentifier];
}

-(void)clearCache {
    self.cache = [NSMutableDictionary new];
}

-(BOOL)isLoadingForUniqueIdentifier:(id)uniqueIdentifier {
    return (self.inFlightLoads[uniqueIdentifier] != nil);
}

-(void)loadResource:(NSString *)urlString withUniqueIdentifier:(id)loadIdentifier success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    [self loadResource:urlString withUniqueIdentifier:loadIdentifier backgroundProcessor:nil success:success failure:failure];
}

-(void)loadResource:(NSString *)urlString withUniqueIdentifier:(id)loadIdentifier backgroundProcessor:(GBLoadingBackgroundProcessBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    if (!loadIdentifier) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a loadIdentifier" userInfo:nil];
    if (!urlString) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a urlString" userInfo:nil];
    
    //if one such operation is already on the queue, then we failed
    if ([self isLoadingForUniqueIdentifier:loadIdentifier]) {
        if (failure) failure();
        return;
    }
    //otherwise we can enqueue it
    else {
        //check our cache, it might let us avoid a network trip
        id existingObject = self.cache[urlString];
        
        //create the operation
        NSBlockOperation *loadOperation = [NSBlockOperation new];
        
        //remember this operation, it's now retained strongly until it is removed from this dict
        self.inFlightLoads[loadIdentifier] = loadOperation;
        
        //this is the one we use inside it to avoid a retain cycle
        __weak NSBlockOperation *weakLoadOperation = loadOperation;
        [loadOperation addExecutionBlock:^{
            //get the resource, either we have it already from the cache, or go fetch it
            id originalObject = existingObject ?: [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
            
            id processedObject;
            //fresh object: always process
            if (!existingObject) {
                processedObject = processor ? processor(originalObject) : originalObject;
            }
            //existing object, always process turned on: process
            else if (self.shouldAlwaysReProcess) {
                processedObject = processor ? processor(originalObject) : originalObject;
            }
            //existing object, always process turned off: don't process
            else {
                processedObject = originalObject;
            }
            
            //call back on main thread when we're done
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                //cancelled
                if (weakLoadOperation.isCancelled) {
                    if (failure) failure();
                }
                //all good
                else if (processedObject) {
                    //cachine: in case of fresh object
                    if (!existingObject) {
                        //if we should always reprocess...
                        if (self.shouldAlwaysReProcess) {
                            //...store the original object
                            self.cache[urlString] = originalObject;
                        }
                        //if not...
                        else {
                            //then just cache the already processed ones
                            self.cache[urlString] = processedObject;
                        }
                    }
                    
                    //call the success handler on our processed object
                    if (success) success(processedObject);
                }
                //some other error condition
                else {
                    //notify of failure
                    if (failure) failure();
                }
                
                //remove the operation from the queue
                [self.inFlightLoads removeObjectForKey:loadIdentifier];
            }];
        }];
        
        //load the resource
        [self.operationQueue addOperation:loadOperation];
    }
}

#pragma mark - util

-(void)_cancelLoadWithUniqueIdentifier:(id)uniqueIdentifier {
    NSOperation *operation = self.inFlightLoads[uniqueIdentifier];
    if (operation) {
        [operation cancel];
        [self.inFlightLoads removeObjectForKey:operation];
    }
}

@end
