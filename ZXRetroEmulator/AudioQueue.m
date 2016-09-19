//
//  AudioQueue.m
//  ZXRetroEmulator
//
//  Created by Mike Daley on 15/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import "AudioQueue.h"

#define kExponent 18
#define kMask (_capacity - 1)
#define kUsed ((_written - _read) & ((1 << kExponent) - 1))
#define kSpace (_capacity - 1 - kUsed)
#define kSize (_capacity - 1)

@interface AudioQueue ()

@property (assign) int16_t *buffer;
@property (assign) int read;
@property (assign) int written;
@property (assign) int capacity;

@end

@implementation AudioQueue

- (void)dealloc
{
    
    free(_buffer);

}

+ (AudioQueue *)queue
{
    AudioQueue *audioQueue = [AudioQueue new];
    [audioQueue setup];
    return audioQueue;
}

- (void)setup
{
    _capacity = 1 << kExponent;
    _buffer = malloc(_capacity << 1);
    _read = 0;
    _written = 0;
}

- (int)write:(int16_t *)data count:(uint)bytes
{
    
    if (!data) {
        return 0;
    }
    
    int t;
    int i;
    
    t = kSpace;
    
    if (bytes > t)
    {
        bytes = t;
    } else {
        t = bytes;
    }
    
    i = _written;
    
    if ((i + bytes) > _capacity)
    {
        memcpy(_buffer + i, data, (_capacity - i) << 1);
        data += _capacity - i;
        bytes -= _capacity - i;
        i = 0;
    }
    
    memcpy(_buffer + i, data, bytes << 1);
    _written = i + bytes;
    
    return t;
}

- (int)read:(int16_t *)data count:(uint)bytes
{
    
    int t;
    int i;
    
    t = kUsed;
    
    if (bytes > t)
    {
        bytes = t;
    } else {
        t = bytes;
    }
    
    i = _read;
    
    if ((i + bytes) > _capacity)
    {
        memcpy(data, _buffer + i, (_capacity - i) << 1);
        data += _capacity - i;
        bytes -= _capacity - i;
        i = 0;
    }
    
    memcpy(data, _buffer + i, bytes << 1);
    _read = i + bytes;
        
    return t;
}

- (int)used
{
    return kUsed;
}

@end
