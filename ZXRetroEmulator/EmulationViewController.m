//
//  EmulationViewController.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 03/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "EmulationViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "AppDelegate.h"
#import "ZXSpectrum48.h"
#import "AudioCore.h"

#pragma mark - Private Interface

@interface EmulationViewController ()

@property (strong) AppDelegate *appDelegate;

@property (assign) float wScale;
@property (assign) float hScale;

@end

#pragma mark - Implementation 

@implementation EmulationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.wantsLayer = YES;
    self.view.layer.magnificationFilter = kCAFilterNearest;
    _wScale = 1.0 / 352.0;
    _hScale = 1.0 / 312.0;

    [self showBorder];
    
    _appDelegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
}

- (void)keyUp:(NSEvent *)theEvent
{
    if ([self.delegate respondsToSelector:@selector(keyUp:)])
    {
        [self.delegate keyUp:theEvent];
    }
}

- (void)keyDown:(NSEvent *)theEvent
{
    if ([self.delegate respondsToSelector:@selector(keyDown:)])
    {
        [self.delegate keyDown:theEvent];
    }
}

- (void)flagsChanged:(NSEvent *)theEvent
{
    if ([self.delegate respondsToSelector:@selector(flagsChanged:)])
    {
        [self.delegate flagsChanged:theEvent];
    }
}

# pragma mark - Border Animation

- (void)hideBorder
{
    CABasicAnimation *contentsRectAnim = [CABasicAnimation animationWithKeyPath:@"contentsRect"];
    contentsRectAnim.fromValue = [NSValue valueWithRect:self.view.layer.contentsRect];
    contentsRectAnim.toValue = [NSValue valueWithRect:CGRectMake(32 * self.wScale,
                                                                 56 * self.hScale,
                                                                 1.0 - ((64 * self.wScale) + (32 * self.wScale)),
                                                                 1.0 - ((56 * self.hScale) + (56 * self.hScale))
                                                                 )
                                ];
    contentsRectAnim.duration = 0.2;
    [self.view.layer addAnimation:contentsRectAnim forKey:@"contentsRect"];
    
    self.view.layer.contentsRect = CGRectMake(32 * self.wScale,
                                              56 * self.hScale,
                                              1.0 - ((64 * self.wScale) + (32 * self.wScale)),
                                              1.0 - ((56 * self.hScale) + (56 * self.hScale))
                                              );

}

- (void)showBorder
{
    CABasicAnimation *contentsRectAnim = [CABasicAnimation animationWithKeyPath:@"contentsRect"];
    contentsRectAnim.fromValue = [NSValue valueWithRect:self.view.layer.contentsRect];
    contentsRectAnim.toValue = [NSValue valueWithRect:CGRectMake(0,
                                                                 24 * self.hScale,
                                                                 1.0 - (20 * self.wScale),
                                                                 1.0 - ((24 * self.hScale) * 2))];
    contentsRectAnim.duration = 0.2;
    [self.view.layer addAnimation:contentsRectAnim forKey:@"contentsRect"];
    self.view.layer.contentsRect = CGRectMake(0,
                                              24 * self.hScale,
                                              1.0 - (20 * self.wScale),
                                              1.0 - ((24 * self.hScale) * 2));

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
