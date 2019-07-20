//
//  MyView.m
//  OpenGL-GLKit-纹理
//
//  Created by zhw on 2019/7/20.
//  Copyright © 2019 zhw. All rights reserved.
//

#import "MyView.h"

@interface MyView()
@property (nonatomic, strong) GLKBaseEffect *effect;
@end

@implementation MyView
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setup];
    }
    return self;
}
- (void)setup
{
    //新建OpenGLES 上下文
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    self.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;  //颜色缓冲区格式
    [EAGLContext setCurrentContext:self.context];
    
    //顶点数据，前三个是顶点坐标（x、y、z轴），后面两个是纹理坐标（x，y）
    GLfloat vertexData[] =
    {
        0.5, -0.5, 0.0f,    1.0f, 0.0f, //右下
        0.5, 0.5,  0.0f,    1.0f, 1.0f, //右上
        -0.5, 0.5, 0.0f,    0.0f, 1.0f, //左上
        
        0.5, -0.5, 0.0f,    1.0f, 0.0f, //右下
        -0.5, 0.5, 0.0f,    0.0f, 1.0f, //左上
        -0.5, -0.5, 0.0f,   0.0f, 0.0f, //左下
    };
    
    //顶点数据缓存
    GLuint VBO;
    glGenBuffers(1, &VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertexData), vertexData, GL_STATIC_DRAW);
    
    //设置指针
    glEnableVertexAttribArray(GLKVertexAttribPosition);//顶点坐标
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (void*)0);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0); //纹理坐标
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (void*)(3 * sizeof(GLfloat)));
    
    //纹理贴图
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"duck" ofType:@"png"];
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:@(1), GLKTextureLoaderOriginBottomLeft, nil];//GLKTextureLoaderOriginBottomLeft 纹理坐标系是相反的
    GLKTextureInfo* textureInfo = [GLKTextureLoader textureWithContentsOfFile:filePath options:options error:nil];
    
    //着色器
    self.effect = [[GLKBaseEffect alloc] init];
    self.effect.texture2d0.enabled = GL_TRUE;
    self.effect.texture2d0.name = textureInfo.name;
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    glClearColor(0.3f, 0.6f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    //启动着色器
    [self.effect prepareToDraw];
    glDrawArrays(GL_TRIANGLES, 0, 6);
}
/**
 *  渲染场景代码
 */
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    
    glClearColor(0.3f, 0.6f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    //启动着色器
    [self.effect prepareToDraw];
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

@end
