//
//  MyScene.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 07/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "MyScene.h"
#import <SpriteKit/SpriteKit.h>
#import <GLKit/GLKit.h>

@implementation MyScene

- (void)didMoveToView:(SKView *)view {
    
    self.sprite = [SKSpriteNode spriteNodeWithTexture:NULL size:CGSizeMake(352, 304)];
    self.sprite.position = CGPointMake(352/2, 304/2);
    self.sprite.color = [NSColor redColor];
    [self addChild:self.sprite];
    
}

@end
