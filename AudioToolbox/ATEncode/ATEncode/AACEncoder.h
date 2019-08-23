//
//  AACEncoder.h
//  ATEncode
//
//  Created by zhw on 2019/8/23.
//  Copyright © 2019 zhw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>


NS_ASSUME_NONNULL_BEGIN

@interface AACEncoder : NSObject

@property (nonatomic) dispatch_queue_t encoderQueue;
@property (nonatomic) dispatch_queue_t callbackQueue;

- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer completionBlock:(void (^)(NSData *encodedData, NSError* error))completionBlock;

@end

NS_ASSUME_NONNULL_END
