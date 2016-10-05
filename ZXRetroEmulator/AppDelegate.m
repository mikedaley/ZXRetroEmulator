//
//  AppDelegate.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 03/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "AppDelegate.h"
#import <Quartz/Quartz.h>

#import "EmulationViewController.h"
#import "ZXSpectrum48.h"

#pragma mark = Private Interface

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet EmulationViewController *emulationViewController;

@property (strong) NSLayoutConstraint *windowWidthConstraint;
@property (strong) NSLayoutConstraint *windowHeightConstraint;

@property (assign) NSInteger viewWidth;
@property (assign) NSInteger viewHeight;
@property (assign) NSInteger viewScale;

@property (assign) BOOL borderVisible;

@end

#pragma mark - Implementation 

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    _borderVisible = YES;
    _viewScale = 2.0;
    _viewWidth = 32 + 256 + 44;
    _viewHeight = 32 + 192 + 32 ;
    
    [self setupViews];
    
    _machine = [[ZXSpectrum48 alloc] initWithEmulationScreenView:_emulationViewController.view];
    _emulationViewController.delegate = _machine;
    [_machine start];
    
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"shock" ofType:@"sna"];
//    [_machine loadSnapshotWithPath:path];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

#pragma mark - View setup

- (void)setupViews
{
    _window.contentView.wantsLayer = YES;
    [_window.contentView addSubview:_emulationViewController.view];

    _emulationViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSDictionary *views = @{ @"emulationDisplayView" : _emulationViewController.view };
    
    _windowWidthConstraint = [NSLayoutConstraint constraintWithItem:_emulationViewController.view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeWidth multiplier:1.0 constant:_viewWidth * _viewScale];
    _windowHeightConstraint = [NSLayoutConstraint constraintWithItem:_emulationViewController.view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeHeight multiplier:1.0 constant:_viewHeight * _viewScale];
    
    [_window.contentView addConstraint:_windowWidthConstraint];
    [_window.contentView addConstraint:_windowHeightConstraint];
    
    NSArray *vertEmulationConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[emulationDisplayView]|" options:0 metrics:nil views:views];
    NSArray *horizEmulationConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[emulationDisplayView]|" options:0 metrics:nil views:views];
    
    [_window.contentView addConstraints:vertEmulationConstraint];
    [_window.contentView addConstraints:horizEmulationConstraint];
    
    [_window makeFirstResponder:_emulationViewController.view];
}

#pragma mark - Menu actions

- (IBAction)animateWindowSize:(id)sender
{
    NSMenuItem *menuItem = sender;
    if (menuItem)
    {
        self.viewScale = (float)menuItem.tag;
    }
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context)
    {
        context.duration = 0.25;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        self.windowWidthConstraint.animator.constant = _viewWidth * self.viewScale / 2.0;
        self.windowHeightConstraint.animator.constant = _viewHeight * self.viewScale / 2.0;
        
    } completionHandler:nil];
}

- (IBAction)machineReset:(id)sender
{
    [self.machine reset];
}

- (IBAction)openDocument:(id)sender
{
    _machine.paused = YES;
    NSOpenPanel *openPanel = [NSOpenPanel new];
    openPanel.canChooseDirectories = NO;
    openPanel.allowsMultipleSelection = NO;
    openPanel.allowedFileTypes = @[@"sna"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
            self.machine.paused = NO;
            if (result == NSModalResponseOK)
            {
                [self.machine loadSnapshotWithPath:openPanel.URLs[0].path];
            }
        }];
    });
    
}

- (IBAction)toggleFilter:(id)sender
{
    if (_emulationViewController.view.layer.magnificationFilter == kCAFilterNearest)
    {
        _emulationViewController.view.layer.magnificationFilter = kCAFilterLinear;
    }
    else
    {
        _emulationViewController.view.layer.magnificationFilter = kCAFilterNearest;
    }
}

- (IBAction)toggleBorder:(id)sender
{
    if (self.borderVisible)
    {
        _viewWidth = 320;
        _viewHeight = 256;
        [self animateWindowSize:nil];
        [self.emulationViewController hideBorder];
        self.borderVisible = NO;
    }
    else
    {
        _viewWidth = 32 + 256 + 32;
        _viewHeight = 32 + 192 + 32 ;
        [self animateWindowSize:nil];
        [self.emulationViewController showBorder];
        self.borderVisible = YES;
    }
}

@end
