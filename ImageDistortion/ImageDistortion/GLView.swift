//
//  GLView.swift
//  
//
//  Created by GevinChen on 2019/8/18.
//  Copyright © 2019 GevinChen. All rights reserved.
//

import UIKit
import CoreVideo
import AVFoundation
import VideoToolbox
import QuartzCore

@objc class GLView: UIView {
    
    private var eaglLayer:CAEAGLLayer?
    private var eaglContext: EAGLContext?
    //@objc var framebufferSize: CGSize = CGSize.zero
    private var _displayLink: CADisplayLink?
    
    private var _framebuffer:GLuint = 0
    private var _colorRenderBuffer:GLuint = 0
    
    // vbo
    private var _vao: GLuint = 0
    private var _vbo: GLuint = 0
    private var _ebo: GLuint = 0
//    private var _vertices: [GLfloat] = []
//    private var _texCoords: [GLfloat] = []
//    private var _indicaties: [ushort] = []
    private var _indicateSize: Int = 0
    private var _angle: Float = 0
    
    // texture
    private var _texture: GLuint = 0
    private var _textureSize: CGSize = CGSize.zero
    
    private var _program: GLProgram?
    
    // shader variable id
    private var _uniform_texture: GLint = 0
    private var _attr_textureCoord: GLint = 0
    private var _attr_squareVertices: GLint = 0
    
    deinit {
        print("OpenGLESHandler dealloc")
    }
    
    override class var layerClass: AnyClass {
        get {
            return CAEAGLLayer.self
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        
        
    }
    
    @objc
    func setupGL() {
        
        self.setupGLContext()
        
        self.setupRenderFramebuffer()
        
        self.setupProgram()

        self.setupTexture()
        
        self.setupVAO()
        
        self.setupInput()

    }

    private func setupGLContext() {
        
        eaglLayer = self.layer as? CAEAGLLayer
        eaglLayer?.isOpaque = true
        eaglLayer?.drawableProperties = [ kEAGLDrawablePropertyRetainedBacking: NSNumber(value: false),
                                          kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8 ]
        
        eaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2 )
        if eaglContext == nil {
            fatalError("Failed to initialize OpenGLES 2.0 context")
        }
        
        guard EAGLContext.setCurrent(eaglContext) else {
            fatalError("Failed to set current OpenGL context")
        }
        
        _displayLink = CADisplayLink(target: self, selector: #selector(renderTexture))
        _displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.common)
        _displayLink?.isPaused = false
    }
    
    // mark: - vertex array buffer
    
