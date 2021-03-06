//
//  ZXSpectrum48.m
//  ZXRetroEmu
//
//  Created by Mike Daley on 02/09/2016.
//  Copyright © 2016 71Squared Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZXSpectrum48.h"
#import "Z80Core.h"
#import "AudioCore.h"

#pragma mark - Private Interface

@interface ZXSpectrum48 ()

// Emulation queue and timer
@property (weak) NSView *emulationView;
@property (strong) dispatch_queue_t emulationQueue;
@property (strong) dispatch_source_t emulationTimer;
@property (assign) CGColorSpaceRef colourSpace;
@property (strong) id imageRef;
@property (strong) NSString *snapshotPath;
@property (strong) AudioCore *audioCore;

@end

#pragma mark - Structures 

// Structure of pixel data used in the emulation display buffer
struct PixelData {
    uint8 r;
    uint8 g;
    uint8 b;
    uint8 a;
};

// Keyboard data structure
struct KeyboardEntry {
    int keyCode;
    int mapEntry;
    int mapBit;
};

#pragma mark - Variables

// Z80 CPU core
CZ80Core *core;

// Main Memory array
// TODO: Break memory up into 16k banks. This will be needed for 128k machines
unsigned char memory[64 * 1024];

// Memory and IO contention tables
static unsigned char contentionValues[8] = {6, 5, 4, 3, 2, 1, 0, 0};
unsigned char   memoryContentionTable[69888];
unsigned char   ioContentionTable[69888];

// Machine specific tState values
int             tsPerFrame;
int             tsPerLine;
int             tsTopBorder;
int             tsVerticalBlank;
int             tsVerticalDisplay;
int             tsHorizontalDisplay;
int             tsPerChar;
int             tsToOrigin;

// Machine specific pixel values
int             pxTopBorder;
int             pxVerticalBlank;
int             pxHorizontalDisplay;
int             pxVerticalDisplay;
int             pxHorizontalTotal;
int             pxVerticalTotal;

// Display values

// Holds the current border colour as set by the ULA
int             borderColour;

// Used to track the flash phase
int             frameCounter;

// Details for the image that is created for the screen representation
int             emuDisplayBitsPerPx;
int             emuDisplayBitsPerComponent;
int             emuDisplayBytesPerPx;
bool            emuShouldInterpolate;

// Image buffer array buffer, its length and current index into the buffer used when drawing
unsigned char   *emuDisplayBuffer;
unsigned int    emuDisplayBufferLength;
int             emuDisplayBufferIndex;

// Width and height of the image used to display the emulated screen
int             emuDisplayPxWidth;
int             emuDisplayPxHeight;

// Width of the left and right border in chars. A char is 8 pixels wide
int             emuLeftBorderChars;
int             emuRightBorderChars;

// Height of the top and bottom borders in pixel lines
int             emuTopBorderLines;
int             emuBottomBorderLines;

// The maximum beam exten on the X and Y axis. These are used to track if the simulated CRT beam is outside the
// normal screen boundaries for the machine
int             emuBeamXMax;
int             emuBeamYMax;

// Tracks the number of tStates used for drawing the screen. This is compared with the number of tStates that have passed
// in the current frame so that the right number of 8x1 screen chunks are drawn
int             emuDisplayTs;
int             emuCurrentLineStartTs;
int             emuDisplayTsOffset;

int             pixelBeamX;
int             pixelBeamY;

// Holds the current pixel and attribute line addresses when rendering the screen
int             pixelAddress;
int             attrAddress;

// Audio
int             audioStepTStates;
float           audioValue;
int             audioTStates;
bool            beeperOn;

// Events

typedef enum : NSUInteger {
    None,
    Reset,
    Snapshot,
} EventType;

EventType event;

// Pallette

PixelData pallette[] = {
  
    // Normal colours
    {0, 0, 0, 255},         // Black
    {0, 0, 204, 255},       // Blue
    {204, 0, 0, 255},       // Red
    {204, 0, 204, 255},     // Green
    {0, 204, 0, 255},       // Magenta
    {0, 204, 204, 255},     // Cyan
    {204, 204, 0, 255},     // Yellow
    {204, 204, 204, 255},   // White
        
    // Bright colours
    {0, 0, 0, 255},
    {0, 0, 255, 255},
    {255, 0, 0, 255},
    {255, 0, 255, 255},
    {0, 255, 0, 255},
    {0, 255, 255, 255},
    {255, 255, 0, 255},
    {255, 255, 255, 255}

};

