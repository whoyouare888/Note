//
//  ViewController.m
//  VTEncode
//
//  Created by zhw on 2019/8/12.
//  Copyright © 2019 zhw. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
/*视频录制*/
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureOutput;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) AVCaptureConnection *captureConnection;

/*编码*/
@property (nonatomic, assign) VTCompressionSessionRef compressionSession;
@property (nonatomic, assign) int frameNum;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self initCaptureSession];
    [self initVideoToolBox];
}

- (void)initCaptureSession
{
    //初始化会话
    self.captureSession = [[AVCaptureSession alloc] init];
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
    
    //查找后置摄像头
    AVCaptureDevice *inputCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == AVCaptureDevicePositionBack)
        {
            inputCamera = device;
        }
    }
    //包装到AVCaptureDeviceInput
    NSError *error;
    self.deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:inputCamera error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    
    //输入设备添加到会话
    if ([self.captureSession canAddInput:self.deviceInput]) {
        [self.captureSession addInput:self.deviceInput];
    }
    
    //创建输出设备
    self.captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    //允许丢帧
    self.captureOutput.alwaysDiscardsLateVideoFrames = YES;
    
    //打印支持的像素格式
    NSArray *typeArray = [self.captureOutput availableVideoCVPixelFormatTypes];
    for (NSNumber *type in typeArray) {
        NSLog(@"**%c%c%c%c", (type.intValue >> 24), ((type.intValue & 0x00ff0000) >> 16), ((type.intValue & 0x0000ff00) >> 8), (type.intValue & 0x000000ff));
    }
    //设置输出的像素格式
    [self.captureOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];

    //设置输出串行队列和数据回调
    dispatch_queue_t outputQueue = dispatch_queue_create("CaptureQueue", DISPATCH_QUEUE_SERIAL);
    [self.captureOutput setSampleBufferDelegate:self queue:outputQueue];
    
    if ([self.captureSession canAddOutput:self.captureOutput]) {
        [self.captureSession addOutput:self.captureOutput];
    }
    
    //设置输出的视频方向
    self.captureConnection = [self.captureOutput connectionWithMediaType:AVMediaTypeVideo];
    [self.captureConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    if (inputCamera.position == AVCaptureDevicePositionFront && self.captureConnection.supportsVideoMirroring)
    {
        self.captureConnection.videoMirrored = YES;
    }
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    //设置实时预览的方向
    self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    [self.previewLayer setFrame:self.view.bounds];
    [self.view.layer addSublayer:self.previewLayer];
    
    //设置帧率
//    [self setupFrameRate:25];
    
    UIButton *startBtn = [[UIButton alloc] initWithFrame:CGRectMake(50, 100, 100, 50)];
    [startBtn setTitle:@"start" forState:UIControlStateNormal];
    [startBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [startBtn addTarget:self action:@selector(startClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startBtn];
    
    UIButton *toggleCamBtn = [[UIButton alloc] initWithFrame:CGRectMake(50, 200, 100, 50)];
    [toggleCamBtn setTitle:@"toggleCam" forState:UIControlStateNormal];
    [toggleCamBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [toggleCamBtn addTarget:self action:@selector(toggleClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:toggleCamBtn];
    
}
- (void)initVideoToolBox
{
    self.frameNum = 0;
    
    //宽高和视频采集的分辨率有关
    int width = 720, height = 1280;
    OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, encodeCallback, (__bridge void *)(self),  &_compressionSession);
    if (noErr != status)
    {
        NSLog(@"could not create CompressionSession");
        return;
    }
    
    // 设置实时编码输出（避免延迟）
    status = VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    if (status != noErr) {
        NSLog(@"set realtime fail");
        return;
    }

    //Baseline没有B帧，用于直播，减小延迟
    status = VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    if (status != noErr) {
        NSLog(@"set profile level fail");
        return;
    }
    
    // GOP size
    status = VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(15));
    if (status != noErr) {
        NSLog(@"set gop size fail");
        return;
    }
    
    // 设置期望帧率
    status = VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(25));
    if (status != noErr) {
        NSLog(@"set ExpectedFrameRate fail");
        return;
    }
    
    //配置是否产生B帧
    status = VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    if (noErr != status)
    {
        NSLog(@"set b frame allow fail");
        return;
    }
    
    //设置平均码率 单位 bit per second，3500Kbps
    int averageBitRate = 3500 * 1024;
    status = VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(averageBitRate));
    if (noErr != status)
    {
        NSLog(@"set AverageBitRate fail");
        return;
    }
    
    //参考webRTC 限制最大码率不超过平均码率的1.5倍，单位为byte per second
    int64_t dataLimitBytesPerSecondValue = averageBitRate * 1.5 / 8;
    CFNumberRef bytesPerSecond = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &dataLimitBytesPerSecondValue);
    int64_t oneSecondValue = 1;
    CFNumberRef oneSecond = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &oneSecondValue);
    const void* nums[2] = {bytesPerSecond, oneSecond};
    CFArrayRef dataRateLimits = CFArrayCreate(NULL, nums, 2, &kCFTypeArrayCallBacks);
    status = VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_DataRateLimits, dataRateLimits);
    if (noErr != status)
    {
        NSLog(@"set DataRateLimits fail");
        return;
    }
    
    //准备编码
    VTCompressionSessionPrepareToEncodeFrames(self.compressionSession);
    
    //编码后，写入h264文件中
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"result.h264"];
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];

}

