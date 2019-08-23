//
//  ViewController.m
//  ATEncode
//
//  Created by zhw on 2019/8/23.
//  Copyright © 2019 zhw. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AACEncoder.h"

@interface ViewController ()<AVCaptureAudioDataOutputSampleBufferDelegate>
@property (nonatomic , strong) AVCaptureSession *mCaptureSession; //负责输入和输出设备之间的数据传递
@property (nonatomic , strong) AVCaptureDeviceInput *mCaptureAudioDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (nonatomic , strong) AVCaptureAudioDataOutput *mCaptureAudioOutput;
@property (nonatomic , strong) AACEncoder *mAudioEncoder;

@end

@implementation ViewController
{
    NSFileHandle *audioFileHandle;
    dispatch_queue_t mCaptureQueue;

}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(20, 20, 100, 100)];
    [button setTitle:@"play" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
    [button addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
    
    self.mAudioEncoder = [[AACEncoder alloc] init];

}

- (void)onClick:(UIButton *)button {
    if (!self.mCaptureSession || !self.mCaptureSession.running) {
        [button setTitle:@"stop" forState:UIControlStateNormal];
        [self startCapture];
        
    }
    else {
        [button setTitle:@"play" forState:UIControlStateNormal];
        [self stopCapture];
        
    }
}


- (void)startCapture {
    self.mCaptureSession = [[AVCaptureSession alloc] init];
    
    mCaptureQueue = dispatch_queue_create("capture queue", DISPATCH_QUEUE_SERIAL);
    
    AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] lastObject];
    self.mCaptureAudioDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:nil];
    if ([self.mCaptureSession canAddInput:self.mCaptureAudioDeviceInput]) {
        [self.mCaptureSession addInput:self.mCaptureAudioDeviceInput];
    }
    self.mCaptureAudioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    if ([self.mCaptureSession canAddOutput:self.mCaptureAudioOutput]) {
        [self.mCaptureSession addOutput:self.mCaptureAudioOutput];
    }
    [self.mCaptureAudioOutput setSampleBufferDelegate:self queue:mCaptureQueue];
    
    
    NSString *audioFile = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"result.aac"];
    [[NSFileManager defaultManager] removeItemAtPath:audioFile error:nil];
    [[NSFileManager defaultManager] createFileAtPath:audioFile contents:nil attributes:nil];
    audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:audioFile];
    
    [self.mCaptureSession startRunning];
}
- (void)stopCapture {
    [self.mCaptureSession stopRunning];
    [audioFileHandle closeFile];
    audioFileHandle = NULL;
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    [self.mAudioEncoder encodeSampleBuffer:sampleBuffer completionBlock:^(NSData *encodedData, NSError *error) {
        [self->audioFileHandle writeData:encodedData];
    }];

}


@end