// Keyboard Data
unsigned char keyboardMap[8];

KeyboardEntry keyboardLookup[] = {
    { 6, 0,	1 },    // Z
    { 7, 0,	2 },    // X
    { 8, 0,	3 },    // C
    { 9, 0,	4 },    // V
    
    { 0, 1,	0 },    // A
    { 1, 1,	1 },    // S
    { 2, 1,	2 },    // D
    { 3, 1,	3 },    // F
    { 5, 1,	4 },    // G
    
    { 12, 2, 0 },   // Q
    { 13, 2, 1 },   // W
    { 14, 2, 2 },   // E
    { 15, 2, 3 },   // R
    { 17, 2, 4 },   // T
    
    { 18, 3, 0 },   // 1
    { 19, 3, 1 },   // 2
    { 20, 3, 2 },   // 3
    { 21, 3, 3 },   // 4
    { 23, 3, 4 },   // 5
    
    { 29, 4, 0 },   // 0
    { 25, 4, 1 },   // 9
    { 28, 4, 2 },   // 8
    { 26, 4, 3 },   // 7
    { 22, 4, 4 },   // 6
    
    { 35, 5, 0 },   // P
    { 31, 5, 1 },   // O
    { 34, 5, 2 },   // I
    { 32, 5, 3 },   // U
    { 16, 5, 4 },   // Y
    
    { 36, 6, 0 },   // ENTER
    { 37, 6, 1 },   // L
    { 40, 6, 2 },   // K
    { 38, 6, 3 },   // J
    { 4,  6, 4 },   // H
    
    { 49, 7, 0 },   // Space
    { 46, 7, 2 },   // M
    { 45, 7, 3 },   // N
    { 11, 7, 4 }    // B
};

#pragma mark - Implementation

@implementation ZXSpectrum48

- (instancetype)initWithEmulationScreenView:(NSView *)view
{
    self = [super init];
    if (self) {
        
        _emulationView = view;
        
        core = new CZ80Core;
        core->Initialise(coreMemoryRead, coreMemoryWrite, coreIORead, coreIOWrite, coreMemoryContention, coreIOContention, 0);
        
        event = None;

        borderColour = 1;
        frameCounter = 0;
        
        _colourSpace = CGColorSpaceCreateDeviceRGB();

        pxTopBorder = 56;
        pxVerticalBlank = 8;
        pxHorizontalDisplay = 256;
        pxVerticalDisplay = 192;
        pxHorizontalTotal = 448;
        pxVerticalTotal = 312;
        
        tsPerFrame = 69888;
        tsPerLine = 224;
        tsTopBorder = pxTopBorder * tsPerLine;
        tsVerticalBlank = pxVerticalBlank * tsPerLine;
        tsVerticalDisplay = pxVerticalDisplay * tsPerLine;
        tsHorizontalDisplay = 128;
        tsPerChar = 4;
        tsToOrigin = 14336;
        
        emuShouldInterpolate = YES;
        emuDisplayBitsPerPx = 32;
        emuDisplayBitsPerComponent = 8;
        emuDisplayBytesPerPx = 4;
        
        emuLeftBorderChars = 5;
        emuRightBorderChars = 5;
        
        emuBottomBorderLines = emuLeftBorderChars * 8;
        emuTopBorderLines = emuLeftBorderChars * 8;
        
        emuBeamXMax = (32 + emuRightBorderChars);
        emuBeamYMax = (192 + emuBottomBorderLines);

        emuDisplayPxWidth = 256 + 8 * (emuLeftBorderChars + emuRightBorderChars);
        emuDisplayPxHeight = 192 + emuTopBorderLines + emuBottomBorderLines;
        emuDisplayTsOffset = 4;

        [self startDisplayFrame];
        
        // Setup the display buffer and length used to store the output from the emulator
        emuDisplayBufferLength = (emuDisplayPxWidth * emuDisplayPxHeight) * emuDisplayBytesPerPx;
        emuDisplayBuffer = (unsigned char *)malloc(emuDisplayBufferLength);
        
        float fps = 50.08;

        _audioCore = [[AudioCore alloc] initWithSampleRate:44100 framesPerSecond:fps];
        
        audioStepTStates = (tsPerFrame * fps) / 44100;
        
        [self buildContentionTable];
        [self resetKeyboardMap];
        [self loadDefaultROM];
        
        _emulationQueue = dispatch_queue_create("emulationQueue", nil);
        _emulationTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _emulationQueue);
        dispatch_source_set_timer(_emulationTimer, DISPATCH_TIME_NOW, 1.0/fps * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(_emulationTimer, ^{
            
            switch (event) {
                case None:
                    break;

                case Reset:
                    event = None;
                    [self reset];
                    break;
                    
                case Snapshot:
                    [self reset];
                    [self loadSnapshot];
                    event = None;
                    break;
                    
                default:
                    break;
            }
            
            [self doFrame];
            [self generateImage];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.emulationView.layer.contents = self.imageRef;
            });
        
        });
        
    }
    return self;
}

