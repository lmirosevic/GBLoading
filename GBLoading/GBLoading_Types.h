//
//  GBLoading_Types.h
//  GBLoading
//
//  Created by Luka Mirosevic on 13/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#ifndef GBLoading_GBLoading_Types_h
#define GBLoading_GBLoading_Types_h

typedef enum {
    GBLoadingStateNormal,
    GBLoadingStateFailure,
    GBLoadingStateCancellation,
} GBLoadingState;

typedef void(^GBLoadingSuccessBlock)(id object);
typedef void(^GBLoadingFailureBlock)(BOOL isCancelled);
typedef id(^GBLoadingBackgroundProcessorBlock)(NSData *rawData);

#endif
