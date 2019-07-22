//
//  MyView.m
//  OpenGL-PlayYUV
//
//  Created by zhw on 2019/7/21.
//  Copyright © 2019 zhw. All rights reserved.
//

#import "MyView.h"
#import <OpenGLES/ES2/gl.h>

@implementation MyView
{
    EAGLContext *_eaglContext;
    CAEAGLLayer *_eaglLayer;
    GLuint _colorBufferRender;
    GLuint _frameBuffer;
    GLuint _program;
    NSTimer *_timer;
    FILE *_in_file;
    int _width;
    int _height;
    uint8_t *_yuv;
    GLuint _texture_y;
    GLuint _texture_u;
    GLuint _texture_v;
}
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setup];
        [self setupRender];
        [self setupTexture];

    }
    return self;
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)setup
{
    //设置放大倍数
    [self setContentScaleFactor:[[UIScreen mainScreen] scale]];
    
    //设置context
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:_eaglContext];
    
    //设置层
    _eaglLayer = (CAEAGLLayer*)self.layer;
    _eaglLayer.opaque = YES;
    _eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],
                                     kEAGLDrawablePropertyRetainedBacking,
                                     kEAGLColorFormatRGBA8,
                                     kEAGLDrawablePropertyColorFormat, nil];

    
    //设置buffer
    glGenRenderbuffers(1, &_colorBufferRender);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferRender);
    [_eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER,
                              _colorBufferRender);

}

- (void)setupRender
{
    //设置视口大小
    CGFloat scale = [UIScreen mainScreen].scale;
    glViewport(0, 0, self.frame.size.width * scale, self.frame.size.height * scale);

    //前三个是顶点坐标，后面两个是纹理坐标
//    GLfloat vertices[] = {
//        -1.0f, -1.0f, 0.0f,     0.0f, 0.0f,
//        1.0f , -1.0f, 0.0f,     1.0f, 0.0f,
//        -1.0f,  1.0f, 0.0f,     0.0f, 1.0f,
//        1.0f ,  1.0f, 0.0f,     1.0f, 1.0f
//    };
    
    //颠倒纹理坐标，图像才能是正确的上下顺序
    GLfloat vertices[] = {
        -1.0f, -1.0f, 0.0f,     0.0f, 1.0f,
        1.0f , -1.0f, 0.0f,     1.0f, 1.0f,
        -1.0f,  1.0f, 0.0f,     0.0f, 0.0f,
        1.0f ,  1.0f, 0.0f,     1.0f, 0.0f
    };
    
    GLuint indices[] = {
        0, 1, 2,
        1, 2, 3
    };
    
    _program = [self compileShaders:@"vertex.vsh" shaderFragment:@"fragment.fsh"];
    glUseProgram(_program);
    
    GLuint VBO;
    glGenBuffers(1, &VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW);
    
    GLuint EBO;
    glGenBuffers(1, &EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    GLuint position = glGetAttribLocation(_program, "position");
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (void *)0);
    glEnableVertexAttribArray(position);
    
    GLuint textCoor = glGetAttribLocation(_program, "textCoordinate");
    glVertexAttribPointer(textCoor, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (void *)(sizeof(GLfloat) * 3));
    glEnableVertexAttribArray(textCoor);
}

- (void)setupTexture
{
    
    glGenTextures(1, &_texture_y);
    glBindTexture(GL_TEXTURE_2D, _texture_y);
    
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glGenTextures(1, &_texture_u);
    glBindTexture(GL_TEXTURE_2D, _texture_u);
    
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glGenTextures(1, &_texture_v);
    glBindTexture(GL_TEXTURE_2D, _texture_v);
    
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    //设置纹理单元
    glUniform1i(glGetUniformLocation(_program, "texture_y"), 0);
    glUniform1i(glGetUniformLocation(_program, "texture_u"), 1);
    glUniform1i(glGetUniformLocation(_program, "texture_v"), 2);

    
    const char *in_filename = [[[NSBundle mainBundle] pathForResource:@"sintel_yuv420p_848x480.yuv" ofType:nil] UTF8String];
    _in_file = fopen(in_filename, "rb");
    if (!_in_file) {
        NSLog(@"open file %s failed", in_filename);
        exit(1);
    }
    
    _width = 848;
    _height = 480;
    
    _yuv = calloc(_width * _height * 3 / 2, 1);
    if (!_yuv) {
        NSLog(@"calloc failed");
        exit(1);
    }
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 25) target:self selector:@selector(renderCycle) userInfo:nil repeats:YES];
}

- (void)renderCycle
{
    if (feof(_in_file)) {
        [_timer invalidate];
        _timer = nil;
        return;
    }
    
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    //清空
    memset(_yuv, 0, _width * _height * 3 / 2);
    
    //读取Y、U、V
    unsigned long count = fread(_yuv, 1, _width * _height * 3 / 2, _in_file);
    if (count < _width * _height * 3 / 2) {
        [_timer invalidate];
        _timer = nil;
        return;
    }
    
    //y
    glBindTexture(GL_TEXTURE_2D, _texture_y);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, _width, _height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, _yuv);
    
    //u
    glBindTexture(GL_TEXTURE_2D, _texture_u);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, _width / 2, _height / 2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, _yuv + _width * _height);
    
    //v
    glBindTexture(GL_TEXTURE_2D, _texture_v);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, _width / 2, _height / 2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, _yuv + _width * _height * 5 / 4);
    
    //激活、绑定纹理
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture_y);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _texture_u);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, _texture_v);
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    
    [_eaglContext presentRenderbuffer:GL_RENDERBUFFER];


}



- (GLuint)compileShaders:(NSString *)shaderVertex shaderFragment:(NSString *)shaderFragment {
    // 1 vertex和fragment两个shader都要编译
    GLuint vertexShader = [self compileShader:shaderVertex withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:shaderFragment withType:GL_FRAGMENT_SHADER];
    
    // 2 连接vertex和fragment shader成一个完整的program
    GLuint glProgram = glCreateProgram();
    glAttachShader(glProgram, vertexShader);
    glAttachShader(glProgram, fragmentShader);
    
    // link program
    glLinkProgram(glProgram);
    
    // 3 check link status
    GLint linkSuccess;
    glGetProgramiv(glProgram, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(glProgram, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    
    return glProgram;
}

- (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType {
    // 1 查找shader文件
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:nil];
    NSError* error;
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    // 2 创建一个代表shader的OpenGL对象, 指定vertex或fragment shader
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // 3 获取shader的source
    const char* shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    // 4 编译shader
    glCompileShader(shaderHandle);
    
    // 5 查询shader对象的信息
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shaderHandle;
}


@end
