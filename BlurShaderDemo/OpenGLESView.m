//
//  OpenGLESView.m
//  OpenGLES01-环境搭建
//
//  Created by GevinChen on 2017/2/9.
//  Copyright © 2019年 GevinChen. All rights reserved.
//

#import "OpenGLESView.h"
#import <OpenGLES/ES2/gl.h>
#import "GLUtil.h"
#include "JpegUtil.h"

@interface OpenGLESView ()
{
    CAEAGLLayer     *_eaglLayer;
    EAGLContext     *_context;
    GLuint          _colorRenderBuffer;
    GLuint          _frameBufferObject;

    GLuint          _program;
    GLuint          _vbo;
    GLuint          _texture;
    int             _vertCount;
    GLuint          fboId;
    
    GLuint uniform_width; 
    GLuint uniform_height;
    GLuint uniform_radius;
    GLuint uniform_quality;
    GLuint uniform_directions;
    
    int _image_size;
    int _image_width;
    int _image_height;
    
    
    UIImage *renderbufferImage;
}
@end

@implementation OpenGLESView

+ (Class)layerClass
{
    // 只有 [CAEAGLLayer class] 类型的 layer 才支持在其上描绘 OpenGL 内容。
    return [CAEAGLLayer class];
}

- (void)dealloc
{
    glDeleteBuffers(1, &_vbo);
    glDeleteTextures(1, &_texture);
    glDeleteProgram(_program);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setupLayer];
        [self setupContext];
        [self setupGLProgram];
        [self setupVBO];
        [self setupTexure];
    }
    return self;
}

- (void)layoutSubviews
{
    [EAGLContext setCurrentContext:_context];
    
    [self destoryRenderAndFrameBuffer];
    
    [self setupFrameAndRenderBuffer];
    
    [self render];
}


#pragma mark - Setup
- (void)setupLayer
{
    _eaglLayer = (CAEAGLLayer*) self.layer;
    
    // CALayer 默认是透明的，必须将它设为不透明才能让其可见
    _eaglLayer.opaque = YES;
    
    // 设置描绘属性，在这里设置不维持渲染内容以及颜色格式为 RGBA8
    // 注意：如果要用 glReadPixels 的話，kEAGLDrawablePropertyRetainedBacking 要設成 YES
    // 設成 NO 的話， render buffer 的內容在 presentRenderbuffer 之後就會被清空，你再執行 glReadPixel 也讀不到東西
    _eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: [NSNumber numberWithBool:YES], 
                                      kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
                                      };
}

- (void)setupContext
{
    // 设置OpenGLES的版本为2.0 当然还可以选择1.0和最新的3.0的版本，以后我们会讲到2.0与3.0的差异，目前为了兼容性选择2.0的版本
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    // 将当前上下文设置为我们创建的上下文
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

- (void)setupFrameAndRenderBuffer
{

    // 建立一個 render buffer，將其作為 color buffer
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    // 为 color renderbuffer 分配存储空间
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    
    glGenFramebuffers(1, &_frameBufferObject);
    // 设置为当前 framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferObject);
    // 将 _colorRenderBuffer 装配到 GL_COLOR_ATTACHMENT0 这个装配点上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _colorRenderBuffer);
}
    
#define BLUR_SHADER

- (void)setupGLProgram
{
#ifdef BLUR_SHADER
    NSString *vertFile = [[NSBundle mainBundle] pathForResource:@"blurVert.glsl" ofType:nil];
    NSString *fragFile = [[NSBundle mainBundle] pathForResource:@"blurFrag.glsl" ofType:nil];
#else
    NSString *vertFile = [[NSBundle mainBundle] pathForResource:@"vert.glsl" ofType:nil];
    NSString *fragFile = [[NSBundle mainBundle] pathForResource:@"frag.glsl" ofType:nil];    
#endif
    _program = createGLProgramFromFile(vertFile.UTF8String, fragFile.UTF8String);

#ifdef BLUR_SHADER
    uniform_width = glGetUniformLocation(_program, "textureWidth");
    uniform_height = glGetUniformLocation(_program, "textureHeight");
    uniform_radius = glGetUniformLocation(_program, "radius");
    uniform_quality = glGetUniformLocation(_program, "quality");
    uniform_directions = glGetUniformLocation(_program, "directions");
#endif
    
    glUseProgram(_program);
    
    
}

- (void)setupVBO
{
    _vertCount = 6;
    
//    GLfloat vertices[] = {
//        0.5f,  0.5f, 0.0f, 1.0f, 1.0f,   // 右上
//        0.5f, -0.5f, 0.0f, 1.0f, 0.0f,   // 右下
//        -0.5f, -0.5f, 0.0f, 0.0f, 0.0f,  // 左下
//        -0.5f,  0.5f, 0.0f, 0.0f, 1.0f   // 左上
//    };
    
    GLfloat vertices[] = {
        0.5f,  0.5f, 0.0f, 1.0f, 0.0f,   // 右上
        0.5f, -0.5f, 0.0f, 1.0f, 1.0f,   // 右下
        -0.5f, -0.5f, 0.0f, 0.0f, 1.0f,  // 左下
        -0.5f, -0.5f, 0.0f, 0.0f, 1.0f,  // 左下
        -0.5f,  0.5f, 0.0f, 0.0f, 0.0f,  // 左上
        0.5f,  0.5f, 0.0f, 1.0f, 0.0f,   // 右上
    };
    
    // 创建VBO
    _vbo = createVBO(GL_ARRAY_BUFFER, GL_STATIC_DRAW, sizeof(vertices), vertices);
    
    glEnableVertexAttribArray(glGetAttribLocation(_program, "position"));
    glVertexAttribPointer(glGetAttribLocation(_program, "position"), 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*5, NULL);
    
    glEnableVertexAttribArray(glGetAttribLocation(_program, "texcoord"));
    glVertexAttribPointer(glGetAttribLocation(_program, "texcoord"), 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*5, NULL+sizeof(GL_FLOAT)*3);
    
}

- (void)setupTexure
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"wood" ofType:@"jpg"];
    
    unsigned char *data;
    
    
    // 加载纹理
    if (read_jpeg_file(path.UTF8String, &data, &_image_size, &_image_width, &_image_height) < 0) {
        printf("%s\n", "decode fail");
    }
    
    // 创建纹理
    _texture = createTexture2D(GL_RGB, _image_width, _image_height, data);
    
