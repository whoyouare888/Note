//
//  ViewController.m
//  FFmpegDemo
//
//  Created by zhw on 2018/8/7.
//  Copyright © 2018年 zhw. All rights reserved.
//

#import "ViewController.h"
#import "MyView.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>



@implementation ViewController
{
    __weak IBOutlet MyView *_myView;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    myView = _myView;
    
    [NSThread detachNewThreadWithBlock:^{
        demux_decode();

    }];
    
}


static MyView *myView;
static const char *src_filename = "/Users/zhw/Desktop/resource/out.mp4";

static AVFormatContext *fmt_ctx = NULL;
static AVCodecContext *video_dec_ctx = NULL, *audio_dec_ctx = NULL;
static AVStream *video_stream = NULL;
static int video_stream_idx = -1;
static int width, height;
static enum AVPixelFormat src_pix_fmt;
static AVFrame *frame = NULL;
static AVPacket pkt;

static uint8_t *video_dst_data[4] = {NULL};
static int video_dst_linesize[4];
static int video_dst_bufsize;

struct SwsContext *sws_ctx;




static void demux_decode(void)
{
    int ret = 0;
    
    /* 打开文件，创建AVFormatContext */
    if (avformat_open_input(&fmt_ctx, src_filename, NULL, NULL) < 0) {
        printf("Could not open source file %s\n", src_filename);
        goto end;
    }
    
    /* 查找流信息 */
    if (avformat_find_stream_info(fmt_ctx, NULL) < 0) {
        printf("Could not find stream information\n");
        goto end;
    }
    
    //打开视频解码器
    if (open_codec_context(&video_stream_idx, &video_dec_ctx, fmt_ctx, AVMEDIA_TYPE_VIDEO) >= 0) {
        //视频流
        video_stream = fmt_ctx->streams[video_stream_idx];
        
        //创建image,用于存储无对齐的image、转换后的image
        width = video_dec_ctx->width;
        height = video_dec_ctx->height;
        src_pix_fmt = video_dec_ctx->pix_fmt;
        ret = av_image_alloc(video_dst_data, video_dst_linesize, width, height, AV_PIX_FMT_YUV420P, 1);
        if (ret < 0) {
            printf("Could not allocate raw video buffer\n");
            goto end;
        }
        video_dst_bufsize = ret;
        
        //如果不是YUV420P格式，需要进行转换
        if (src_pix_fmt != AV_PIX_FMT_YUV420P) {
            /* create scaling context */
            sws_ctx = sws_getContext(width, height, src_pix_fmt,
                                     width, height, AV_PIX_FMT_YUV420P,
                                     SWS_BILINEAR, NULL, NULL, NULL);
            if (!sws_ctx) {
                fprintf(stderr,
                        "Impossible to create scale context for the conversion "
                        "fmt:%s s:%dx%d -> fmt:%s s:%dx%d\n",
                        av_get_pix_fmt_name(src_pix_fmt), width, height,
                        av_get_pix_fmt_name(AV_PIX_FMT_YUV420P), width, height);
                goto end;
            }
        }
    }
    
    //打印信息
    av_dump_format(fmt_ctx, 0, src_filename, 0);
    
    if (!video_stream) {
        printf("Could not find video stream in the input, aborting\n");
        goto end;
    }
    
    frame = av_frame_alloc();
    if (!frame) {
        printf("Could not allocate frame\n");
        goto end;
    }
    
    av_init_packet(&pkt);
    pkt.data = NULL;
    pkt.size = 0;
    
    //从文件读取数据
    while (av_read_frame(fmt_ctx, &pkt) >= 0) {
        
        decode_packet(0);
        
        av_packet_unref(&pkt);
    }
    
    /* flush cached frames
     将pkt.data置为null，并且pkt.size设为0,然后送给解码器解码，会将解码器缓存的数据解码出来。
     */
    pkt.data = NULL;
    pkt.size = 0;
    decode_packet(1);
  
    
end:
    avcodec_free_context(&video_dec_ctx);
    avcodec_free_context(&audio_dec_ctx);
    avformat_close_input(&fmt_ctx);
    av_frame_free(&frame);
    av_free(video_dst_data[0]);
    
    
}
static int open_codec_context(int *stream_idx, AVCodecContext **dec_ctx, AVFormatContext *fmt_ctx, enum AVMediaType type)
{
    int ret, stream_index;
    AVStream *st;
    AVCodec *dec = NULL;
    
    //寻找type类型的流，返回流的index
    ret = av_find_best_stream(fmt_ctx, type, -1, -1, NULL, 0);
    if (ret < 0) {
        printf("Could not find %s stream\n", av_get_media_type_string(type));
        return ret;
    }
    stream_index = ret;
    //获取流
    st = fmt_ctx->streams[stream_index];
    
    //寻找解码器
    dec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!dec) {
        printf("failed to find %s codec\n", av_get_media_type_string(type));
        return AVERROR(EINVAL);
    }
    
    //为解码器创建上下文
    *dec_ctx = avcodec_alloc_context3(dec);
    if (!*dec_ctx) {
        printf("failed to alloc %s codec context\n", av_get_media_type_string(type));
        return AVERROR(ENOMEM);
    }
    
    //把流中的解码参数复制到解码器的AVCodecContext中
    ret = avcodec_parameters_to_context(*dec_ctx, st->codecpar);
    if (ret < 0) {
        printf("failed to copy %s codec params to decoder context\n", av_get_media_type_string(type));
        return ret;
    }
    
    //打开解码器
    ret = avcodec_open2(*dec_ctx, dec, NULL);
    if (ret < 0) {
        printf("failed to open %s codec\n", av_get_media_type_string(type));
        return ret;
    }
    
    //返回流的index
    *stream_idx = stream_index;
    
    return 0;
}
static void decode_packet(int cached)
{
    int ret = 0;
    
    if (pkt.stream_index == video_stream_idx) {
        //解码视频
        ret = avcodec_send_packet(video_dec_ctx, &pkt);
        if (ret < 0) {
            printf("error video send_packet\n");
            return;
        }
        
        while ((ret = avcodec_receive_frame(video_dec_ctx, frame)) == 0) {
            if (frame->width != width || frame->height != height || frame->format != src_pix_fmt) {
                printf("Error: Width, height and pixel format have to be "
                       "constant in a rawvideo file, but the width, height or "
                       "pixel format of the input video changed");
                return;
            }
            
            if (src_pix_fmt != AV_PIX_FMT_YUV420P) {
                //转换格式
                sws_scale(sws_ctx, (const uint8_t **)frame->data,
                          frame->linesize, 0, height, video_dst_data, video_dst_linesize);

            }else {
                //复制解码后的视频到之前创建的缓存区
                av_image_copy(video_dst_data, video_dst_linesize, (const uint8_t **)frame->data, frame->linesize, src_pix_fmt, width, height);
            }
            
            av_frame_unref(frame);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [myView renderWithData:video_dst_data[0] width:width height:height];
                NSLog(@"---");
            });
            
            [NSThread sleepForTimeInterval:0.04];

        }
        
    }
}


@end
