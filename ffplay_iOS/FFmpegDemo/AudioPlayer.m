//
//  AudioPlayer.m
//  FFmpegDemo
//
//  Created by zhw on 2019/7/23.
//  Copyright © 2019 zhw. All rights reserved.
//

#import "AudioPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#define INPUT_BUS 1
#define OUTPUT_BUS 0

@implementation AudioPlayer
{
    AudioUnit _audioUnit;
}

- (void)prepare
{
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
    outputFormat.mSampleRate       = self.sampleRate; // 采样率
    outputFormat.mFormatID         = kAudioFormatLinearPCM; // PCM格式
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger; // 浮点数
    outputFormat.mFramesPerPacket  = 1; // 非压缩数据，固定填1
    outputFormat.mChannelsPerFrame = self.channels; // 声道数
    /*对于交错声音格式，mBytesPerFrame = 声道数 * 每个采样点占的字节数(浮点数是4)，
     非交错格式，mBytesPerFrame = 每个采样点占的字节数(浮点数是4)
     */
    outputFormat.mBytesPerFrame    = self.channels * 2;
    outputFormat.mBytesPerPacket   = outputFormat.mBytesPerFrame;
    outputFormat.mBitsPerChannel   = 8 * 2; //每声道占的位数
//    [self printAudioStreamBasicDescription:outputFormat];
    
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
    

}
- (void)start
{
    OSStatus status = noErr;
    status = AudioOutputUnitStart(_audioUnit);
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
    AudioPlayer *p = (__bridge AudioPlayer *)inRefCon;
    if ([p.delegate respondsToSelector:@selector(audioPlayer:data:length:)]) {
        [p.delegate audioPlayer:p data:ioData->mBuffers[0].mData length:ioData->mBuffers[0].mDataByteSize];
    }
//    NSLog(@"out size: %d", ioData->mBuffers[0].mDataByteSize);
    
    return noErr;
}
- (void)stop {
    AudioOutputUnitStop(_audioUnit);
    AudioUnitUninitialize(_audioUnit);
    AudioComponentInstanceDispose(_audioUnit);
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
@end
