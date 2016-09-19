//
//  AudioCore.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 03/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "AudioCore.h"
#import "ZXSpectrum48.h"
#import "AudioQueue.h"

#pragma mark - Private interface

@interface AudioCore ()

// Reference to the machine using the audio core
@property (weak) ZXSpectrum48 *machine;

// reference to the emulation queue that is being used to drive the emulation
@property (assign) dispatch_queue_t emulationQueue;

// Queue used to control the samples being provided to Core Audio
@property (strong) AudioQueue *queue;

// Properties used to store the CoreAudio graph and nodes, including the high and low pass effects nodes
@property (assign) AUGraph graph;
@property (assign) AUNode outNode;
@property (assign) AUNode converterNode;
@property (assign) AUNode lowPassNode;
@property (assign) AUNode highPassNode;

@end

// Signature of the CoreAudio render callback. This is called by CoreAudio when it needs more data in its buffer.
// By using AudioQueue we can generate another new frame of data at 50.08 fps making sure that the audio stays in
// sync with the frames.
static OSStatus renderAudio(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlags,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData);

#pragma mark - Implementation

@implementation AudioCore

- (instancetype)initWithSampleRate:(int)sampleRate framesPerSecond:(float)fps emulationQueue:queue machine:(ZXSpectrum48 *)machine
{
    self = [super init];
    if (self) {
        
        _emulationQueue = queue;
        _queue = [AudioQueue queue];
        _machine = machine;
        
        NewAUGraph(&_graph);
        
        // Output Node
        AudioComponentDescription componentDescription;
        componentDescription.componentType = kAudioUnitType_Output;
        componentDescription.componentSubType = kAudioUnitSubType_DefaultOutput;
        componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        AUGraphAddNode(_graph, &componentDescription, &_outNode);
        
        // Low pass effect node
        componentDescription.componentType = kAudioUnitType_Effect;
        componentDescription.componentSubType = kAudioUnitSubType_LowPassFilter;
        componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        AUGraphAddNode(_graph, &componentDescription, &_lowPassNode);
        
        AUGraphConnectNodeInput(_graph, _lowPassNode, 0, _outNode, 0);
        
        // High pass effect node
        componentDescription.componentType = kAudioUnitType_Effect;
        componentDescription.componentSubType = kAudioUnitSubType_HighPassFilter;
        componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        AUGraphAddNode(_graph, &componentDescription, &_highPassNode);
        
        AUGraphConnectNodeInput(_graph, _highPassNode, 0, _lowPassNode, 0);
        
        // Converter node
        componentDescription.componentType = kAudioUnitType_FormatConverter;
        componentDescription.componentSubType = kAudioUnitSubType_AUConverter;
        componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        AUGraphAddNode(_graph, &componentDescription, &_converterNode);
        
        AUGraphConnectNodeInput(_graph, _converterNode, 0, _highPassNode, 0);
        
        AUGraphOpen(_graph);
        
        // Buffer format
        AudioStreamBasicDescription bufferFormat;
        bufferFormat.mFormatID = kAudioFormatLinearPCM;
        bufferFormat.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian;
        bufferFormat.mSampleRate = sampleRate;
        bufferFormat.mBitsPerChannel = 16;
        bufferFormat.mChannelsPerFrame = 2;
        bufferFormat.mBytesPerFrame = 4;
        bufferFormat.mFramesPerPacket = 1;
        bufferFormat.mBytesPerPacket = 4;
        
        // Set the frames per slice property on the converter node
        AudioUnit convert;
        AUGraphNodeInfo(_graph, _converterNode, NULL, &convert);
        AudioUnitSetProperty(convert, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &bufferFormat, sizeof(bufferFormat));
        
        uint32 framesPerSlice = 882;
        AudioUnitSetProperty(convert, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Input, 0, &framesPerSlice, sizeof(framesPerSlice));
        
        // define the callback for rendering audio
        AURenderCallbackStruct renderCallbackStruct;
        renderCallbackStruct.inputProc = renderAudio;
        renderCallbackStruct.inputProcRefCon = (__bridge void *)self;
        
        // Attach the audio callback to the converterNode
        AUGraphSetNodeInputCallback(_graph, _converterNode, 0, &renderCallbackStruct);
        AUGraphInitialize(_graph);
        AUGraphStart(_graph);
        
        // Initial filter settings
        self.lowPassFilter = 5000;
        self.highPassFilter = 50;

    }
    return self;
}

static OSStatus renderAudio(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlags,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData)
{
//    NSLog(@"Frames: %u", (unsigned int)inNumberFrames);

    AudioCore *audioCore = (__bridge AudioCore *)inRefCon;

    // Grab the buffer that core audio has passed in and reset its contents to 0
    int16_t *buffer = ioData->mBuffers[0].mData;
    memset(buffer, 0, inNumberFrames << 2);
    
    // Update the queue with the reset buffer
    [audioCore.queue read:buffer count:(inNumberFrames << 1)];


    if ([audioCore.queue used] < (3840 << 1))
    {
        dispatch_async(audioCore.emulationQueue, ^{
            [audioCore.machine doFrame];
        });
        
        [audioCore.queue write:audioCore.machine.audioBuffer count:(3840 << 1)];        
    }
    
    ioData->mBuffers[0].mDataByteSize = (inNumberFrames << 2);
    
    return noErr;
    
}

- (void)setLowPassFilter:(double)lowPassFilter
{
    _lowPassFilter = lowPassFilter;
    AudioUnit filterUnit;
    AUGraphNodeInfo(_graph, _lowPassNode, NULL, &filterUnit);
    AudioUnitSetParameter(filterUnit, 0, kAudioUnitScope_Global, 0, lowPassFilter, 0);
}

- (void)setHighPassFilter:(double)highPassFilter
{
    _highPassFilter = highPassFilter;
    AudioUnit filterUnit;
    AUGraphNodeInfo(_graph, _highPassNode, NULL, &filterUnit);
    AudioUnitSetParameter(filterUnit, 0, kAudioUnitScope_Global, 0, highPassFilter, 0);
}

@end