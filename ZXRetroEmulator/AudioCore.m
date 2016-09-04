//
//  AudioCore.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 03/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "AudioCore.h"
#import <AVFoundation/AVFoundation.h>

#pragma mark - Private interface

@interface AudioCore ()

// AVAudioEngine ivars
@property (strong) AVAudioEngine *audioEngine;
@property (strong) AVAudioPlayerNode *playerNode;
@property (strong) AVAudioMixerNode *mixerNode;
@property (strong) NSMutableArray *buffers;

// Total number of buffers to be created
@property (assign) NSInteger totalBuffers;

// Current buffer being written too and the position within the buffer
@property (assign) NSInteger currentBuffer;
@property (assign) NSInteger currentBufferPosition;

@property (assign) NSInteger lastScheduledBuffer;

// Number of sample frames within a buffer
@property (assign) unsigned int frameCapcity;

@end

#pragma mark - Implementation

@implementation AudioCore

- (instancetype)initWithSampleRate:(int)sampleRate framesPerSecond:(int)fps
{
    self = [super init];
    if (self) {
        
//        _frameCapcity = (sampleRate / fps);
        _frameCapcity = 350;
        
        _audioEngine = [AVAudioEngine new];
        _playerNode = [AVAudioPlayerNode new];
        _mixerNode = [_audioEngine mainMixerNode];
        [_mixerNode setOutputVolume:0.5];
        
        // Playing with improving the sound output using filters :)
        AVAudioUnitEQ *eqnode = [[AVAudioUnitEQ alloc] initWithNumberOfBands:2];
        eqnode.globalGain = 1;
        [_audioEngine attachNode:eqnode];
        AVAudioUnitEQFilterParameters *params = eqnode.bands[0];
        params.filterType = AVAudioUnitEQFilterTypeBandPass;
        params.bandwidth = 0.5;
        params.frequency = 1000.0;
        params.gain = 15;
        
        AVAudioFormat *audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:sampleRate channels:1 interleaved:NO];
        
        _totalBuffers = 16;
        
        _buffers = [NSMutableArray new];
        for (int i = 0; i < _totalBuffers; i++) {
            AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:self.frameCapcity];
            buffer.frameLength = self.frameCapcity;
            [_buffers addObject:buffer];
        }
        
        [_audioEngine attachNode:_playerNode];
        [_audioEngine connect:_playerNode to:_mixerNode format:audioFormat];
        [_audioEngine connect:eqnode to:_mixerNode format:audioFormat];
        
        [_audioEngine startAndReturnError:nil];
        [_playerNode play];
        
        _currentBuffer = 0;
        _currentBufferPosition = 0;
    }
    return self;
}

- (void)updateBeeperAudioWithValue:(float)value
{
    AVAudioPCMBuffer *buffer = [self.buffers objectAtIndex:self.currentBuffer];
    float * const data = buffer.floatChannelData[0];
    data[_currentBufferPosition++] = value * 0.001f;
    
    if (self.currentBufferPosition > self.frameCapcity) {
        [self.playerNode scheduleBuffer:buffer completionHandler:nil];
        self.currentBufferPosition = 0;
        self.currentBuffer = (self.currentBuffer + 1) % self.totalBuffers;
    }
}

@end
