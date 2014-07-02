//
//  GLCanvas.m
//  GLCanvas
//
//  Created by Cortex on 11/5/13.
//  Copyright (c) 2013 LightScaled Solutions. All rights reserved.
//

#import "GLCanvas.h"
#import "GLESUtils.h"
#import <GLKit/GLKit.h>

#import "CC3GLMatrix.h"
#include <stddef.h>

#include "Colors.h"
#include "ColorConvert.h"


#define X  0
#define Y  1
#define Z  2

#define RED  0
#define GREEN  1
#define BLUE  2
#define ALPHA  3


const Vertex Vertices[] = {
    {{420, 468, 0}, {0, 0, 1, 1}},
    {{420, 668, 0}, {0, 0, 1, 1}},
    {{220, 668, 0}, {0, 1, 0, 1}},
    {{220, 468, 0}, {0, 1, 0, 1}},
    {{420, 468, -1}, {1, 0, 0, 1}},
    {{420, 668, -1}, {1, 0, 0, 1}},
    {{220, 668, -1}, {0, 1, 0, 1}},
    {{220, 468, -1}, {0, 1, 0, 1}}
};

const GLubyte Indices[] = {
    // Front
    0, 1, 2,
    2, 3, 0,
    // Back
    4, 6, 5,
    4, 7, 6,
    // Left
    2, 7, 3,
    7, 6, 2,
    // Right
    0, 4, 1,
    4, 1, 5,
    // Top
    6, 2, 1,
    1, 6, 5,
    // Bottom
    0, 3, 7,
    0, 7, 4
};


@implementation GLCanvas


#pragma mark - Properties

@synthesize xRotation = _xRotation;
@synthesize yRotation = _yRotation;
@synthesize zRotation = _zRotation;

#pragma mark - Class Methods
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - Instance Initialization
-(id) init
{
    self = [super init];
    if(self) {
        [self commontInit];
    }
    return self;
}

-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self) {
        [self commontInit];
    }
    return self;
}

-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self commontInit];
    }
    return self;
}

-(void) commontInit
{
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    
    [self setupLayer];
    [self setupContext];
    
    [self setupRenderBuffer];
    //[self setupDepthBuffer];

    [self setupFrameBuffer];
    
   // [self enableBlending];

    [self compileVertexProgram];
    [self setupProjection];
    
    [self setupVBOs];
   // [self populateVBOs3D];
    [self populateVBOz];
    
    
    [self setupDisplayLink];
}

#pragma mark - OpenGL Layer/Context Setup
-(void) setupLayer
{
    _eaglLayer = (CAEAGLLayer *) self.layer;
    
    //Disable opacity for performance reasons.
    _eaglLayer.opaque = YES;
    
    //Retain EAGLDrawable contents after a call to presentBuffer.
    _eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: [NSNumber numberWithBool:YES],
                                      kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
}


- (void)setupContext {
 
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_context)
    {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (![EAGLContext setCurrentContext:_context])
    {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

-(void) setupDisplayLink
{
    CADisplayLink* displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    
}

#pragma mark - RenderBuffer Setup
- (void)setupRenderBuffer {
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_glWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_glHeight);
    
    _clearBitField |= GL_COLOR_BUFFER_BIT;
    
}

-(void) setupDepthBuffer {
    glGenRenderbuffers(1, &_depthRenderBuffer);
    glBindBuffer(GL_RENDERBUFFER, _depthRenderBuffer);

    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, _glWidth, _glHeight);
    
    _clearBitField |= GL_DEPTH_BUFFER_BIT;
}

-(void) setupFrameBuffer
{
    glGenFramebuffers(1, &_viewFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _viewFrameBuffer);
    
    if(_colorRenderBuffer)
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);
    
    if(_depthRenderBuffer)
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthRenderBuffer);
    
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        exit(1);
    }
    

    
}

#pragma mark - Compile Shaders
- (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType {
    
    //Load shader code into string.
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName
                                                           ofType:@"glsl"];
    NSError* error;
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSLog(@"Error loading shader %@: %@", shaderName, error.localizedDescription);
        exit(1);
    }
    
    // Create a shader object
    GLuint shaderHandle = glCreateShader(shaderType);
    
    //Load Shader Source Code
    const char * shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    //Compiler Shader
    glCompileShader(shaderHandle);
    
    //Check compilation status
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