    private func setupVAO() {
         
        let meshLayout = CGSize(width: 4, height: 40)
        let vertices = self.genVerticesAndTexCoords(drawRect: CGRect(x: 40, y:200, width: _textureSize.width * CGFloat(0.4), height: _textureSize.height * CGFloat(0.4) ), meshLayout: meshLayout )
        let indicaties = self.genIndicaties(meshLayout: meshLayout)
        _indicateSize = indicaties.count
        
        glGenVertexArrays(1, &_vao)
        glBindVertexArray(_vao)
        
        glGenBuffers(1, &_vbo);
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vbo);
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<GLfloat>.size * vertices.count, vertices, GLenum(GL_STATIC_DRAW))

        glGenBuffers(1, &_ebo)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), _ebo)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), MemoryLayout<ushort>.size * _indicateSize, indicaties, GLenum(GL_STATIC_DRAW))
        
        glBindVertexArray(0)
    }
    
    
    // MARK: - vertices
    
    private func genTextureCoordinates(meshLayout: CGSize ) -> [GLfloat] {
        
        var texCoords: [GLfloat] = []
        let meshWidth = GLfloat(1.0/meshLayout.width)
        let meshHeight = GLfloat(1.0/meshLayout.height)
        
        for y in 0...Int(meshLayout.height) {
            for x in 0...Int(meshLayout.width) {
                texCoords.append( GLfloat(x) * meshWidth )
                texCoords.append( GLfloat(y) * meshHeight)
            }
        }
        return texCoords
    }
    
    private func genVertices( drawRect: CGRect, meshLayout: CGSize ) -> [GLfloat] {
        let viewSize = self.eaglLayer!.bounds.size
        let originX:GLfloat = GLfloat(-1.0 + (2.0 * (drawRect.origin.x/viewSize.width)) )
        let originY:GLfloat = GLfloat(-1.0 + (2.0 * (drawRect.origin.y/viewSize.height)) )
        let width = 2.0 * GLfloat(drawRect.width/viewSize.width)
        let height = 2.0 * GLfloat(drawRect.height/viewSize.height)  
        
        let meshWidth = GLfloat( 2.0 * (drawRect.width/meshLayout.width)/viewSize.width)
        let meshHeight = GLfloat( 2.0 * (drawRect.height/meshLayout.height)/viewSize.height)
    
        var vertices: [GLfloat] = []
        
        for y in 0...Int(meshLayout.height) {
            for x in 0...Int(meshLayout.width) {
                vertices.append( originX + GLfloat(x) * meshWidth )
                vertices.append( originY + GLfloat(y) * meshHeight)
            }
        }
        
        return vertices
    }
    
    private func genVerticesAndTexCoords( drawRect: CGRect, meshLayout: CGSize ) -> [GLfloat] {
        let viewSize = self.eaglLayer!.bounds.size
        let originX:GLfloat = GLfloat(-1.0 + (2.0 * (drawRect.origin.x/viewSize.width)) )
        let originY:GLfloat = GLfloat(-1.0 + (2.0 * (drawRect.origin.y/viewSize.height)) )
        let width = 2.0 * GLfloat(drawRect.width/viewSize.width)
        let height = 2.0 * GLfloat(drawRect.height/viewSize.height)  
        
        // mesh width, height in buffer
        let meshWidth = GLfloat( 2.0 * (drawRect.width/meshLayout.width)/viewSize.width)
        let meshHeight = GLfloat( 2.0 * (drawRect.height/meshLayout.height)/viewSize.height)
        // mesh width, height in texture
        let meshTexWidth = GLfloat(1.0/meshLayout.width)
        let meshTexHeight = GLfloat(1.0/meshLayout.height)
        
        var vertices: [GLfloat] = []
        
        for y in 0...Int(meshLayout.height) {
            for x in 0...Int(meshLayout.width) {
                // position
                vertices.append( originX + GLfloat(x) * meshWidth )
                vertices.append( originY + GLfloat(y) * meshHeight)
                // tex coords
                vertices.append( GLfloat(x) * meshTexWidth )
                vertices.append( GLfloat(y) * meshTexHeight)
                
                print("\(vertices[vertices.count-4]), \(vertices[vertices.count-3]), \(vertices[vertices.count-2]), \(vertices[vertices.count-1])")
            }
        }
        
        return vertices
    }
    
    /*
     
     vertex
     10 11 12 13 14
     | \| \| \| \|
     5  6  7  8  9 
     | \| \| \| \|
     0  1  2  3  4  
     
     indicate
     strip 1: 0 5 1 6 2 7 3 8 4 9
     strip 2: 5 10 6 11 7 12 8 13 9 14 
     
     connect strip
     strip 1 ( 9 5 ) strip 2
     */
    private func genIndicaties( meshLayout: CGSize ) -> [ushort] {
        
        var indicaties: [ushort] = []
        for y in 0..<ushort(meshLayout.height) {
            let startIdx = y * ushort(meshLayout.width + 1)
            for x in 0...ushort(meshLayout.width) {
                indicaties.append( startIdx + x ) // left bottom
                indicaties.append( startIdx + x + ushort(meshLayout.width + 1.0) ) // left top
                
                // connect to next strip // reference Apple OpenGL ES Programming Guide 
                // https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/TechniquesforWorkingwithVertexData/TechniquesforWorkingwithVertexData.html
                if x==ushort(meshLayout.width) {
                    indicaties.append( startIdx + x + ushort(meshLayout.width + 1.0) )
                    indicaties.append( startIdx + ushort(meshLayout.width + 1.0))
                }
            }
        } 
        return indicaties
    }
    
    // MARK: - Texture
    
    private func setupTexture() {
        let imageOpt = UIImage(named: "ice_bubble.jpg")
        guard let image = imageOpt else {
            print("Failed to load image")
            return
        }
        _textureSize = image.size
        
        guard let cgImage = image.cgImage else {
            print("Failed to load image")
            return
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        /*
         it will write one byte each for red, green, blue, and alpha – so 4 bytes in total.
         */
        
        let textureData = UnsafeMutablePointer<GLubyte>.allocate(capacity: width * height * 4) //4 components per pixel (RGBA)
        
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let cgContext = CGContext( data: textureData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: colorspace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue );
        cgContext?.clear(CGRect(x: 0, y: 0, width: width, height: height))
        let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(height))
        cgContext?.concatenate(flipVertical)
        cgContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        glActiveTexture(GLenum(GL_TEXTURE0))
        glGenTextures(1, &_texture)
        glBindTexture(GLenum(GL_TEXTURE_2D), _texture)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR )
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR )
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE )
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE )
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, GLsizei(_textureSize.width), GLsizei(_textureSize.height), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), textureData )
        glBindTexture(GLenum(GL_TEXTURE_2D), 0);
    
    }
    
    // MARK: - Framebuffer
    
    private func setupRenderFramebuffer() {

        glGenRenderbuffers(1, &_colorRenderBuffer);
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), _colorRenderBuffer);
        
        eaglContext?.renderbufferStorage(Int(GL_RENDERBUFFER), from: eaglLayer!)
        var backingWidth: GLint = 0
        var backingHeight: GLint = 0
        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_WIDTH), &backingWidth)
        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_HEIGHT), &backingHeight)
        print("renderBuffer size: \(backingWidth), \(backingHeight)")
        
        glGenFramebuffers(1, &_framebuffer);
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), _framebuffer );
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), 
                                  GLenum(GL_COLOR_ATTACHMENT0),
                                  GLenum(GL_RENDERBUFFER),
                                  _colorRenderBuffer);
        if (glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) != GL_FRAMEBUFFER_COMPLETE) {
            fatalError(String(format:"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))))
        }
        
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
    }
    
    @objc
    private func destoryFrameBuffer() {
        glDeleteFramebuffers(1, &_framebuffer)
        _framebuffer = 0
        if _colorRenderBuffer != 0 {
            glDeleteRenderbuffers(1, &_colorRenderBuffer)
            self._colorRenderBuffer = 0
        }
    }
    
    // MARK: - Program
    
    private func setupProgram() {
        
        let vertPath = Bundle.main.path(forResource: "DisplayShader", ofType: "vsh")!
        let vertShaderString = try! String(contentsOfFile: vertPath)
        let fragPath = Bundle.main.path(forResource: "DisplayShader", ofType: "fsh")!
        let fragShaderString = try! String(contentsOfFile: fragPath)
        
        self._program = GLProgram(vertexShaderString: vertShaderString, fragmentShaderString: fragShaderString)
        // init attributes should before link()
        self._program?.addAttribute(attrName: "position")
        self._program?.addAttribute(attrName: "inputTextureCoordinate")
        
        let status = self._program?.link()
        if status == false {
            let progLog = self._program?.programLog ?? ""
            NSLog("Program link log: %@", progLog)
            let vertLog = self._program?.vertShaderLog ?? ""
            NSLog("Vertex shader compile log: %@", vertLog)
            let fragLog = self._program?.fragShaderLog ?? ""
            NSLog("Fragment shader compile log: %@", fragLog)
            self._program = nil
            fatalError("Filter shader link failed")
        }
        
        self._program?.use()
        
    }
    
    // MARK: - input data
    
    func setupInput() {
        
        glBindVertexArray(_vao)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vbo)
        
        // equal to nil + sizeof(GLfloat) * 2
        let ptr = UnsafeMutablePointer<GLfloat>(bitPattern: MemoryLayout<GLfloat>.size*2)
        glEnableVertexAttribArray(_program!.attribute("position"));
        glVertexAttribPointer(_program!.attribute("position"), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size*4), nil)
        glEnableVertexAttribArray(_program!.attribute("inputTextureCoordinate"))
        glVertexAttribPointer(_program!.attribute("inputTextureCoordinate"), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size*4), ptr )
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), _texture)
        glUniform1i(GLint(_program!.uniform("inputImageTexture")), 0)
        glUniform1f(GLint(_program!.uniform("angle")), 0.0)
    }
    
    // MARK: - Render

    @objc
    func renderTexture( ) {
        
        print("render!")
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), _framebuffer)
        glBindVertexArray(_vao)

