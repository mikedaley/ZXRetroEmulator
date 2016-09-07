//
//  SpriteKitViewController.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 07/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "SpriteKitViewController.h"
#import "MyScene.h"

@interface SpriteKitViewController ()

@end

@implementation SpriteKitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    self.view.wantsLayer = YES;
    
    SKView *spriteKitView = (SKView *)self.view;
    spriteKitView.showsDrawCount = YES;
    spriteKitView.showsFPS = YES;
    spriteKitView.showsNodeCount = YES;
    
}

- (void)viewWillAppear {
    
    self.scene = [[MyScene alloc] initWithSize:CGSizeMake(352, 304)];
    SKView *spriteView = (SKView *)self.view;
    [spriteView presentScene:self.scene];
    
}

@end