- (void)startExecution {
    dispatch_resume(_emulationTimer);
}

- (void)stopExecution {
    dispatch_suspend(_emulationTimer);
}

#pragma mark - CPU

- (void)reset {
    core->Reset();
    frameCounter = 0;
    beeperOn = false;
    [self startDisplayFrame];
    [self resetKeyboardMap];
}

- (void)doFrame {
    
    int count = tsPerFrame;
    while (count > 0) {
        count -= [self step];
    }
}

- (int)step {
    
    int tsCPU = core->Execute(1);
    
    [self updateSreenWithTStates];
    [self updateAudioWithTStates:tsCPU];
    
    if (core->GetTStates() > tsPerFrame) {
        
        core->ResetTStates(tsPerFrame);
        core->SignalInterrupt();
        
        // Reset the drawing vars.
        [self startDisplayFrame];
        
        frameCounter++;
    }
    
    return tsCPU;
}

#pragma mark - Display

- (void)updateSreenWithTStates {
    
    // Keep drawing 8x1 screen chucks based on the number of Ts in the current frame
    while (emuDisplayTs <= core->GetTStates() && emuDisplayTs != -1) {
        
        // Draw the borders
        if (pixelBeamY < 0 || pixelBeamY >= 192 || pixelBeamX < 0 || pixelBeamX >= 32) {
            
            for (int i = 0; i < 8; i ++) {
                emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[borderColour].r;
                emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[borderColour].g;
                emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[borderColour].b;
                emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[borderColour].a;
            }
            
        } else { // Draw the main bitmap screen
            
            int pixelByte = memory[pixelAddress | pixelBeamX];
            int attributeByte = memory[attrAddress | pixelBeamX];
            
            // Extract the ink and paper colours from the attribute byte read in
            int ink = (attributeByte & 0x07) + ((attributeByte & 0x40) >> 3);
            int paper = ((attributeByte >> 3) & 0x07) + ((attributeByte & 0x40) >> 3);
            
            // Switch ink and paper if the flash phase has changed
            if ((frameCounter & 16) && (attributeByte & 0x80)) {
                int tempPaper = paper;
                paper = ink;
                ink = tempPaper;
            }

            // Loop through the current pixel byte drawing pixels into the screen image buffer
            for (int b = 0x80; b; b >>= 1) {
                
                if (pixelByte & b) {
                    emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[ink].r;
                    emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[ink].g;
                    emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[ink].b;
                    emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[ink].a;
                } else {
                    emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[paper].r;
                    emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[paper].g;
                    emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[paper].b;
                    emuDisplayBuffer[emuDisplayBufferIndex++] = pallette[paper].a;
                }
            }
        }
        
        // Step the pixel beam 1 char position right, which is in effect 8 pixels
        pixelBeamX ++;
        
        if (pixelBeamX < emuBeamXMax) {
            // Not reached the right edge of the screen so update the drawing Ts by 1 char
            emuDisplayTs += tsPerChar;
        } else {
            
            // Reached the right edge of the screen so reset the X beam and drop down one line
            pixelBeamX = -emuLeftBorderChars;
            pixelBeamY++;
            
            // If the new line is within the bitmap screen update the pixel and attrubute line addresses
            if (pixelBeamY >= 0 && pixelBeamY < 192) {
                pixelAddress = 16384 | ( (pixelBeamY & 0xc0) << 5 ) | ( (pixelBeamY & 0x07) << 8 ) | ( (pixelBeamY & 0x38) << 2 );
                attrAddress = 16384 | 0x1800 | ( (pixelBeamY & 0xf8) << 2 );
            }
            
            // If we are not past the bottom of the screen then update the drawing Ts with an entire line
            if (pixelBeamY < emuBeamYMax) {
                emuCurrentLineStartTs += tsPerLine;
                emuDisplayTs = emuCurrentLineStartTs;
            } else {
                // Finished the screen
                emuDisplayTs = -1;
            }
        }
    }
}

