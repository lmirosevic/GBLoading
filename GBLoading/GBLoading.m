//
//  GBLoading.m
//  GBLoading
//
//  Created by Luka Mirosevic on 11/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import "GBLoading.h"

#import <UIKit/UIKit.h>

#import <objc/runtime.h>

static BOOL const kDefaultShouldAlwaysReProcess =           NO;

@interface GBLoadingEgressHandler : NSObject

@property (copy, nonatomic) GBLoadingSuccessBlock           success;
@property (copy, nonatomic) GBLoadingFailureBlock           failure;

@property (assign, nonatomic) GBLoadingState                state;
@property (assign, nonatomic) BOOL                          isCompleted;

+(GBLoadingEgressHandler *)egressHandlerWithSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;
-(id)initWithSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure;

-(void)executeWithOptionalProcessedObject:(id)processedObject;

@end

@implementation GBLoadingEgressHandler

+(GBLoadingEgressHandler *)egressHandlerWithSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    return [[self alloc] initWithSuccess:success failure:failure];
}

-(id)initWithSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    if (self = [super init]) {
        self.success = success;
        self.failure = failure;
        self.state = GBLoadingStateNormal;
        self.isCompleted = NO;
    }
    
    return self;
}

-(void)executeWithOptionalProcessedObject:(id)processedObject {
    self.isCompleted = YES;
    
    switch (self.state) {
        case GBLoadingStateNormal: {
            if (self.success) self.success(processedObject);
        } break;
            
        case GBLoadingStateFailure: {
            if (self.failure) self.failure(NO);
        } break;
            
        case GBLoadingStateCancellation: {
            if (self.failure) self.failure(YES);
        } break;
    }
}

@end

@interface GBLoadingCanceller ()

@property (weak, nonatomic) GBLoadingEgressHandler  *egressHandler;

@end

@implementation GBLoadingCanceller

#pragma mark - API

-(void)cancel {
    if (!self.egressHandler.isCompleted) {
        self.egressHandler.state = GBLoadingStateCancellation;
    }
}

#pragma mark - util

+(GBLoadingCanceller *)_cancellerWithEgressHandler:(GBLoadingEgressHandler *)egressHandler {
    return [[self alloc] _initWithEgressHandler:egressHandler];
}

-(id)_initWithEgressHandler:(GBLoadingEgressHandler *)egressHandler {
    if (self = [super init]) {
        self.egressHandler = egressHandler;
    }
    
    return self;
}

@end

@interface GBLoading ()

@property (strong, nonatomic) NSMutableDictionary       *cache;
@property (strong, nonatomic) NSMutableDictionary       *handlerQueues;
@property (strong, nonatomic) NSOperationQueue          *loadOperationQueue;

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
        self.handlerQueues = [NSMutableDictionary new];
        self.loadOperationQueue = [NSOperationQueue new];
    }
    return self;
}

-(void)dealloc {
    self.cache = nil;
    
    //process all handler queues
    for (NSString *resource in self.handlerQueues) {
        //set all their states to failed
        [self _markAllEgressHandlersForResource:resource asBeingInState:GBLoadingStateFailure];
        
        //execute them all
        [self _processEgressQueueForResource:resource withOptionalProcessedObject:nil];
    }
    //now it's safe to remove them all
    self.handlerQueues = nil;
    
    self.loadOperationQueue = nil;
}

#pragma mark - API

-(void)removeResourceFromCache:(NSString *)resource {
    if (!resource) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a resource" userInfo:nil];
    
    [self _removeResourceFromCache:resource];
}

-(void)clearCache {
    self.cache = [NSMutableDictionary new];
}

-(void)cancelLoadForResource:(NSString *)resource {
    if (!resource) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a resource" userInfo:nil];
    
    [self _cancelLoadForResource:resource];
}

-(BOOL)isLoadingResource:(NSString *)resource {
    if (!resource) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a resource" userInfo:nil];
    
    return [self _isLoadingResource:resource];
}

-(void)loadResource:(NSString *)resource withSuccess:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    [self loadResource:nil withBackgroundProcessor:nil success:success failure:failure];
}

-(void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    [self loadResource:resource withBackgroundProcessor:processor success:success failure:failure canceller:nil];
}

-(void)loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller {
    if (!resource) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a resource" userInfo:nil];
    
    [self _loadResource:resource withBackgroundProcessor:processor success:success failure:failure canceller:canceller];
}

#pragma mark - util

-(void)_removeResourceFromCache:(NSString *)resource {
    [self.cache removeObjectForKey:resource];
}