#ifdef BLUR_SHADER
    glUniform1f(uniform_width, _image_width );
    glUniform1f(uniform_height, _image_height );
    glUniform1f(uniform_radius, 30.0); // 半徑幾pixel
    glUniform1f(uniform_quality, 10.0); // 半徑切幾等份
    glUniform1f(uniform_directions, 18.0); // 圓切幾等份
#endif
    
    if (data) {
        free(data);
        data = NULL;
    }
}

#pragma mark - Clean
- (void)destoryRenderAndFrameBuffer
{
    glDeleteFramebuffers(1, &_frameBufferObject);
    _frameBufferObject = 0;
    glDeleteRenderbuffers(1, &_colorRenderBuffer);
    _colorRenderBuffer = 0;
}

#pragma mark - Render
- (void)render
{
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    //glLineWidth(2.0);
    
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    
    // 激活纹理
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(glGetUniformLocation(_program, "image"), 0);
    
    glDrawArrays(GL_TRIANGLES, 0, _vertCount);
    
    // 索引数组
    //unsigned int indices[] = {0,1,2,3,2,0};
    //glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, indices);
    
    //将指定 renderbuffer 呈现在屏幕上，在这里我们指定的是前面已经绑定为当前 renderbuffer 的那个，在 renderbuffer 可以被呈现之前，必须调用renderbufferStorage:fromDrawable: 为之分配存储空间。
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - read pixel 

/**
 
 默认情况下，当你把renderbuffer里的内容呈现到屏幕上后，renderbuffer里的内容就失效了。因此，要读取openGL ES 准确的内容，你必须按照一下做法的一种：
 
 1）你必须在调用EAGLContext / -presentRenderbuffer: 之前调用 glReaderPiexels
 
 2）设置的CAEAGLLayer的retain属性设置为true，保留该层的内容。但是，这可能有不良反应性能的影响，所以你注意，只在必要时使用此这种方法。
 
 */
- (UIImage*)readPixel
{
    //After render to the FBO 
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferObject);
//    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    
    GLint width;
    GLint height;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);

    int pixelLength = width * height * 4;
    GLubyte* pixels = (GLubyte*) malloc(pixelLength);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels); // 會讀 render buffer 裡的資料
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, pixelLength, NULL);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaLast; // 含 alpha channel
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    int bitsPerComponent = 8;
    int bitsPerPixel = 8 * 4;
    int bytesPerRow = 4 * width;
    
    CGImageRef imageRef = CGImageCreate(width, 
                                        height, 
                                        bitsPerComponent,
                                        bitsPerPixel,
                                        bytesPerRow,
                                        colorSpaceRef, 
                                        bitmapInfo,
                                        provider, 
                                        NULL, 
                                        NO,
                                        renderingIntent);
    
    //----------------------
    // #way 1 (not work)
//    UIImage *image = [UIImage imageWithCGImage:imageRef];
    
    //----------------------
    // #way 2 (work)
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
    CGContextRef cgcontext = UIGraphicsGetCurrentContext();
    // UIKit coordinate system is upside down to GL/Quartz coordinate system
    // Flip the CGImage by rendering it to the flipped bitmap context
    // The size of the destination area is measured in POINTS
    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
    CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, width, height), imageRef);
    // Retrieve the UIImage from the current context
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    CGImageRelease(imageRef); 
    CGDataProviderRelease(provider); 
    CGColorSpaceRelease(colorSpaceRef); 
    free(pixels);
    
    return image;
    
}

- (UIImage*)getImage{
    return renderbufferImage;
}

@end