- (void)generateImage {
    
    CFDataRef dataRef = CFDataCreate(kCFAllocatorDefault, emuDisplayBuffer, emuDisplayBufferLength);
    
    CGDataProviderRef providerRef = CGDataProviderCreateWithCFData(dataRef);
    
    _imageRef = CFBridgingRelease(CGImageCreate(emuDisplayPxWidth,
                                                emuDisplayPxHeight,
                                                emuDisplayBitsPerComponent,
                                                emuDisplayBitsPerPx,
                                                emuDisplayPxWidth * emuDisplayBytesPerPx,
                                                _colourSpace,
                                                (CGBitmapInfo)kCGImageAlphaPremultipliedLast,
                                                providerRef,
                                                nil,
                                                emuShouldInterpolate,
                                                kCGRenderingIntentDefault));
    
    // Clean up
    CGDataProviderRelease(providerRef);
    CFRelease(dataRef);
}

- (void)startDisplayFrame {
    pixelBeamX = -emuLeftBorderChars;
    pixelBeamY = -emuTopBorderLines;
    emuDisplayTs = tsToOrigin - (emuTopBorderLines * tsPerLine) - (emuLeftBorderChars * tsPerChar) - emuDisplayTsOffset;
    emuCurrentLineStartTs = emuDisplayTs;
    emuDisplayBufferIndex = 0;
}

#pragma mark - Audio

- (void)updateAudioWithTStates:(int)numberTs {
    
    while (audioTStates + numberTs > audioStepTStates) {
        
        int tStates = audioStepTStates - audioTStates;
        
        audioValue += beeperOn ? (8192 * tStates) : 0;
        
        [self.audioCore updateBeeperAudioWithValue:audioValue / audioStepTStates];
        
        numberTs = (audioTStates + numberTs) - audioStepTStates;
        audioValue = 0;
        audioTStates = 0;
        
    }
    
    audioValue += beeperOn ? (8192 * numberTs) : 0;
    audioTStates += numberTs;
}

#pragma mark - Memory & IO methods

static unsigned char coreMemoryRead(unsigned short address, int tstates) {
    return memory[address];
}

static void coreMemoryWrite(unsigned short address, unsigned char data, int tstates) {
    
    // Only allow writing to RAM not ROM
    if (address >= 16384) {
        memory[address] = data;
    }
    
}

static unsigned char coreIORead(unsigned short address, int tstates) {
    
    // Calculate the necessary contention based on the Port number being accessed and if the port belongs to the ULA.
    // All non-even port numbers below to the ULA. N:x means no contention to be added and just advance the tStates.
    // C:x means that contention should be calculated based on the current tState value and then x tStates are to be
    // added to the current tState count
    //
    // in 40 - 7F?| Low bit | Contention pattern
    //------------+---------+-------------------
    //		No    |  Reset  | N:1, C:3
    //		No    |   Set   | N:4
    //		Yes   |  Reset  | C:1, C:3
    //		Yes   |   Set   | C:1, C:1, C:1, C:1
    //
    if (address >= 16384 && address <= 32767) {
        if ((address & 1) == 0) {
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(3);
        } else {
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
        }
    } else {
        if ((address & 1) == 0) {
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(3);
        } else {
            core->AddTStates(4);
        }
    }
    
    if ((address & 0xff) == 0xfe) {
        for (int i = 0; i < 8; i++) {
            int addr = address & (0x100 << i);
            if (addr == 0) {
                return keyboardMap[i] & 0xff;
            }
        }
    }
    
    return 0xff;
}