-(void)_markAllEgressHandlersForResource:(NSString *)resource asBeingInState:(GBLoadingState)state {
    for (GBLoadingEgressHandler *egressHandler in self.handlerQueues[resource]) {
        egressHandler.state = state;
    }
}

-(BOOL)_isLoadingResource:(NSString *)resource {
    //we know it's loading if there is anything in the queue, because once a load finishes we always clear the entire queue
    BOOL areEgressHandlersEnqueued = ([self _egressQueueForResource:resource].count > 0);

    return (areEgressHandlersEnqueued);
}

-(void)_cancelLoadForResource:(NSString *)resource {
    //we just set the cancelled flag on all our enqueued resources, this might mask a failure, however the client probably doesn't care at this point since he clearly no longer wants the object for the resource
    for (GBLoadingEgressHandler *egressHandler in [self _egressQueueForResource:resource]) {
        egressHandler.state = GBLoadingStateCancellation;
    }
}

-(void)_loadResource:(NSString *)resource withBackgroundProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure canceller:(GBLoadingCanceller **)canceller {
    //first check if this resource is already being loaded
    BOOL isLoadingResource = [self _isLoadingResource:resource];
    
    //in any case we need an egress handler
    GBLoadingEgressHandler *egressHandler = [GBLoadingEgressHandler egressHandlerWithSuccess:success failure:failure];
    
    //and we always want to enqueue it (because we always want the client to know what happened)
    [self _enqueueEgressHandler:egressHandler forResource:resource];
    
    //if the caller wants a canceller object, we should give him one
    if (canceller) {
        *canceller = [GBLoadingCanceller _cancellerWithEgressHandler:egressHandler];
    }
    
    //we now optionally kick off a fetchAndProcess
    if (!isLoadingResource) {
        [self _fetchAndProcessResource:resource withProcessor:processor];
    }
    else {
        //in this case we don't have to do anything, because the entire queue will get called once the already running fetch finishes
    }
}

-(void)_fetchAndProcessResource:(NSString *)resource withProcessor:(GBLoadingBackgroundProcessorBlock)processor {
    //we can assume the values coming in are valid, our principle is: we trust our private methods, but we don't trust the public ones

    //check our cache, it might let us avoid a network trip
    id existingObject = self.cache[resource];
    
    [self.loadOperationQueue addOperationWithBlock:^{
        //get the resource, either we have it already from the cache, othwerwise go fetch it
        id originalObject = existingObject ?: [NSData dataWithContentsOfURL:[NSURL URLWithString:resource]];

        id processedObject;
        if (!existingObject &&                  //if it's fresh, and
            (processor && originalObject)) {    //we've got something to process
            //process it
            id temp = processor(originalObject);
    
            //bail if processor returned nil
            if (!temp) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Must return a non nil object from the processor function." userInfo:nil];
            
            processedObject = temp;
        }
        //it it's fresh and there's no processor
        else if (!existingObject && !processor) {
            //just use the orignal one
            processedObject = originalObject;
        }
        //if it's cached
        else {
            //don't process it
            processedObject = originalObject;
        }
        
        //once we're done creating the object, process our egress queue
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            //we might need to cache it if we got a new one
            if (processedObject && !existingObject) {
                self.cache[resource] = processedObject;
            }
            
            //if we didn't get an object from the network, then it's safe to say we failed
            if (!originalObject) {
                [self _markAllEgressHandlersForResource:resource asBeingInState:GBLoadingStateFailure];
            }
            
            //process the queue
            [self _processEgressQueueForResource:resource withOptionalProcessedObject:processedObject];
        }];
    }];
}

-(void)_processEgressQueueForResource:(NSString *)resource withOptionalProcessedObject:(id)processedObject {
    //process everything on the queue
    for (GBLoadingEgressHandler *egressHandler in [self _egressQueueForResource:resource]) {
        [egressHandler executeWithOptionalProcessedObject:processedObject];
    }
    
    //empty the queue
    [self _emptyQueueForResource:resource];
}

-(void)_enqueueEgressHandler:(GBLoadingEgressHandler *)egressHandler forResource:(NSString *)resource {
    [[self _egressQueueForResource:resource] addObject:egressHandler];
}

-(NSMutableArray *)_egressQueueForResource:(NSString *)resource {
    id egressQeueu = self.handlerQueues[resource];
    
    //create it if it doesn't exist
    if (!egressQeueu) {
        egressQeueu = [NSMutableArray new];
        self.handlerQueues[resource] = egressQeueu;
    }
    
    return egressQeueu;
}

-(void)_emptyQueueForResource:(NSString *)resource {
    [self.handlerQueues removeObjectForKey:resource];
}

@end
