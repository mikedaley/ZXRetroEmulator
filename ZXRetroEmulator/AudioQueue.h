//
//  AudioQueue.h
//  ZXRetroEmulator
//
//  Created by Mike Daley on 15/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioQueue : NSObject

+ (AudioQueue *)queue;
- (void)setup;
- (int)write:(int16_t *)data count:(uint)bytes;
- (int)read:(int16_t *)data count:(uint)bytes;
- (int)used;

@end
