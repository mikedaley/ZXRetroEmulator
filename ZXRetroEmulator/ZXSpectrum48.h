//
//  ZXSpectrum48.h
//  ZXRetroEmu
//
//  Created by Mike Daley on 02/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewEventProtocol.h"

@class AudioCore;

@interface ZXSpectrum48 : NSObject <ViewEventProtocol>

#pragma mark - Properties

// Buffer used to hold the sound samples generated for each emulation frame
@property (assign) int16_t *audioBuffer;
@property (strong) AudioCore *audioCore;
@property (strong) dispatch_queue_t emulationQueue;

@property (assign) BOOL paused;

#pragma mark - Methods

- (instancetype)initWithEmulationScreenView:(NSView *)view;
- (void)start;
- (void)pause;
- (void)reset;
- (void)loadSnapshotWithPath:(NSString *)path;
- (void)doFrame;

@end
