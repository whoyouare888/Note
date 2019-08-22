//
//  ViewController.m
//  VTDecode
//
//  Created by zhw on 2019/8/21.
//  Copyright © 2019 zhw. All rights reserved.
//

#import "ViewController.h"
#import <VideoToolbox/VideoToolbox.h>
#import "VPVideoStreamPlayLayer.h"

static const uint8_t startCode[4] = {0, 0, 0, 1};

@interface ViewController ()
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic , strong) CADisplayLink *dispalyLink;
@property (nonatomic, strong) VPVideoStreamPlayLayer *playLayer;

@end

@implementation ViewController
{
    VTDecompressionSessionRef _decodeSession;
    CMFormatDescriptionRef  _formatDescription;
    uint8_t *_sps;
    long _spsSize;
    uint8_t *_pps;
    long _ppsSize;
    
    uint8_t *_packetBuffer;
    long _packetSize;
    uint8_t *_inputBuffer;
    long _inputSize;
    long _inputMaxSize;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.playLayer = [[VPVideoStreamPlayLayer alloc] initWithFrame:CGRectMake(0, 60, self.view.frame.size.width, 500)];
    [self.view.layer addSublayer:self.playLayer];
    
    [self initInputFile];
    
    
    self.dispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(startDecode)];
    self.dispalyLink.frameInterval = 2; // 默认是30FPS的帧率录制
    [self.dispalyLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
}

- (void)initInputFile
{
    self.inputStream = [[NSInputStream alloc] initWithFileAtPath:[[NSBundle mainBundle] pathForResource:@"result" ofType:@"h264"]];
    [self.inputStream open];
    _inputSize = 0;
    _inputMaxSize = 100000;
    _inputBuffer = calloc(_inputMaxSize, 1);
}
- (void)inputEnd {
    [self.inputStream close];
    self.inputStream = nil;
    if (_inputBuffer) {
        free(_inputBuffer);
        _inputBuffer = NULL;
    }
    [self.dispalyLink setPaused:YES];

    
}
- (void)initVideoToolbox
{
    // 根据sps pps创建解码视频参数
    CMFormatDescriptionRef fmtDesc;
    const uint8_t* parameterSetPointers[2] = {_sps, _pps};
    const size_t parameterSetSizes[2] = {_spsSize, _ppsSize};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &fmtDesc);
    if (status != noErr) {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
        return;
    }
    
    if (_decodeSession == nil || !VTDecompressionSessionCanAcceptFormatDescription(_decodeSession, fmtDesc)) {
        if (_decodeSession) {
            VTDecompressionSessionInvalidate(_decodeSession);
            CFRelease(_decodeSession);
            _decodeSession = nil;
        }
        if (_formatDescription) {
            CFRelease(_formatDescription);
        }
        
        _formatDescription = fmtDesc;
        
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(_formatDescription);
        NSDictionary *attrs = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
                                (id)kCVPixelBufferWidthKey : @(dimensions.width),
                                (id)kCVPixelBufferHeightKey : @(dimensions.height),
                                };
        
        //设置回调
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = decodeOutputDataCallback;
        callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
        
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _formatDescription,
                                              NULL, (__bridge CFDictionaryRef)attrs,
                                              &callBackRecord,
                                              &_decodeSession);
        // 解码线程数量
        VTSessionSetProperty(_decodeSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)@(1));
        // 是否实时解码
        VTSessionSetProperty(_decodeSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    }else {
        CFRelease(fmtDesc);
    }


    
}

