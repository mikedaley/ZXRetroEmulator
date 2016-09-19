//
//  EmulationViewController.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 03/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "EmulationViewController.h"
#import "AppDelegate.h"
#import "ZXSpectrum48.h"
#import "AudioCore.h"

@interface EmulationViewController ()

@property (weak) AppDelegate *appDelegate;


@end

@implementation EmulationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    self.view.wantsLayer = YES;
    self.view.layer.magnificationFilter = kCAFilterNearest;
    
    _appDelegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
    
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

#pragma Sliders

- (IBAction)highPassFilterChanged:(id)sender
{
    self.appDelegate.machine.audioCore.highPassFilter = [sender floatValue];
    
}

- (IBAction)lowPassFilterChanged:(id)sender
{
    self.appDelegate.machine.audioCore.lowPassFilter = [sender floatValue];
}

@end
