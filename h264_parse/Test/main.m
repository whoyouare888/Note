//
//  main.m
//  Test
//
//  Created by zhw on 2019/6/28.
//  Copyright © 2019 zhw. All rights reserved.
//

#import <Foundation/Foundation.h>

void h264_parser(const char *url);

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        const char *path = "/Users/zhw/Desktop/Test/Test/sintel.h264";
        h264_parser(path);
    }
    return 0;
}

void h264_parser(const char *url)
{
    
    const int buffer_size = 100000;
    
    FILE *h264_stream = fopen(url, "rb+");
    if (h264_stream == NULL) {
        printf("open file error\n");
        return;
    }
    
    char buffer[buffer_size] = {0};
    char *ptr = buffer;
    
    while (!feof(h264_stream)) {

        if (ptr != buffer) {
            //待拷贝数目
            long count = buffer + (buffer_size - 1) - ptr + 1;

            char tmp[count];
            for (int i = 0; i < count; i++) {
                tmp[i] = ptr[i];
            }
            memset(buffer, 0, buffer_size);
            for (int i = 0; i < count; i++) {
                buffer[i] = tmp[i];
            }
            ptr = buffer + count;
            
            unsigned long real_count = fread(ptr, 1, buffer_size - count, h264_stream);
            printf("------real count %ld, end %d\n", real_count, feof(h264_stream));


        }else {
            unsigned long real_count = fread(buffer, 1, buffer_size, h264_stream);
            printf("------real count %ld, end %d\n", real_count, feof(h264_stream));

        }
        
        ptr = buffer;
        
        //ptr指针距离buffer结尾至少有5个字节
        while (ptr + 4 <= buffer + (buffer_size - 1)) {
            int found = 0;
            if (ptr[0] == 0 && ptr[1] == 0 && ptr[2] == 1) {    //寻找0x000001
                found = 1;
                ptr += 3;
            }else if (ptr[0] == 0 && ptr[1] == 0 && ptr[2] == 0 && ptr[3] == 1) {   //寻找0x00000001
                found = 1;
                ptr += 4;
            }else {
                ptr += 1;
            }
            
            if (found) {
                char forbidden_bit = (ptr[0] & 0x80) >> 7; //取最高1位
                char nal_reference_idc = (ptr[0] & 0x60) >> 5; //取2位
                char nal_unit_type = ptr[0] & 0x1f; //取最后5位
                
                printf("forbidden_bit %d, nal_reference_idc %d, nal_unit_type %d \n", forbidden_bit, nal_reference_idc, nal_unit_type);
            }
        }

        
    }
    
}

