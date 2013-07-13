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
//static NSUInteger const kMaxConcurrentOperationsCount =     6;

typedef enum {
    GBLoadingStateWorking,
    GBLoadingStateFailed,
    GBLoadingStateCancelled,
} GBLoadingState;

@interface GBLoadingEgressHandler : NSObject

@property (copy, nonatomic) GBLoadingSuccessBlock           success;
@property (copy, nonatomic) GBLoadingFailureBlock           failure;

@property (assign, nonatomic) GBLoadingState                state;

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
        self.state = GBLoadingStateWorking;
    }
    
    return self;
}

-(void)executeWithOptionalProcessedObject:(id)processedObject {
    switch (self.state) {
        case GBLoadingStateWorking: {
            if (self.success) self.success(processedObject);
        } break;
            
        case GBLoadingStateFailed: {
            if (self.failure) self.failure(NO);
        } break;
            
        case GBLoadingStateCancelled: {
            if (self.failure) self.failure(YES);
        } break;
    }
}

@end

@interface GBLoading ()

@property (strong, nonatomic) NSMutableDictionary       *cache;
@property (strong, nonatomic) NSMutableDictionary       *handlerQueues;
@property (strong, nonatomic) NSOperationQueue          *loadOperationQueue;//foo might be faster to use GCD

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
//        self.loadOperationQeueue.maxConcurrentOperationCount = kMaxConcurrentOperationsCount;//foo see what's faster on the device
    }
    return self;
}

-(void)dealloc {
    self.cache = nil;
    
    //process all handler queues
    for (NSString *resource in self.handlerQueues) {
        //set all their states to failed
        [self _markAllEgressHandlersForResource:resource asBeingInState:GBLoadingStateFailed];
        
        //execute them all
        [self _processEgressQueueForResource:resource withOptionalProcessedObject:nil];
    }
    //now it's safe to remove them all
    self.handlerQueues = nil;
    
    self.loadOperationQueue = nil;
}

#pragma mark - API

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
    [self loadResource:nil withProcessor:nil success:success failure:failure];
}

-(void)loadResource:(NSString *)resource withProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    if (!resource) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a resource" userInfo:nil];
    
    [self _loadResource:resource withProcessor:processor success:success failure:failure];
}

#pragma mark - util

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
        egressHandler.state = GBLoadingStateCancelled;
    }
}

-(void)_loadResource:(NSString *)resource withProcessor:(GBLoadingBackgroundProcessorBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
    //in any case we need an egress handler
    GBLoadingEgressHandler *egressHandler = [GBLoadingEgressHandler egressHandlerWithSuccess:success failure:failure];
    
    //and we always want to enqueue it (because we always want the client to know what happened)
    [self _enqueueEgressHandler:egressHandler forResource:resource];
    
    //we now optionally kick off a fetchAndProcess
    if (![self _isLoadingResource:resource]) {
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
        //if it's fresh
        if (!existingObject && processor) {
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
                [self _markAllEgressHandlersForResource:resource asBeingInState:GBLoadingStateFailed];
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
    self.handlerQueues[resource] = nil;
}

//-(void)cancelLoadWithUniqueIdentifier:(id)loadIdentifier {
//    if (!loadIdentifier) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a loadIdentifier" userInfo:nil];
//    
//    [self _destroyLoadForUniqueIdentifier:loadIdentifier];
//}
//
//-(BOOL)isLoadingForUniqueIdentifier:(id)loadIdentifier {
//    return ([loadIdentifier associatedOperation] != nil);
//}
//
//-(void)loadResource:(NSString *)urlString withUniqueIdentifier:(id)loadIdentifier success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
//    [self loadResource:urlString withUniqueIdentifier:loadIdentifier backgroundProcessor:nil success:success failure:failure];
//}
//
//-(void)loadResource:(NSString *)urlString withUniqueIdentifier:(id)loadIdentifier backgroundProcessor:(GBLoadingBackgroundProcessBlock)processor success:(GBLoadingSuccessBlock)success failure:(GBLoadingFailureBlock)failure {
//    if (!loadIdentifier) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a loadIdentifier" userInfo:nil];
//    if (!urlString) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Must provide a urlString" userInfo:nil];
//    
//    //if one such operation is already on the queue, then we failed
//    if ([self isLoadingForUniqueIdentifier:loadIdentifier]) {
//        if (failure) failure();
//    }
//    //otherwise we can enqueue it
//    else {
//        //check our cache, it might let us avoid a network trip
//        id existingObject = self.cache[urlString];
//        
//        //create the operation
//        NSBlockOperation *loadOperation = [NSBlockOperation new];
//        
//        [loadOperation addExecutionBlock:^{
//            //get the resource, either we have it already from the cache, or go fetch it
//            id originalObject = existingObject ?: [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
//            
//            id processedObject;
//            //fresh object: always process
//            if (!existingObject) {
//                processedObject = processor ? processor(originalObject) : originalObject;
//            }
//            //existing object, always process turned on: process
//            else if (self.shouldAlwaysReProcess) {
//                processedObject = processor ? processor(originalObject) : originalObject;
//            }
//            //existing object, always process turned off: don't process
//            else {
//                processedObject = originalObject;
//            }
//            
//            //call back on main thread when we're done
//            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//                //cancelled
//                if (![self isLoadingForUniqueIdentifier:loadIdentifier]) {
//                    //noop
//                }
//                //all good
//                else if (processedObject) {
//                    //caching: in case of fresh object
//                    if (!existingObject) {
//                        //if we should always reprocess...
//                        if (self.shouldAlwaysReProcess) {
//                            //...store the original object
//                            self.cache[urlString] = originalObject;
//                        }
//                        //if not...
//                        else {
//                            //...then just cache the already processed ones
//                            self.cache[urlString] = processedObject;
//                        }
//                    }
//                    
//                    //get rid of it
//                    [self _destroyLoadForUniqueIdentifier:loadIdentifier];
//                    
//                    //call the success handler on our processed object
//                    if (success) success(processedObject);
//                }
//                //some other error condition
//                else {
//                    [self _destroyLoadForUniqueIdentifier:loadIdentifier];
//                }
//            }];
//        }];
//        
//        //remember the operation
//        [loadIdentifier setAssociatedOperation:loadIdentifier];
//        
//        //load the resource
//        [self.operationQueue addOperation:loadOperation];
//    }
//}
//
//#pragma mark - util
//
//-(void)_destroyLoadForUniqueIdentifier:(id)loadIdentifier {
//    NSOperation *operation = [loadIdentifier associatedOperation];
//    if (operation) {
//        [loadIdentifier setAssociatedOperation:nil];
//    }
//}

@end



















//object:
//resource => meta
//meta : {
//success block
//fail block
//state
//}

//each resource has its string of success and fail blocks
//when a


//a load request comes in, if its totally fresh

//load some resource, when it's finished, cache it and call the handler with a certain state: (success/fail/cancelled)



//if it succeeds, call my callback
//if it fails, call my failure
//if a new request comes in for the same resource, append the succeed and failure blocks
//i should be able to cancel the callback for a particular


//creating a new load:
    //adds the meta object to the handlerqueue
    //calls the async load function which does the load and the processing, and when done, calls the queue worked on the main thread

//we have a handler queue processor method which pulls of work of the handler queue and goes through it

//calling cancel just sets the state to cancelled on all meta objects

//when a meta object is finally executed (and they're always executed), it should do a couple things based on it's state


//gonna need:
//meta object
//queue for each resource
//loader function
//queue processor function
//cancel function









