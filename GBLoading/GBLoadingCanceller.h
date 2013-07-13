//
//  GBLoadingCanceller.h
//  GBLoading
//
//  Created by Luka Mirosevic on 13/07/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GBLoadingCanceller : NSObject

//use this if you need to cancel a very specific load. in contrast if you have multiple loads for a single resource (e.g. same image appears multiple times in a table), then calling -[GBLoading cancelLoadForResource:] will cancel all of them, even though maybe some of the more recent loads, you might still want
-(void)cancel;

@end
