//
//  AppDelegate.h
//  ZXRetroEmulator
//
//  Created by Mike Daley on 03/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ZXSpectrum48;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) ZXSpectrum48 *machine;

@end

