//
//  MyView.h
//  OpenGL-PlayYUV
//
//  Created by zhw on 2019/7/21.
//  Copyright © 2019 zhw. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenGlESView : UIView
//data只支持YUV420
- (void)renderWithData:(unsigned char *)data width:(int)width height:(int)height;
- (void)reset;
@end

NS_ASSUME_NONNULL_END