- (void)startDecode
{
    [self readPacket];
    if(_packetBuffer == NULL || _packetSize == 0) {
        [self inputEnd];
        return;
    }
    
    //将NALU的开始码替换成NALU的长度信息，长度固定4个字节
    uint32_t nalSize = (uint32_t)(_packetSize - 4);
    uint32_t *pNalSize = (uint32_t *)_packetBuffer;
    *pNalSize = CFSwapInt32HostToBig(nalSize);
    
    int nalType = _packetBuffer[4] & 0x1F;
    switch (nalType) {
        case 0x05:
            NSLog(@"Nal type is IDR frame");
            [self initVideoToolbox];
            [self decode];
            break;
        case 0x07:
            NSLog(@"Nal type is SPS");
            if (_sps) {
                free(_sps);
                _sps = NULL;
            }
            _spsSize = _packetSize - 4;
            _sps = malloc(_spsSize);
            memcpy(_sps, _packetBuffer + 4, _spsSize);
            break;
        case 0x08:
            NSLog(@"Nal type is PPS");
            if (_pps) {
                free(_pps);
                _pps = NULL;
            }
            _ppsSize = _packetSize - 4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, _packetBuffer + 4, _ppsSize);
            break;
        default:
            NSLog(@"Nal type is B/P frame");
            [self decode];
            break;
    }

    NSLog(@"Read Nalu size %ld", _packetSize);
    
}
- (void)decode
{
    CMBlockBufferRef blockBuffer = NULL;
    // 创建 CMBlockBufferRef
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(NULL, (void*)_packetBuffer, _packetSize, kCFAllocatorNull, NULL, 0, _packetSize, 0, &blockBuffer);
    if(status != kCMBlockBufferNoErr)
    {
        return;
    }
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {_packetSize};
    // 创建 CMSampleBufferRef
    status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, _formatDescription , 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
    if (status != kCMBlockBufferNoErr || sampleBuffer == NULL)
    {
        return;
    }
    // VTDecodeFrameFlags 0为允许多线程解码
    VTDecodeFrameFlags flags = 0;
    VTDecodeInfoFlags flagOut = 0;
    // 解码 这里第四个参数会传到解码的callback里的sourceFrameRefCon，可为空
    OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_decodeSession, sampleBuffer, flags, NULL, &flagOut);
    
    if(decodeStatus == kVTInvalidSessionErr)
    {
        NSLog(@"H264Decoder::Invalid session, reset decoder session");
    }
    else if(decodeStatus == kVTVideoDecoderBadDataErr)
    {
        NSLog(@"H264Decoder::decode failed status = %d(Bad data)", (int)decodeStatus);
    }
    else if(decodeStatus != noErr)
    {
        NSLog(@"H264Decoder::decode failed status = %d", (int)decodeStatus);
    }
    // Create了就得Release
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
}
- (void)readPacket {
    if (_packetSize && _packetBuffer) {
        _packetSize = 0;
        free(_packetBuffer);
        _packetBuffer = NULL;
    }
    if (_inputSize < _inputMaxSize && self.inputStream.hasBytesAvailable) {
        _inputSize += [self.inputStream read:_inputBuffer + _inputSize maxLength:_inputMaxSize - _inputSize];
    }
    if (memcmp(_inputBuffer, startCode, 4) == 0) {
        if (_inputSize > 4) {
            uint8_t *pStart = _inputBuffer + 4;
            uint8_t *pEnd = _inputBuffer + _inputSize;
            while (pStart != pEnd) {
                if(memcmp(pStart - 3, startCode, 4) == 0) {
                    _packetSize = pStart - _inputBuffer - 3;
                    if (_packetBuffer) {
                        free(_packetBuffer);
                        _packetBuffer = NULL;
                    }
                    _packetBuffer = calloc(_packetSize, 1);
                    memcpy(_packetBuffer, _inputBuffer, _packetSize); //复制packet内容到新的缓冲区
                    memmove(_inputBuffer, _inputBuffer + _packetSize, _inputSize - _packetSize); //把缓冲区前移
                    _inputSize -= _packetSize;
                    break;
                }
                else {
                    ++pStart;
                }
            }
        }
    }
}

static void decodeOutputDataCallback(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration)
{
    CVPixelBufferRetain(pixelBuffer);
    ViewController *vc = (__bridge ViewController *)decompressionOutputRefCon;
    [vc.playLayer inputPixelBuffer:pixelBuffer];
    CVPixelBufferRelease(pixelBuffer);

}


@end