static void coreIOWrite(unsigned short address, unsigned char data, int tstates) {
    
    // Calculate the necessary contention based on the Port number being accessed and if the port belongs to the ULA.
    // All non-even port numbers below to the ULA. N:x means no contention to be added and just advance the tStates.
    // C:x means that contention should be calculated based on the current tState value and then x tStates are to be
    // added to the current tState count
    //
    // in 40 - 7F?| Low bit | Contention pattern
    //------------+---------+-------------------
    //		No    |  Reset  | N:1, C:3
    //		No    |   Set   | N:4
    //		Yes   |  Reset  | C:1, C:3
    //		Yes   |   Set   | C:1, C:1, C:1, C:1
    //
    if (address >= 16384 && address <= 32767) {
        if ((address & 1) == 0) {
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(3);
        } else {
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(1);
        }
    } else {
        if ((address & 1) == 0) {
            core->AddTStates(1);
            core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
            core->AddTStates(3);
        } else {
            core->AddTStates(4);
        }
    }

    if ((address & 0xff) == 0xfe) {
        borderColour = data & 0x07;
        beeperOn = (data & 0x10) ? true : false;
    }
}

static void coreMemoryContention(unsigned short address, unsigned int tstates, int param) {
    
    if (address >= 16384 && address <= 32767) {
        core->AddContentionTStates(memoryContentionTable[core->GetTStates() % tsPerFrame]);
    }
    
}

static void coreIOContention(unsigned short address, unsigned int tstates, int param) {
    // NOT USED
}

#pragma mark - Contention Tables

- (void)buildContentionTable {
    
    for (int i = 0; i < tsPerFrame; i++) {
        
        memoryContentionTable[i] = 0;
        ioContentionTable[i] = 0;
        
        // 14336 Ts is reported by most ZX Spectrum machines while there were a percentage that would
        // respond to the /INT late report 14335 Ts. We are setting up contention for 14336 Ts
        int ts = i - ((tsTopBorder + tsVerticalBlank) - 1);

        if (ts >= 0 && ts < (int)tsVerticalDisplay) {
            int perLine = ts % tsPerLine;
            if (perLine < tsHorizontalDisplay) {
                memoryContentionTable[i] = contentionValues[perLine & 7];
                ioContentionTable[i] = contentionValues[perLine & 7];
            }
        }
    }
}

#pragma mark - Load ROM

- (void)loadDefaultROM {
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"48" ofType:@"ROM"];
    NSData *rom = [NSData dataWithContentsOfFile:path];
    
    const char *fileBytes = (const char*)[rom bytes];
    
    for (int addr = 0; addr < rom.length; addr++) {
        memory[addr] = fileBytes[addr];
    }
}

#pragma mark - SnapShot

- (void)loadSnapshotWithPath:(NSString *)path {
    self.snapshotPath = path;
    event = Snapshot;
}

- (void)loadSnapshot {
    
    NSData *data = [NSData dataWithContentsOfFile:self.snapshotPath];
    
    const char *fileBytes = (const char*)[data bytes];
    
    if (data.length == 49179) {
        
        int snaAddr = 27;
        for (int i= 16384; i < (48 * 1024) + 16384; i++) {
            memory[i] = fileBytes[snaAddr++];
        }
        
        // Decode the header
        core->SetRegister(CZ80Core::eREG_I, fileBytes[0]);
        core->SetRegister(CZ80Core::eREG_R, fileBytes[20]);
        core->SetRegister(CZ80Core::eREG_ALT_HL, ((unsigned short *)&fileBytes[1])[0]);
        core->SetRegister(CZ80Core::eREG_ALT_DE, ((unsigned short *)&fileBytes[1])[1]);
        core->SetRegister(CZ80Core::eREG_ALT_BC, ((unsigned short *)&fileBytes[1])[2]);
        core->SetRegister(CZ80Core::eREG_ALT_AF, ((unsigned short *)&fileBytes[1])[3]);
        core->SetRegister(CZ80Core::eREG_HL, ((unsigned short *)&fileBytes[1])[4]);
        core->SetRegister(CZ80Core::eREG_DE, ((unsigned short *)&fileBytes[1])[5]);
        core->SetRegister(CZ80Core::eREG_BC, ((unsigned short *)&fileBytes[1])[6]);
        core->SetRegister(CZ80Core::eREG_IY, ((unsigned short *)&fileBytes[1])[7]);
        core->SetRegister(CZ80Core::eREG_IX, ((unsigned short *)&fileBytes[1])[8]);
        
        core->SetRegister(CZ80Core::eREG_AF, ((unsigned short *)&fileBytes[21])[0]);
        core->SetRegister(CZ80Core::eREG_SP, ((unsigned short *)&fileBytes[21])[1]);
        
        // Border colour
        borderColour = fileBytes[26];
        
        // Set the IM
        core->SetIMMode(fileBytes[25]);
        
        // Do both on bit 2 as a RETN copies IFF2 to IFF1
        core->SetIFF1((fileBytes[19] >> 2) & 1);
        core->SetIFF2((fileBytes[19] >> 2) & 1);
        
        // Set the PC
        unsigned char pc_lsb = memory[core->GetRegister(CZ80Core::eREG_SP)];
        unsigned char pc_msb = memory[core->GetRegister(CZ80Core::eREG_SP) + 1];
        core->SetRegister(CZ80Core::eREG_PC, (pc_msb << 8) | pc_lsb);
        core->SetRegister(CZ80Core::eREG_SP, core->GetRegister(CZ80Core::eREG_SP) + 2);
        
        [self startDisplayFrame];
    }
}

