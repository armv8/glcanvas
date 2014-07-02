//
//  GLESUtils.h
//  GLCanvas
//
//  Created by Cortex on 11/5/13.
//  Copyright (c) 2013 LightScaled Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "GLTextureInfo.h"

@interface GLESUtils : NSObject

+ (GLTextureInfo_t)textureFromImage:(UIImage *) image;
+(GLuint) compileShader:(NSString *) shaderPath withType:(GLenum) shaderType error:(NSError **) error;
+(void) setupProgramUsingVertexShader:(NSString *) vertexShaderName FragmentShader:(NSString *) fragmentShaderName;

@end
