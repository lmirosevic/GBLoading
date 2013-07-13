//
//  GBLoading_StandardProcessors.h
//  GBLoading
//
//  Created by Luka Mirosevic on 11/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//


#ifndef GBLoading_Standard_Processors_h
#define GBLoading_Standard_Processors_h

#import "GBLoading_Types.h"

#import <UIKit/UIKit.h>

static GBLoadingBackgroundProcessorBlock const KGBLoadingProcessorDataToImage = ^id(NSData *rawData) {
    return [UIImage imageWithData:rawData];
};

#endif