//        let meshLayout = CGSize(width: 4, height: 4)
//        var vertices = self.genVerticesAndTexCoords(drawRect: CGRect(x: 40, y:300, width: _textureSize.width * CGFloat(0.4), height: _textureSize.height * CGFloat(0.4) ), meshLayout: meshLayout )
////        let texCoords = self.genTextureCoordinates(meshLayout: meshLayout)
//        let indicaties = self.genIndicaties(meshLayout: meshLayout)
//        _indicateSize = indicaties.count 
//        let ptr = UnsafeMutablePointer<GLfloat>(&vertices)
//        glEnableVertexAttribArray(_program!.attribute(name: "position"));
//        glVertexAttribPointer(_program!.attribute(name: "position"), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size*4), vertices)
//        glEnableVertexAttribArray(_program!.attribute(name:"inputTextureCoordinate"));
//        glVertexAttribPointer(_program!.attribute(name:"inputTextureCoordinate"), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size*4), ptr.advanced(by: 2) )
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), _texture)
        glUniform1i(GLint(_program!.uniform("inputImageTexture")), 0)
        _angle = Float( Int(_angle + 2) % 360 )
        glUniform1f(GLint(_program!.uniform("angle")), _angle)
        
        glViewport(0, 0, GLsizei(self.layer.bounds.size.width), GLsizei(self.layer.bounds.size.height) );
        glClearColor(1.0, 1.0, 1.0, 1.0);
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT));
        
        glDrawElements(GLenum(GL_TRIANGLE_STRIP), GLsizei(_indicateSize), GLenum(GL_UNSIGNED_SHORT), nil)
        
        glBindVertexArray(0)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        
        // display renderbuffer
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), _colorRenderBuffer)
        self.eaglContext?.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    // MARK: - Read Buffer
    
