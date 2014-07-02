//
//  GLESUtils.m
//  GLCanvas
//
//  Created by Cortex on 11/5/13.
//  Copyright (c) 2013 LightScaled Solutions. All rights reserved.
//

#import "GLESUtils.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <GLKit/GLKit.h>

@implementation GLESUtils

// Create a texture from an image
+ (GLTextureInfo_t)textureFromImage:(UIImage *) image
{
    CGImageRef		brushImage;
	CGContextRef	brushContext;
	GLubyte			*brushData;
	float			width;
    float           height;
    GLuint          textureId;
    GLTextureInfo_t   texture;
    
    // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
    brushImage = image.CGImage;
    
    // Get the width and height of the image
    width = CGImageGetWidth(brushImage);
    height = CGImageGetHeight(brushImage);
    
    // Make sure the image exists
    if(brushImage) {
        // Allocate  memory needed for the bitmap context
        brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
        
        // Use  the bitmatp creation function provided by the Core Graphics framework.
        brushContext =  CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
        
        // After you create the context, you can draw the  image to the context.
        CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushImage);
        
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        CGContextRelease(brushContext);
        
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &textureId);
        
        // Bind the texture name.
        glBindTexture(GL_TEXTURE_2D, textureId);
        
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        
        // Specify a 2D texture image, providing the a pointer to the image data in memory
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
        
        // Release  the image data; it's no longer needed
        free(brushData);
        
        texture.id = textureId;
        texture.width = (GLsizei)  width;
        texture.height = (GLsizei) height;
    }
    
    return texture;
}


+(GLuint) compileShader:(NSString *) shaderPath withType:(GLenum) shaderType error:(NSError **) error
{
    NSError* lerror;
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSUTF8StringEncoding error:&lerror];
    if (!shaderString) {
        NSLog(@"Error loading shader %@: %@", shaderPath, lerror.localizedDescription);
        exit(1);
    }
    
    //Create OpenGLShader Object
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // Give Source Code to OpenGL For Shader
    const char * shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int) [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    //Compile Shader @ Runtime.
    glCompileShader(shaderHandle);
    
    //Check to see if this failed.
    GLint compileSuccess;
    
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        
        return 0;
    }
    return shaderHandle;
}

+(void) setupProgramUsingVertexShader:(NSString *) vertexShaderName FragmentShader:(NSString *) fragmentShaderName
{
    NSString * vertexShaderPath = [[NSBundle mainBundle] pathForResource:vertexShaderName ofType:@"vsh"];
    NSString * fragmentShaderPath = [[NSBundle mainBundle] pathForResource:fragmentShaderName ofType:@"fsh"];
    
    //Compile vertex shader
    GLuint vertexShader = [GLESUtils compileShader:vertexShaderPath
                                         withType:GL_VERTEX_SHADER error:nil];
    
    //Compile fragment shader
    GLuint fragmentShader = [GLESUtils compileShader:fragmentShaderPath
                                           withType:GL_FRAGMENT_SHADER error:nil];
    
    //Create an empty program object
    GLuint programHandle = glCreateProgram();
    
    //Attach vertex & fragment shaders
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    
    //Link the program object.
    glLinkProgram(programHandle);
    
    //Check to see if program linked to openGL
    GLint linkSuccess;
    
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    //Tell OpenGL To use program.
    glUseProgram(programHandle);
}

@end
