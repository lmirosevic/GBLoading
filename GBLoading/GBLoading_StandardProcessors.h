//
//  GBLoading_StandardProcessors.h
//  GBLoading
//
//  Created by Luka Mirosevic on 11/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import "GBLoading_Types.h"

#import <UIKit/UIKit.h>

static GBLoadingBackgroundProcessorBlock const kGBLoadingProcessorDataToImage = ^id(NSData *rawData) {
    return [UIImage imageWithData:rawData];
};

static GBLoadingBackgroundProcessorBlock const kGBLoadingProcessorJSONDeserializer = ^id(NSData *rawData) {
    if (rawData) {
        NSError *error;
        id parsedJSON = [NSJSONSerialization JSONObjectWithData:rawData options:0 error:&error];
        if (!error) {
            return parsedJSON;
        }
        else {
            return nil;
        }
    }
    else {
        return nil;
    }
};
