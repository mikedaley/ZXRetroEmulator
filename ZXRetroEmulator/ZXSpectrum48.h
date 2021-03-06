//
//  ZXSpectrum48.h
//  ZXRetroEmu
//
//  Created by Mike Daley on 02/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewEventProtocol.h"

@interface ZXSpectrum48 : NSObject <ViewEventProtocol>

#pragma mark - Properties

#pragma mark - Methods

- (instancetype)initWithEmulationScreenView:(NSView *)view;
- (void)startExecution;
- (void)stopExecution;
- (void)loadSnapshotWithPath:(NSString *)path;
- (void)reset;

@end