- (void)setupFrameRate:(int)frameRate
{
    AVFrameRateRange *frameRateRange = [self.deviceInput.device.activeFormat.videoSupportedFrameRateRanges objectAtIndex:0];
    if (frameRate > frameRateRange.maxFrameRate || frameRate < frameRateRange.minFrameRate)
    {
        NSLog(@"帧率超过范围");
        return ;
    }

    NSError *error;
    [self.deviceInput.device lockForConfiguration:&error];
    self.deviceInput.device.activeVideoMinFrameDuration = CMTimeMake(1, frameRate);
    self.deviceInput.device.activeVideoMaxFrameDuration = CMTimeMake(1, frameRate);
    [self.deviceInput.device unlockForConfiguration];
}

- (void)startClick:(UIButton *)sender {
    if (!self.captureSession || !self.captureSession.running) {
        [sender setTitle:@"stop" forState:UIControlStateNormal];
        [self startCapture];
        
    }
    else {
        [sender setTitle:@"start" forState:UIControlStateNormal];
        sender.hidden = YES;
        [self stopCapture];
        
    }
}

- (void)toggleClick:(UIButton *)btn
{
    if (!self.captureSession || !self.captureSession.running) {
        return;
    }

    AVCaptureDevicePosition currentPosition = self.deviceInput.device.position;
    AVCaptureDevicePosition toPosition;
    if (currentPosition == AVCaptureDevicePositionBack)
    {
        toPosition = AVCaptureDevicePositionFront;
    }
    else
    {
        toPosition = AVCaptureDevicePositionBack;
    }
    
    //获取摄像头
    AVCaptureDevice *inputCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == toPosition)
        {
            inputCamera = device;
        }
    }
    
    if (inputCamera == nil) {
        return;
    }
    
    //开始配置
    NSError *error;
    [self.captureSession beginConfiguration];
    AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:inputCamera error:&error];
    [self.captureSession removeInput:self.deviceInput];
    if ([self.captureSession canAddInput:newInput])
    {
        [self.captureSession  addInput:newInput];
        self.deviceInput = newInput;
    }
    [self.captureSession commitConfiguration];
    
    //重新获取连接并设置视频的方向、是否镜像
    self.captureConnection = [self.captureOutput connectionWithMediaType:AVMediaTypeVideo];
    self.captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    if (inputCamera.position == AVCaptureDevicePositionFront && self.captureConnection.supportsVideoMirroring)
    {
        self.captureConnection.videoMirrored = YES;
    }
}

- (void)startCapture
{
    // 摄像头权限判断
    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (videoAuthStatus != AVAuthorizationStatusAuthorized)
    {
        NSLog(@"摄像头权限没开");
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.captureSession startRunning];
    });
}
- (void)stopCapture
{
    [self.captureSession stopRunning];
    [self.previewLayer removeFromSuperlayer];
    [self endVideoToolBox];
    [self.fileHandle closeFile];
    self.fileHandle = NULL;
}

- (void)endVideoToolBox
{
    VTCompressionSessionCompleteFrames(self.compressionSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(self.compressionSession);
    CFRelease(self.compressionSession);
    self.compressionSession = NULL;
}

#pragma mark -
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    //设置编码时间戳
    CMTime pts = CMTimeMake(self.frameNum++, 25);
    OSStatus status = VTCompressionSessionEncodeFrame(self.compressionSession,
                                                          imageBuffer,
                                                          pts,
                                                          kCMTimeInvalid,
                                                          NULL, NULL, NULL);
    if (status != noErr) {
        NSLog(@"Encode failed");
        VTCompressionSessionInvalidate(self.compressionSession);
        CFRelease(self.compressionSession);
        self.compressionSession = NULL;
        return;
    }
    NSLog(@"EncodeFrame Success");

}
void encodeCallback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer)
{
    NSLog(@"encodeCallback");
    if (status != noErr) {
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        return;
    }
    
    if (infoFlags & kVTEncodeInfo_FrameDropped)
    {
        NSLog(@"---encode dropped frame");
        return;
    }
    
    ViewController *encoder = (__bridge ViewController *)outputCallbackRefCon;

    const char header[] = "\x00\x00\x00\x01";
    size_t headerLen = 4;  //4字节的0x00000001分隔码
    NSData *headerData = [NSData dataWithBytes:header length:headerLen];
    
    // 判断是否是关键帧
    bool isKeyFrame = !CFDictionaryContainsKey((CFDictionaryRef)CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), (const void *)kCMSampleAttachmentKey_NotSync);
    // 获取sps & pps数据
    if (isKeyFrame)
    {
        NSLog(@"编码了一个关键帧");
        CMFormatDescriptionRef formatDescriptionRef = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // 关键帧需要加上SPS、PPS信息
        size_t sParameterSetSize, sParameterSetCount;
        const uint8_t *sParameterSet;
        OSStatus spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescriptionRef, 0, &sParameterSet, &sParameterSetSize, &sParameterSetCount, 0);
        
        size_t pParameterSetSize, pParameterSetCount;
        const uint8_t *pParameterSet;
        OSStatus ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescriptionRef, 1, &pParameterSet, &pParameterSetSize, &pParameterSetCount, 0);
        
        if (noErr == spsStatus && noErr == ppsStatus)
        {
            NSData *sps = [NSData dataWithBytes:sParameterSet length:sParameterSetSize];
            NSData *pps = [NSData dataWithBytes:pParameterSet length:pParameterSetSize];
            
            [encoder.fileHandle writeData:headerData];
            [encoder.fileHandle writeData:sps];
            [encoder.fileHandle writeData:headerData];
            [encoder.fileHandle writeData:pps];
         
        }

    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            // Read the NAL unit length
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder.fileHandle writeData:headerData];
            [encoder.fileHandle writeData:data];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

@end
