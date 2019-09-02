//
//  OpenGLESView.m
//  BlurShaderDemo
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
    
    int _image_size;
    int _image_width;
    int _image_height;
    
    
    UIImage *renderbufferImage;
}
@end

@implementation OpenGLESView

+ (Class)layerClass
{
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
    
    _eaglLayer.opaque = YES;
    
    _eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: [NSNumber numberWithBool:YES], 
                                      kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
                                      };
}

- (void)setupContext
{
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

- (void)setupFrameAndRenderBuffer
{
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    
    glGenFramebuffers(1, &_frameBufferObject);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferObject);
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
        0.8f,  0.8f, 0.0f, 1.0f, 0.0f,   // 右上
        0.8f, -0.8f, 0.0f, 1.0f, 1.0f,   // 右下
        -0.8f, -0.8f, 0.0f, 0.0f, 1.0f,  // 左下
        -0.8f, -0.8f, 0.0f, 0.0f, 1.0f,  // 左下
        -0.8f,  0.8f, 0.0f, 0.0f, 0.0f,  // 左上
        0.8f,  0.8f, 0.0f, 1.0f, 0.0f,   // 右上
    };
    
    _vbo = createVBO(GL_ARRAY_BUFFER, GL_STATIC_DRAW, sizeof(vertices), vertices);
    
    glEnableVertexAttribArray(glGetAttribLocation(_program, "position"));
    glVertexAttribPointer(glGetAttribLocation(_program, "position"), 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*5, NULL);
    
    glEnableVertexAttribArray(glGetAttribLocation(_program, "texcoord"));
    glVertexAttribPointer(glGetAttribLocation(_program, "texcoord"), 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*5, NULL+sizeof(GL_FLOAT)*3);
    
}

- (void)setupTexure
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Grovont_Wyoming_US" ofType:@"jpg"];
    unsigned char *data;
    if (read_jpeg_file(path.UTF8String, &data, &_image_size, &_image_width, &_image_height) < 0) {
        printf("%s\n", "decode fail");
    }

    _texture = createTexture2D(GL_RGB, _image_width, _image_height, data);
    
#ifdef BLUR_SHADER
    glUniform1f(uniform_width, _image_width );
    glUniform1f(uniform_height, _image_height );
    glUniform1f(uniform_radius, 10.0); // 半徑幾pixel，會用一個 radius*2 + 1 的 box
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
    
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(glGetUniformLocation(_program, "image"), 0);
    
    glDrawArrays(GL_TRIANGLES, 0, _vertCount);
    
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