#pragma mark - Compile Programs
- (void) compileVertexProgram
{
    
    //Compile Vertex Shader
    GLuint vertexShader = [self compileShader:@"SimpleVertex"
                                     withType:GL_VERTEX_SHADER];

    //Compile Fragment Shader
    GLuint fragmentShader = [self compileShader:@"SimpleFragment"
                                       withType:GL_FRAGMENT_SHADER];
    
    //Attach Shaders & Link Program
    _vertexProgram = glCreateProgram();
    glAttachShader(_vertexProgram, vertexShader);
    glAttachShader(_vertexProgram, fragmentShader);
    glLinkProgram(_vertexProgram);
    
    //Check link status
    GLint linkSuccess;
    glGetProgramiv(_vertexProgram, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(_vertexProgram, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(_vertexProgram);
    
    //Get Attribute locations in program.
    _positionSlot = glGetAttribLocation(_vertexProgram, "Position");
    _colorSlot = glGetAttribLocation(_vertexProgram, "SourceColor");
    
    _projectionSlot = glGetUniformLocation(_vertexProgram, "Projection");
    _modelViewSlot =  glGetUniformLocation(_vertexProgram, "ModelView");
    
    _texCoordSlot = glGetAttribLocation(_vertexProgram, "TexCoordIn");
    _textureSlot = glGetUniformLocation(_vertexProgram, "Texture");
    
    
    //Make sure we have valid pointers.
    if(&_positionSlot == 0) {
        NSLog(@"Error locating position attribute");
    }
    
    if(&_colorSlot == 0) {
        NSLog(@"Error locating color attribute");
    }
    
    if(&_projectionSlot == 0) {
        NSLog(@"Error locating projection uniform");
    }
    
    if(&_modelViewSlot == 0) {
        NSLog(@"Error locating modelview uniform");
    }
}

-(void) compilePointProgram
{
    //Compile Vertex Shader
    GLuint vertexShader = [self compileShader:@"SimpleVertex"
                                     withType:GL_VERTEX_SHADER];
    
    //Compile Fragment Shader
    GLuint fragmentShader = [self compileShader:@"SimpleFragment"
                                       withType:GL_FRAGMENT_SHADER];
    
    //Attach Shaders & Link Program
    _vertexProgram = glCreateProgram();
    glAttachShader(_vertexProgram, vertexShader);
    glAttachShader(_vertexProgram, fragmentShader);
    glLinkProgram(_vertexProgram);
    
    //Check link status
    GLint linkSuccess;
    glGetProgramiv(_vertexProgram, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(_vertexProgram, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(_vertexProgram);

}

#pragma mark - Projection/ModelView Setup
-(void) setupProjection
{
   
     GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, _glWidth, 0, _glHeight, -1, 1);
     GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
    
    
    
     GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    
     glUseProgram(_vertexProgram);
     glUniformMatrix4fv(_projectionSlot, 1, GL_FALSE, MVPMatrix.m);
 
   // glEnable(GL_CULL_FACE);

}

-(void) setupTranslationx
{
    GLKMatrix4 matrix = GLKMatrix4MakeTranslation(sin(CACurrentMediaTime()), sin(CACurrentMediaTime()), -1);
    glUniformMatrix4fv(_modelViewSlot, 1, GL_FALSE, matrix.m);

}


-(void) setupRotationx
{
    _rotationAngle +=  90/60;
    
    GLKMatrix4 xMatrix = GLKMatrix4MakeRotation(_xRotation , 1, 0, 0);
    GLKMatrix4 yMatrix = GLKMatrix4MakeRotation(_yRotation , 0, 1, 0);
    GLKMatrix4 zMatrix = GLKMatrix4MakeRotation(_zRotation , 0, 0, 1);

    GLKMatrix4 tMatrix = GLKMatrix4Multiply(xMatrix, yMatrix);
    GLKMatrix4 rMatrix = GLKMatrix4Multiply(tMatrix, zMatrix);
    

    
    glUniformMatrix4fv(_modelViewSlot, 1, GL_FALSE, rMatrix.m);
    
}


#pragma mark - Enable Blending
-(void) enableBlending
{
    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}

#pragma mark - Generate Textures
- (GLuint)setupTexture:(NSString *)fileName {
    // 1
    CGImageRef spriteImage = [UIImage imageNamed:fileName].CGImage;
    if (!spriteImage) {
        NSLog(@"Failed to load image %@", fileName);
        exit(1);
    }
    
    // 2
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte * spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4,
                                                       CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    // 3
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    // 4
    GLuint texName;
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    free(spriteData);        
    return texName;    
}

#pragma mark - VBO Manipulation

- (void)setupVBOs {
    _vertices = malloc(sizeof(Vertex)*10000);
    _vBC = 0;
    
    _indicies = malloc(sizeof(GLuint)*10000);
    _iBC = 0;
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);

    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);

}
/*
-(void) populateVBOs
{
    float zpos = -7.0f;
    
    _vBC = 0;
    
    //Vertex 0
    _vertices[_vBC].Position[X] = 1.0f;
    _vertices[_vBC].Position[Y] = -1.0f;
    _vertices[_vBC].Position[Z] = zpos;
    
    _vertices[_vBC].Color[R] = 1.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    //Vertex 1
    _vertices[_vBC].Position[X] = 1.0f;
    _vertices[_vBC].Position[Y] = 1.0f;
    _vertices[_vBC].Position[Z] = zpos;
    
    _vertices[_vBC].Color[R] = 1.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    //Vertex 2
    _vertices[_vBC].Position[X] = -1.0f;
    _vertices[_vBC].Position[Y] = 1.0f;
    _vertices[_vBC].Position[Z] = zpos;
    
    _vertices[_vBC].Color[R] = 0.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 1.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    //Vertex 3
    _vertices[_vBC].Position[X] = -1.0f;
    _vertices[_vBC].Position[Y] = -1.0f;
    _vertices[_vBC].Position[Z] = zpos;
    
    _vertices[_vBC].Color[R] = 0.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;

    _iBC = 0;
    //Triangle 1
    _indicies[_iBC++] = 0;
    _indicies[_iBC++] = 1;
    _indicies[_iBC++] = 2;
    
    
    //Triangle 2
    _indicies[_iBC++] = 2;
    _indicies[_iBC++] = 3;
    _indicies[_iBC++] = 0;
}

-(void) populateVBOsx
{
    
    float scale = self.contentScaleFactor;
    
    float zpos = -1.0f;
    
    float topy = 548.0f;
    float bottomy =10.0f*scale;
    
    float leftx = 10.0f*scale;
    float rightx = 310.0f;
    
    
    _vBC = 0;
    
    //Vertex 0
    _vertices[_vBC].Position[X] = rightx;
    _vertices[_vBC].Position[Y] = bottomy;
    _vertices[_vBC].Position[Z] = zpos;
    
    _vertices[_vBC].Color[R] = 1.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    //Vertex 1
    _vertices[_vBC].Position[X] = rightx;
    _vertices[_vBC].Position[Y] = topy;
    _vertices[_vBC].Position[Z] = zpos;
    
    _vertices[_vBC].Color[R] = 0.0f;
    _vertices[_vBC].Color[G] = 1.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    //Vertex 2
    _vertices[_vBC].Position[X] = leftx;
    _vertices[_vBC].Position[Y] = topy;
    _vertices[_vBC].Position[Z] = zpos;
    
    _vertices[_vBC].Color[R] = 0.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 1.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    //Vertex 3
    _vertices[_vBC].Position[X] = leftx;
    _vertices[_vBC].Position[Y] = bottomy;
    _vertices[_vBC].Position[Z] = zpos;
    
    _vertices[_vBC].Color[R] = 0.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    _iBC = 0;
    //Triangle 1
    _indicies[_iBC++] = 0;
    _indicies[_iBC++] = 1;
    _indicies[_iBC++] = 2;
    
    
    //Triangle 2
    _indicies[_iBC++] = 2;
    _indicies[_iBC++] = 3;
    _indicies[_iBC++] = 0;
}

-(void) populateVBOs3D
{
    
    float scale = self.contentScaleFactor;
    
    float zback = -1.0f;
    float zfront = 1.0f;
    
    float centerx = self.frame.size.width/2;
    float centery = self.frame.size.height/2;
    
    float size = 100.0f;
    
    float topy =  (centery + size/2)*scale;
    float bottomy = (centery - size/2)*scale;
    
    float leftx = (centerx - size/2)*scale;
    float rightx = (centerx + size/2)*scale;
    
    
    
    _vBC = 0;
    
    //Vertex 0
    _vertices[_vBC].Position[X] = rightx;
    _vertices[_vBC].Position[Y] = bottomy;
    _vertices[_vBC].Position[Z] = zfront;
    
    _vertices[_vBC].Color[R] = 1.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vertices[_vBC].TexCoord[X] = 1.0f;
    _vertices[_vBC].TexCoord[X] = 0.0f;

    _vBC++;
    
    //Vertex 1
    _vertices[_vBC].Position[X] = rightx;
    _vertices[_vBC].Position[Y] = topy;
    _vertices[_vBC].Position[Z] = zfront;
    
    _vertices[_vBC].Color[R] = 1.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;

    _vertices[_vBC].TexCoord[X] = 1.0f;
    _vertices[_vBC].TexCoord[X] = 1.0f;

    _vBC++;
    
    //Vertex 2
    _vertices[_vBC].Position[X] = leftx;
    _vertices[_vBC].Position[Y] = topy;
    _vertices[_vBC].Position[Z] = zfront;
    
    _vertices[_vBC].Color[R] = 0.0f;
    _vertices[_vBC].Color[G] = 1.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vertices[_vBC].TexCoord[X] = 1.0f;
    _vertices[_vBC].TexCoord[X] = 0.0f;

    
    _vBC++;
    
    //Vertex 3
    _vertices[_vBC].Position[X] = leftx;
    _vertices[_vBC].Position[Y] = bottomy;
    _vertices[_vBC].Position[Z] = zfront;
    
    _vertices[_vBC].Color[R] = 0.0f;
    _vertices[_vBC].Color[G] = 1.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;

    
    _vBC++;
    
    //Vertex 4
    _vertices[_vBC].Position[X] = rightx;
    _vertices[_vBC].Position[Y] = bottomy;
    _vertices[_vBC].Position[Z] = zback;
    
    _vertices[_vBC].Color[R] = 1.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    //Vertex 5
    _vertices[_vBC].Position[X] = rightx;
    _vertices[_vBC].Position[Y] = topy;
    _vertices[_vBC].Position[Z] = zback;
    
    _vertices[_vBC].Color[R] = 1.0f;
    _vertices[_vBC].Color[G] = 0.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;

    _vBC++;
    
    //Vertex 6
    _vertices[_vBC].Position[X] = leftx;
    _vertices[_vBC].Position[Y] = topy;
    _vertices[_vBC].Position[Z] = zback;
    
    _vertices[_vBC].Color[R] = 0.0f;
    _vertices[_vBC].Color[G] = 1.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    //Vertex 7
    _vertices[_vBC].Position[X] = leftx;
    _vertices[_vBC].Position[Y] = bottomy;
    _vertices[_vBC].Position[Z] = zback;
    
    _vertices[_vBC].Color[R] = 0.0f;
    _vertices[_vBC].Color[G] = 1.0f;
    _vertices[_vBC].Color[B] = 0.0f;
    _vertices[_vBC].Color[A] = 1.0f;
    
    _vBC++;
    
    _iBC = 0;
    //Front - Triangle 1
    _indicies[_iBC++] = 0;
    _indicies[_iBC++] = 1;
    _indicies[_iBC++] = 2;

    //Front - Triangle 2
    _indicies[_iBC++] = 2;
    _indicies[_iBC++] = 3;
    _indicies[_iBC++] = 0;
    
    //Back - Triangle 1
    _indicies[_iBC++] = 4;
    _indicies[_iBC++] = 6;
    _indicies[_iBC++] = 5;
    
    //Back - Triangle 2
    _indicies[_iBC++] = 4;
    _indicies[_iBC++] = 7;
    _indicies[_iBC++] = 6;
    
    //Left - Triangle 1
    _indicies[_iBC++] = 2;
    _indicies[_iBC++] = 7;
    _indicies[_iBC++] = 3;
    
    //Left - Triangle 2
    _indicies[_iBC++] = 7;
    _indicies[_iBC++] = 6;
    _indicies[_iBC++] = 2;
    
    //Right - Triangle 1
    _indicies[_iBC++] = 0;
    _indicies[_iBC++] = 4;
    _indicies[_iBC++] = 1;
    
    //Right - Triangle 2
    _indicies[_iBC++] = 4;
    _indicies[_iBC++] = 5;
    _indicies[_iBC++] = 1;
    
    //Top - Triangle 1
    _indicies[_iBC++] = 6;
    _indicies[_iBC++] = 2;
    _indicies[_iBC++] = 1;
    
    //Top - Triangle 2
    _indicies[_iBC++] = 1;
    _indicies[_iBC++] = 6;
    _indicies[_iBC++] = 5;
    
    //Botton - Triangle 1
    _indicies[_iBC++] = 0;
    _indicies[_iBC++] = 3;
    _indicies[_iBC++] = 7;
    
    _indicies[_iBC++] = 0;
    _indicies[_iBC++] = 7;
    _indicies[_iBC++] = 4;
    
}
*/


-(void) populateVBOzz
{
    float centerX = _glWidth/2;
    float centerY = _glHeight/2;
    _vBC = 0;
    
    
    float minAngle = -30;
    float maxAngle = 230;
    float totalAngle = maxAngle - minAngle;
    
    float angle = -150.0f;
    float angleInc =  2.0f;
    
    float arcAngle  = 0.0f;
    
    for(angle = 210; angle > -30; angle -= angleInc) {
    float rad_angle = GLKMathDegreesToRadians(angle);
    float next_rad_angle = GLKMathDegreesToRadians(angle - angleInc);
    
    float radius = 300.0f;
    
    arcAngle += angleInc;
    float percent = arcAngle/totalAngle;
        
    
    float x1 = radius * cos(rad_angle) + centerX;
    float y1 = radius * sin(rad_angle) + centerY;
    
    float x2 = radius * cos(next_rad_angle) + centerX;
    float y2 = radius * sin(next_rad_angle) + centerY;


    
    HSVColor_t startColor;
    RGB2HSV(&green, &startColor);
    
        
    HSVColor_t endColor;
    RGB2HSV(&red, &endColor);
    
    
    HSVColor_t hInterpol;
    HSVInterpolate(&startColor, &endColor, percent, &hInterpol);
    RGBColor_t rout;
    
    HSV2RGB(&hInterpol, &rout);
    float  i_r = rout.R/255.0f;
    float  i_g = rout.G/255.0f;
    float  i_b = rout.B/255.0f;
        
    float  i_a = rout.A/255.0f;
    
    
    
    //V0
    _vertices[_vBC].Position[X] = centerX;
    _vertices[_vBC].Position[Y] = centerY;
    _vertices[_vBC].Position[Z] = 0.0f;
    
    _vertices[_vBC].Color[RED] = i_r;
    _vertices[_vBC].Color[GREEN] = i_g;
    _vertices[_vBC].Color[BLUE] = i_b;
    _vertices[_vBC++].Color[ALPHA] = i_a;
    
    //V1
    _vertices[_vBC].Position[X] = x1;
    _vertices[_vBC].Position[Y] = y1;
    _vertices[_vBC].Position[Z] = percent;
    
    _vertices[_vBC].Color[RED] = i_r;
    _vertices[_vBC].Color[GREEN] = i_g;
    _vertices[_vBC].Color[BLUE] = i_b;
    _vertices[_vBC++].Color[ALPHA] = i_a;
    
    //V2
    _vertices[_vBC].Position[X] = x2;
    _vertices[_vBC].Position[Y] = y2;
    _vertices[_vBC].Position[Z] = percent;
    
    _vertices[_vBC].Color[RED] = i_r;
    _vertices[_vBC].Color[GREEN] = i_g;
    _vertices[_vBC].Color[BLUE] = i_b;
    _vertices[_vBC++].Color[ALPHA] = i_a;
    
    
    }
    
}


-(void) populateVBOz
{
    _vBC = 0;
    _iBC = 0;
    
    float centerX = _glWidth/2;
    float centerY = _glHeight/2;
    
    float minAngle = -30;
    float maxAngle = 230;
    float totalAngle = maxAngle - minAngle;
    
    float angle = -150.0f;
    float angleInc =  1.0f;
    
    float arcAngle  = 0.0f;
    
    float radius = 300.0f;

    BOOL outerOverdraw = YES;
    BOOL innerOverdraw = YES;
    
    for(angle = 210; angle > -30; angle -= angleInc) {
        float rad_angle = GLKMathDegreesToRadians(angle);
        float next_rad_angle = GLKMathDegreesToRadians(angle - angleInc);
        
        
        arcAngle += angleInc;
        float percent = arcAngle/totalAngle;
        
        if(percent > sin(CACurrentMediaTime()))
            break;
        
        
        float x0 = (radius - 10 )* cos(rad_angle) + centerX;
        float y0 = (radius - 10)* sin(rad_angle) + centerY;
        
        float x1 = radius * cos(rad_angle) + centerX;
        float y1 = radius * sin(rad_angle) + centerY;
        
        float x2 = radius * cos(next_rad_angle) + centerX;
        float y2 = radius * sin(next_rad_angle) + centerY;
        
        float x3 = (radius - 10 )* cos(next_rad_angle) + centerX;
        float y3 = (radius - 10)* sin(next_rad_angle) + centerY;
        
        float xo1 = (radius + 10 )* cos(rad_angle) + centerX;
        float yo1 = (radius + 10)* sin(rad_angle) + centerY;
        
        float xo2 = (radius + 10 )* cos(next_rad_angle) + centerX;
        float yo2 = (radius + 10)* sin(next_rad_angle) + centerY;
        
        float xi1 = (radius - 20 )* cos(rad_angle) + centerX;
        float yi1 = (radius - 20)* sin(rad_angle) + centerY;
        
        float xi2 = (radius - 20 )* cos(next_rad_angle) + centerX;
        float yi2 = (radius - 20)* sin(next_rad_angle) + centerY;
        
        HSVColor_t startColor;
        RGB2HSV(&green, &startColor);
        
        
        HSVColor_t endColor;
        RGB2HSV(&red, &endColor);
        
        
        HSVColor_t hInterpol;
        HSVInterpolate(&startColor, &endColor, percent, &hInterpol);
        RGBColor_t rout;
        
        HSV2RGB(&hInterpol, &rout);
        float  i_r = rout.R/255.0f;
        float  i_g = rout.G/255.0f;
        float  i_b = rout.B/255.0f;
        
        float  i_a = rout.A/255.0f;
        
        percent = 0;
        
        //V0
        uint v0 = _vBC;
        _vertices[_vBC].Position[X] = x0;
        _vertices[_vBC].Position[Y] = y0;
        _vertices[_vBC].Position[Z] = 0.0f;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
        
        
        //V1
        uint v1 = _vBC;
        _vertices[_vBC].Position[X] = x1;
        _vertices[_vBC].Position[Y] = y1;
        _vertices[_vBC].Position[Z] = percent;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
        
        //V2
        uint v2 = _vBC;
        _vertices[_vBC].Position[X] = x2;
        _vertices[_vBC].Position[Y] = y2;
        _vertices[_vBC].Position[Z] = percent;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
      
        //V3
        uint v3 = _vBC;
        _vertices[_vBC].Position[X] = x3;
        _vertices[_vBC].Position[Y] = y3;
        _vertices[_vBC].Position[Z] = percent;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
        
        
        _indicies[_iBC++] = v0;
        _indicies[_iBC++] = v1;
        _indicies[_iBC++] = v2;
        
        _indicies[_iBC++] = v0;
        _indicies[_iBC++] = v2;
        _indicies[_iBC++] = v3;
        
        //Over draw
        //VO1
        
        if(outerOverdraw) {
            
            //VO2
            int vo1 = _vBC;
            _vertices[_vBC].Position[X] = xo1;
            _vertices[_vBC].Position[Y] = yo1;
            _vertices[_vBC].Position[Z] = percent;
            
            _vertices[_vBC].Color[RED] = 0;
            _vertices[_vBC].Color[GREEN] = 0;
            _vertices[_vBC].Color[BLUE] = 0;
            _vertices[_vBC++].Color[ALPHA] = 0;
            
            //VO2
            int vo2 = _vBC;
            _vertices[_vBC].Position[X] = xo2;
            _vertices[_vBC].Position[Y] = yo2;
            _vertices[_vBC].Position[Z] = percent;
            
            _vertices[_vBC].Color[RED] = 0;
            _vertices[_vBC].Color[GREEN] = 0;
            _vertices[_vBC].Color[BLUE] = 0;
            _vertices[_vBC++].Color[ALPHA] = 0;
            
            _indicies[_iBC++] = v1;
            _indicies[_iBC++] = vo1;
            _indicies[_iBC++] = vo2;
            
            _indicies[_iBC++] = v1;
            _indicies[_iBC++] = vo2;
            _indicies[_iBC++] = v2;
        }
        
        //Inner Overdraw
        //VI1
        if(innerOverdraw) {
            
            //VI1
            uint vi1 = _vBC;
            _vertices[_vBC].Position[X] = xi1;
            _vertices[_vBC].Position[Y] = yi1;
            _vertices[_vBC].Position[Z] = percent;
            
            _vertices[_vBC].Color[RED] = 0;
            _vertices[_vBC].Color[GREEN] = 0;
            _vertices[_vBC].Color[BLUE] = 0;
            _vertices[_vBC++].Color[ALPHA] = 0;
            
            //VI2
            uint vi2 =_vBC;
            _vertices[_vBC].Position[X] = xi2;
            _vertices[_vBC].Position[Y] = yi2;
            _vertices[_vBC].Position[Z] = percent;
            
            _vertices[_vBC].Color[RED] = 0;
            _vertices[_vBC].Color[GREEN] = 0;
            _vertices[_vBC].Color[BLUE] = 0;
            _vertices[_vBC++].Color[ALPHA] = 0;
            
            _indicies[_iBC++] = v0;
            _indicies[_iBC++] = vi1;
            _indicies[_iBC++] = vi2;

            _indicies[_iBC++] = v0;
            _indicies[_iBC++] = vi2;
            _indicies[_iBC++] = v3;
            
        }
        
    }
    
}


-(void) populateVBOwz
{
    
    float innerRadius = 200.0f;
    float outerRadius = innerRadius + 10;
    
    
    float maxAngle = 150;
    float minAngle = -150;
    float totalAngle = maxAngle - minAngle;
    
    float arcAngle = 0;
    
    float startAngle;
    float endAngle;
    /*
    if(!gauge.inverted)
    {
        startAngle =  gauge.minAngle;
        endAngle =  gauge.maxAngle;
        arcAngle = 0;
    }
    else {
        startAngle =  gauge.maxAngle;
        endAngle =  gauge.minAngle;
        arcAngle = 0;
    }
    */
    
    for(float angle  = 0; angle <= (90); angle += 5)
    {
        float rad_angle =  angle * M_PI/180;
        float next_rad_angle = (angle+5)*M_PI/180 ;
        
        
        arcAngle += 5;
        float percent = arcAngle/totalAngle;
        
        if(percent > sin(CACurrentMediaTime()))
            break;
        
        //Generate the bottom triangle.
        float x1 = innerRadius * sin(rad_angle) + 568;
        float y1 = innerRadius * cos(rad_angle) + 320;
        
        float x2 = (innerRadius - 60) * sin(rad_angle) + 568;
        float y2 = (innerRadius - 60) * cos(rad_angle) + 320;
        
        float x3 = innerRadius * sin(next_rad_angle)+ 568;
        float y3 = innerRadius * cos(next_rad_angle) + 320;
        
        
        float x4 = (innerRadius - 60) * sin(next_rad_angle)+ 568;
        float y4 = (innerRadius - 60) * cos(next_rad_angle) + 320;
        
        
        float xo1 = (innerRadius + 10) * sin(rad_angle)+ 568;
        float yo1 = (innerRadius + 10) * cos(rad_angle) + 320;
        
        float xo2 = (innerRadius + 10) * sin(next_rad_angle) + 568;
        float yo2 = (innerRadius + 10) * cos(next_rad_angle) + 320;
        
        
        //        NSLog(@"%f %f , %f %f, %f %f", x1, y1, x2, y2, x3, y3);
        
        
        HSVColor_t startColor;
        RGB2HSV(&red, &startColor);
        
        HSVColor_t endColor;
        RGB2HSV(&blue, &startColor);
    
        
        HSVColor_t hInterpol;
        HSVInterpolate(&startColor, &endColor, percent, &hInterpol);
        RGBColor_t rout;
    
        HSV2RGB(&hInterpol, &rout);
        float  i_r = rout.R/255.0f;
        float  i_g = rout.G/255.0f;
        float  i_b = rout.B/255.0f;
        float  i_a = rout.B/255.0f;
        
        
        //Vertices for bottom triangle.
        
        //V0
        _vertices[_vBC].Position[X] = x1;
        _vertices[_vBC].Position[Y] = y1;
        _vertices[_vBC].Position[Z] = 0.0f;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
        
    
        //V1
        _vertices[_vBC].Position[X] = x3;
        _vertices[_vBC].Position[Y] = y3;
        _vertices[_vBC++].Position[Z] = 0.0f;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
        
        //V2
        _vertices[_vBC].Position[X] = x2;
        _vertices[_vBC].Position[Y] = y2;
        _vertices[_vBC++].Position[Z] = 0.0f;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
        
        //V3
        _vertices[_vBC].Position[X] = x2;
        _vertices[_vBC].Position[Y] = y2;
        _vertices[_vBC++].Position[Z] = 0.0f;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
        
        //V4
        _vertices[_vBC].Position[X] = x3;
        _vertices[_vBC].Position[Y] = y3;
        _vertices[_vBC++].Position[Z] = 0.0f;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
        
        //V5
        _vertices[_vBC].Position[X] = x4;
        _vertices[_vBC].Position[Y] = y4;
        _vertices[_vBC++].Position[Z] = 0.0f;

        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = i_a;
        
        
        //Overdraw Vertices
        _vertices[_vBC].Position[X] = x4;
        _vertices[_vBC].Position[Y] = y4;
        _vertices[_vBC++].Position[Z] = 0.0f;
        
        _vertices[_vBC].Color[RED] = i_r;
        _vertices[_vBC].Color[GREEN] = i_g;
        _vertices[_vBC].Color[BLUE] = i_b;
        _vertices[_vBC++].Color[ALPHA] = 0.0f;
        
        
        
    }
}

#pragma mark - Rendering
- (void)clearScreen
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(_clearBitField);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

-(void) render:(CADisplayLink*) displayLink
{
    /*
    int depth;
    glGetIntegerv(GL_DEPTH_BITS, &depth);
    NSLog(@"%i bits depth", depth);
    
    if(depth == 0)
        exit(1);
    */
    
    [EAGLContext setCurrentContext:_context];
	glBindFramebuffer(GL_FRAMEBUFFER, _viewFrameBuffer);
    
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
glEnable(GL_DEPTH_TEST);

    [self populateVBOz];
    
    
    
   // [self setupTranslationx];
    [self setupRotationx];
    
    /*
    CC3GLMatrix *modelView = [CC3GLMatrix matrix];
    _rotationAngle += displayLink.duration * 30;
    [modelView populateFromTranslation:CC3VectorMake(sin(CACurrentMediaTime()), -1, 1)];

    [modelView rotateBy:CC3VectorMake(_rotationAngle, _rotationAngle, 0)];
    
    glUniformMatrix4fv(_modelViewSlot, 1, 0, modelView.glMatrix);
     */

    
    glViewport(0, 0, _glWidth, _glHeight);
    
    glBufferData(GL_ARRAY_BUFFER, _vBC * sizeof(Vertex), _vertices, GL_STATIC_DRAW);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, _iBC * sizeof(GLuint), _indicies, GL_STATIC_DRAW);
    
 //   glBufferData(GL_ARRAY_BUFFER, 8 * sizeof(Vertex), Vertices, GL_STATIC_DRAW);
 //   glBufferData(GL_ELEMENT_ARRAY_BUFFER, 36 * sizeof(GLubyte), Indices, GL_STATIC_DRAW);
    
    
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    glEnableVertexAttribArray(_positionSlot);
    
    
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (GLvoid*)offsetof(Vertex, Color));
    glEnableVertexAttribArray(_colorSlot);
    
    glUseProgram(_vertexProgram);
    
    // Used when indices are valid.
    glDrawElements(GL_TRIANGLES, _iBC,
                   GL_UNSIGNED_INT, 0);
    
    //glDrawArrays(GL_TRIANGLES, 0, _vBC);
    
    
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
}

@end