//    func readPixel() -> UIImage? {
//        
//        glBindBuffer(GLenum(GL_FRAMEBUFFER), _framebuffer);
//        
//        var width:GLint = 0
//        var height:GLint = 0
//        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_WIDTH), &width)
//        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_HEIGHT), &height)
//        
//        var pixelLengt = width * height * 4;
//        var pixels = UnsafeMutablePointer<GLubyte>.allocate(capacity: Int(pixelLengt)) 
//        
//        glReadPixels(0, 0, width, height, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), pixels)
//        
//        let providerOpt = CGDataProvider(dataInfo: nil, data: pixels, size: Int(pixelLengt), releaseData: { (dataInfoOpt:UnsafeMutableRawPointer?, data:UnsafeRawPointer, size:Int) in 
//            
//        })
//        
//        guard let provider = providerOpt else {
//            return nil
//        }
//  
//        let colorSpace = CGColorSpaceCreateDeviceRGB()
//        //  swift remove CGBitmapByteOrderDefault, use CGBitmapInfo(rawValue: 0) to replace
//        let bitmapInfo = CGBitmapInfo(rawValue: 0).rawValue | CGImageAlphaInfo.last.rawValue
//        let renderingIntent:CGColorRenderingIntent = CGColorRenderingIntent.defaultIntent
//        let bitsPerComponent = 8
//        let bitsPerPixel = 8 * 4
//        let bytesPerRow = 4 * width
//        let cgImageOpt = CGImage(width: Int(width), 
//                                 height: Int(height), 
//                                 bitsPerComponent: bitsPerComponent,
//                                 bitsPerPixel: bitsPerPixel,
//                                 bytesPerRow: Int(bytesPerRow),
//                                 space: colorSpace, 
//                                 bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo), 
//                                 provider: provider, 
//                                 decode: nil,
//                                 shouldInterpolate: false,
//                                 intent: renderingIntent)
//        guard let cgImage = cgImageOpt else {
//            return nil
//        }
//        
//        UIGraphicsBeginImageContextWithOptions(CGSize(width: CGFloat(width), height: CGFloat(height)), false, 1.0)
//        let cgContext = UIGraphicsGetCurrentContext()
//        cgContext?.setBlendMode(CGBlendMode.copy)
//        cgContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
//        let image = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//        
//        return image
//    }

}
