//
//  EmulationViewController.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 03/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "EmulationViewController.h"

@interface EmulationViewController ()

@end

@implementation EmulationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    self.view.wantsLayer = YES;
    self.view.layer.magnificationFilter = kCAFilterNearest;
    

        
    
}

- (void)keyUp:(NSEvent *)theEvent {
    if ([self.delegate respondsToSelector:@selector(keyUp:)]) {
        [self.delegate keyUp:theEvent];
    }
}

- (void)keyDown:(NSEvent *)theEvent {
    if ([self.delegate respondsToSelector:@selector(keyDown:)]) {
        [self.delegate keyDown:theEvent];
    }
}

- (void)flagsChanged:(NSEvent *)theEvent {
    if ([self.delegate respondsToSelector:@selector(flagsChanged:)]) {
        [self.delegate flagsChanged:theEvent];
    }
}

@end
