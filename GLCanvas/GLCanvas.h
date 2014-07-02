//
//  GLCanvas.h
//  GLCanvas
//
//  Created by Cortex on 11/5/13.
//  Copyright (c) 2013 LightScaled Solutions. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef struct {
    float Position[3];
    float Color[4];
} Vertex;

@interface GLCanvas : UIView
{
    CAEAGLLayer* _eaglLayer;
    EAGLContext* _context;
    
    GLuint _colorRenderBuffer;
    GLuint _depthRenderBuffer; 
    GLuint _viewFrameBuffer;
    
    GLint _glWidth;
    GLint _glHeight;
    
    
    GLuint _vertexProgram;
    
    //Program Parameters
    GLuint _positionSlot;
    GLuint _colorSlot;
    
    //Projection
    GLuint _projectionSlot;
    GLuint _modelViewSlot;
    
    //Textures
    GLuint _texCoordSlot;
    GLuint _textureSlot;
    
    //Buffers
    GLuint _vertexBuffer;
    GLuint _indexBuffer;
    
    Vertex * _vertices;
    GLuint * _indicies;
    
    GLuint _clearBitField;
    
    float _rotationAngle;
    
    
    

    
    GLuint _vBC;
    GLuint _iBC;
    
    
}

@property (nonatomic, assign) float xRotation;
@property (nonatomic, assign) float yRotation;
@property (nonatomic, assign) float zRotation;



//@property (nonatomic, assign) EAGLContext * context;

//@property (nonatomic, assign) GLuint viewRenderBuffer;
//@property (nonatomic, assign) GLuint viewFrameBuffer;

@end
