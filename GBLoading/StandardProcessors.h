//
//  StandardProcessors.h
//  GBLoading
//
//  Created by Luka Mirosevic on 11/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//


#ifndef Standard_Processors_h
#define Standard_Processors_h

#import "GBLoading.h"
#import <UIKit/UIKit.h>

static GBLoadingBackgroundProcessBlock const KGBLoadingProcessorDataToImage = ^id(id inputObject) {
    return [UIImage imageWithData:inputObject];
};

#endif