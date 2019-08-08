//
//  AudioPlayer.h
//  FFmpegDemo
//
//  Created by zhw on 2019/7/23.
//  Copyright © 2019 zhw. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AudioPlayer;
@protocol AudioPlayerDelegate <NSObject>

- (void)audioPlayer:(AudioPlayer *)player data:(uint8_t *)data length:(int)length;

@end

@interface AudioPlayer : NSObject
@property (nonatomic, weak) id <AudioPlayerDelegate> delegate;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int channels;

- (void)prepare;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
