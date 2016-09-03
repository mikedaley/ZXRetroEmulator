//
//  EmuApplication.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 03/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "EmuApplication.h"

@implementation EmuApplication

- (void)sendEvent:(NSEvent *)theEvent {
    
    if (theEvent.type == NSKeyUp && theEvent.modifierFlags & NSCommandKeyMask) {
        [_keyWindow sendEvent:theEvent];
    } else {
        [super sendEvent:theEvent];
    }
}

@end
