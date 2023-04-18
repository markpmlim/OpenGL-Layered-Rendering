/*
 
 QuadRenderer.h
 Layered Rendering using a Geometry Shader
 
 Created by Mark Lim Pak Mun on 13/04/2023.
 Copyright © 2023 Apple. All rights reserved.
 
 */

#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#import <GLKit/GLKTextureLoader.h>
#import "OpenGLHeaders.h"

static const CGSize AAPLInteropTextureSize = {1024, 1024};

@interface QuadRenderer : NSObject 

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName;

- (void)draw;

- (void)resize:(CGSize)size;

@property CGPoint mouseCoords;
@property GLuint colorCubemapTexture;

@end
