//
//  ViewController.m
//  AudioUnitPlayPCM
//
//  Created by zhw on 2019/7/23.
//  Copyright © 2019 zhw. All rights reserved.
//

#import "ViewController.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#define INPUT_BUS 1
#define OUTPUT_BUS 0

@interface ViewController ()

@end

@implementation ViewController
{
    AudioUnit _audioUnit;
    FILE *_inFile;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self play];
    
}
- (void)play
{
    //打开文件
    const char *in_filename = [[[NSBundle mainBundle] pathForResource:@"sintel_f32le_2_48000.pcm" ofType:nil] UTF8String];
    _inFile = fopen(in_filename, "rb");
    if (!_inFile) {
        printf("open file %s failed\n", in_filename);
        return;
    }
    
    NSError *error = nil;
    OSStatus status = noErr;
    
    //设置audioSession，只播放
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    //设置类型RemoteIO，用于播放
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &_audioUnit);
    
    UInt32 flag = 1;
    //打开element0(OUTPUT_BUS=0)的输出scope，也就是开启扬声器
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  OUTPUT_BUS,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty error : %d", status);
        return;
    }
    
    //设置输入的音频格式
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = 48000; // 采样率
    outputFormat.mFormatID         = kAudioFormatLinearPCM; // PCM格式
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsFloat; // 浮点数
    outputFormat.mFramesPerPacket  = 1; // 非压缩数据，固定填1
    outputFormat.mChannelsPerFrame = 2; // 声道数
    /*对于交错声音格式，mBytesPerFrame = 声道数 * 每个采样点占的字节数(浮点数是4)，
      非交错格式，mBytesPerFrame = 每个采样点占的字节数(浮点数是4)
     */
    outputFormat.mBytesPerFrame    = 2 * 4;
    outputFormat.mBytesPerPacket   = outputFormat.mBytesPerFrame;
    outputFormat.mBitsPerChannel   = 8 * 4; //每声道占的位数
    [self printAudioStreamBasicDescription:outputFormat];
    
    //设置element0的输入scope
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty error : %d", status);
        return;
    }
    
    //设置回调函数
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(_audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
    
    
    status = AudioUnitInitialize(_audioUnit);
    if (status != noErr) {
        NSLog(@"AudioUnitInitialize error : %d", status);
        return;
    }
    
    status =  AudioOutputUnitStart(_audioUnit);
    if (status != noErr) {
        NSLog(@"AudioOutputUnitStart error : %d", status);
        return;
    }
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    
    ViewController *vc = (__bridge ViewController *)inRefCon;

    ioData->mBuffers[0].mDataByteSize = (UInt32)fread(ioData->mBuffers[0].mData, 1, ioData->mBuffers[0].mDataByteSize, vc->_inFile);
    NSLog(@"out size: %d", ioData->mBuffers[0].mDataByteSize);
    
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [vc stop];
        });
    }
    return noErr;
}
- (void)stop {
    AudioOutputUnitStop(_audioUnit);
    AudioUnitUninitialize(_audioUnit);
    AudioComponentInstanceDispose(_audioUnit);
    fclose(_inFile);
}


- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}
- (void)dealloc {
    

}


@end