#pragma mark - View Event Protocol Methods

- (void)keyDown:(NSEvent *)theEvent {
    
    switch (theEvent.keyCode) {
        case 51: // Backspace
            keyboardMap[0] &= ~0x01; // Shift
            keyboardMap[4] &= ~0x01; // 0
            break;
            
        case 126: // Arrow up
            keyboardMap[0] &= ~0x01; // Shift
            keyboardMap[4] &= ~0x08; // 7
            break;
            
        case 125: // Arrow down
            keyboardMap[0] &= ~0x01; // Shift
            keyboardMap[4] &= ~0x10; // 6
            break;
            
        case 123: // Arrow left
            keyboardMap[0] &= ~0x01; // Shift
            keyboardMap[3] &= ~0x10; // 5
            break;
            
        case 124: // Arrow right
            keyboardMap[0] &= ~0x01; // Shift
            keyboardMap[4] &= ~0x04; // 8
            break;
            
        default:
            for (NSUInteger i = 0; i < sizeof(keyboardLookup) / sizeof(keyboardLookup[0]); i++) {
                
                if (keyboardLookup[i].keyCode == theEvent.keyCode) {
                    keyboardMap[keyboardLookup[i].mapEntry] &= ~(1 << keyboardLookup[i].mapBit);
                    break;
                }
            }
            break;
    }
    
    
}

- (void)keyUp:(NSEvent *)theEvent {
    
    switch (theEvent.keyCode) {
        case 51: // Backspace
            keyboardMap[0] |= 0x01; // Shift
            keyboardMap[4] |= 0x01; // 0
            break;
            
        case 126: // Arrow up
            keyboardMap[0] |= 0x01; // Shift
            keyboardMap[4] |= 0x08; // 7
            break;
            
        case 125: // Arrow down
            keyboardMap[0] |= 0x01; // Shift
            keyboardMap[4] |= 0x10; // 6
            break;
            
        case 123: // Arrow left
            keyboardMap[0] |= 0x01; // Shift
            keyboardMap[3] |= 0x10; // 5
            break;
            
        case 124: // Arrow right
            keyboardMap[0] |= 0x01; // Shift
            keyboardMap[4] |= 0x04; // 8
            break;
            
        default:
            for (NSUInteger i = 0; i < sizeof(keyboardLookup) / sizeof(keyboardLookup[0]); i++) {
                
                if (keyboardLookup[i].keyCode == theEvent.keyCode) {
                    keyboardMap[keyboardLookup[i].mapEntry] |= (1 << keyboardLookup[i].mapBit);
                    break;
                }
            }
            break;
    }
    
}

- (void)flagsChanged:(NSEvent *)theEvent {
    
    switch (theEvent.keyCode) {
        case 56: // Left Shift
        case 60: // Right Shift
            if (theEvent.modifierFlags & NSShiftKeyMask) {
                keyboardMap[0] &= ~0x01;
            } else {
                keyboardMap[0] |= 0x01;
            }
            break;
        case 59: // Control
            if (theEvent.modifierFlags & NSControlKeyMask) {
                keyboardMap[7] &= ~0x02;
            } else {
                keyboardMap[7] |= 0x02;
            }
            
        default:
            break;
    }
    
}

- (void)resetKeyboardMap {
    
    for (int i = 0; i < 8; i++) {
        keyboardMap[i] = 0xff;
    }
    
}

@end
