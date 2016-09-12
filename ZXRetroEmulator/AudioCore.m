//
//  AudioCore.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 03/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "AudioCore.h"
#import <AVFoundation/AVFoundation.h>
#import "ZXSpectrum48.h"

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

// Number of sample frames within a buffer
@property (assign) unsigned int frameCapcity;

@property (assign)dispatch_queue_t emulationQueue;
@property (weak) ZXSpectrum48 *machine;

@property AUGraph graph;
@property AUNode outNode;
@property AUNode converterNode;
@property AUNode lowPassNode;
@property AUNode highPassNode;

@end

#define kSAMPLE_RATE 192000
#define kCHUNK 3840

// Audio render callback
static OSStatus render(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlags,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData);


#pragma mark - Implementation

@implementation AudioCore

- (instancetype)initWithSampleRate:(int)sampleRate framesPerSecond:(float)fps emulationQueue:queue machine:(ZXSpectrum48 *)machine
{
    self = [super init];
    if (self) {
        
        _machine = machine;
        _emulationQueue = queue;
//        _frameCapcity = (sampleRate / fps);
//        
//        _frameCapcity = 3840;
//        
//        _audioEngine = [AVAudioEngine new];
//        _playerNode = [AVAudioPlayerNode new];
//        
//        _mixerNode = [_audioEngine mainMixerNode];
//        [_mixerNode setOutputVolume:0.5];
        
        // Playing with improving the sound output using filters :)
//        AVAudioUnitEQ *eqnode = [[AVAudioUnitEQ alloc] initWithNumberOfBands:2];
//        eqnode.globalGain = 1;
//        [_audioEngine attachNode:eqnode];
//        AVAudioUnitEQFilterParameters *params = eqnode.bands[0];
//        params.filterType = AVAudioUnitEQFilterTypeLowPass;
//        params.bandwidth = 1;
//        params.frequency = 1021;
//        params.gain = 15;
        
//        AVAudioFormat *audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
//                                                                      sampleRate:sampleRate
//                                                                        channels:1
//                                                                     interleaved:NO];
//        _totalBuffers = 1;
//        
//        _buffers = [NSMutableArray new];
//        for (int i = 0; i < _totalBuffers; i++) {
//            AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:self.frameCapcity];
//            buffer.frameLength = 882;
//            [_buffers addObject:buffer];
//        }
//        
//        [_audioEngine attachNode:_playerNode];
//        [_audioEngine connect:_playerNode to:_mixerNode format:audioFormat];
////        [_audioEngine connect:eqnode to:_mixerNode format:audioFormat];
//        
//        [_audioEngine startAndReturnError:nil];
//        [_playerNode play];
//        
//        _currentBuffer = 0;
//        _currentBufferPosition = 0;
        
        NewAUGraph(&_graph);
        
        // Output Node
        AudioComponentDescription audioUnitDesc;
        audioUnitDesc.componentType = kAudioUnitType_Output;
        audioUnitDesc.componentSubType = kAudioUnitSubType_DefaultOutput;
        audioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        AUGraphAddNode(_graph, &audioUnitDesc, &_outNode);
        
        // Low Pass Filter
        audioUnitDesc.componentType = kAudioUnitType_Effect;
        audioUnitDesc.componentSubType = kAudioUnitSubType_LowPassFilter;
        audioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        AUGraphAddNode(_graph, &audioUnitDesc, &_lowPassNode);
        
        // High Pass Filter
        audioUnitDesc.componentType = kAudioUnitType_Effect;
        audioUnitDesc.componentSubType = kAudioUnitSubType_HighPassFilter;
        audioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        AUGraphAddNode(_graph, &audioUnitDesc, &_highPassNode);

        // Converter Node
        audioUnitDesc.componentType = kAudioUnitType_FormatConverter;
        audioUnitDesc.componentSubType = kAudioUnitSubType_AUConverter;
        audioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        AUGraphAddNode(_graph, &audioUnitDesc, &_converterNode);

        AUGraphConnectNodeInput(_graph, _converterNode, 0, _highPassNode, 0);
        AUGraphOpen(_graph);
        
        // Define the format to be used during conversion
        AudioStreamBasicDescription format;
        format.mFormatID = kAudioFormatLinearPCM;
        format.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian;
        format.mSampleRate = kSAMPLE_RATE;
        format.mBitsPerChannel = 16;
        format.mChannelsPerFrame = 2;
        format.mBytesPerFrame = 4;
        format.mFramesPerPacket = 1;
        format.mBytesPerPacket = 4;
        
        AudioUnit convert;
        AUGraphNodeInfo(_graph, _converterNode, NULL, &convert);
        AudioUnitSetProperty(convert, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &format, sizeof(format));
        uint32 r = 882;
        AudioUnitSetProperty(convert, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Input, 0, &r, sizeof(r));
        
        // Audio Render Callback
        AURenderCallbackStruct renderCallback;
        renderCallback.inputProc = render;
        renderCallback.inputProcRefCon = (__bridge void *)self;
        
        AUGraphSetNodeInputCallback(_graph, _converterNode, 0, &renderCallback);
        AUGraphInitialize(_graph);
        AUGraphStop(_graph);
        
        self.lowPassFilter = 5000;
        self.highPassFilter = 50;
        
    }
    return self;
}

- (void)updateBeeperAudioWithValue:(float)value
{
    AVAudioPCMBuffer *buffer = [self.buffers objectAtIndex:self.currentBuffer];
    float * const data = buffer.floatChannelData[0];
    data[_currentBufferPosition++] = value;
    
    if (_currentBufferPosition > _frameCapcity) {
        NSLog(@"oops");
    }
    
//    NSLog(@"%li", _currentBufferPosition);
    
//    if (self.currentBufferPosition == self.frameCapcity) {
//        
//    }
}

- (void)renderAudio {
    
    AVAudioPCMBuffer *buffer = [self.buffers objectAtIndex:self.currentBuffer];
    [self.playerNode scheduleBuffer:buffer completionHandler:^{
        [self.machine startFrame];
    }];
    
    self.currentBufferPosition = 0;
//    self.currentBuffer = (self.currentBuffer + 1) % self.totalBuffers;
    
}




@end






