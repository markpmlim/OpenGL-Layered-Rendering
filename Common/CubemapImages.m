/*
 CubemapImages.m
 Layered Rendering using a Geometry Shader
 
 Created by Mark Lim Pak Mun on 14/04/2023.
 Copyright © 2023 Apple. All rights reserved.
 
 */


#import <Foundation/Foundation.h>
#import "OpenGLHeaders.h"

// Certain GPUs notably from NVidia may have problems exporting the
// images of a cubemap texture generated from a one-pass layered rendering
// using a geometry shader.
// Only the image associated with the token `GL_TEXTURE_CUBE_MAP_POSITIVE_X`
// can be extracted from the cubemap texture with the function `glGetTexImage`.
// This is a workaround solution.
//
// The paramater `cubemapTextureID` is the texture identifier of the layered rendered
// cubemap texture.
// The parameters `width` and `height` of 6 images at base level zero are passed
// Each pixel of the six images of this cubemap texture are FOUR 32-bit floats.
BOOL imagesFromCubemap(GLuint cubemapTextureID,
                       GLint width, GLint height)
{
    const size_t kSrcChannelCount = 4;
    const size_t bytesPerRow = width*kSrcChannelCount*sizeof(GLfloat);
    size_t dataSize = bytesPerRow*height;

    void *front = malloc(dataSize);
    void *back = malloc(dataSize);

    void *top = malloc(dataSize);
    void *bottom = malloc(dataSize);

    void *left = malloc(dataSize);
    void *right = malloc(dataSize);

    GLuint carrierTexture;
    GLuint carrierFBO;
    
    glGenTextures(1, &carrierTexture);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, carrierTexture);
    
    glGenFramebuffers(1, &carrierFBO);
    // The first parameter should be GL_READ_FRAMEBUFFER not GL_FRAMEBUFFER
    glBindFramebuffer(GL_READ_FRAMEBUFFER, carrierFBO);
    GetGLError()

    // The first parameter should be GL_READ_FRAMEBUFFER not GL_FRAMEBUFFER
    glFramebufferTexture2D(GL_READ_FRAMEBUFFER,             // target
                           GL_COLOR_ATTACHMENT0,            // attachment
                           GL_TEXTURE_CUBE_MAP_POSITIVE_X,  //texturetarget
                           cubemapTextureID,                // texture ID
                           0);                              // level
    GetGLError()
    // Copy pixels from the current read framebuffer (carrierFBO) into the texture
    // currently bound to target of the active texture unit (carrierText)
    glCopyTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X,        // target
                     0,                                     // level
                     GL_RGBA,                               // internal format
                     0, 0,                                  // x, y
                     width, height,                         // width, height
                     0);                                    // border
    GetGLError()
    glGetTexImage(GL_TEXTURE_CUBE_MAP_POSITIVE_X,           // target
                  0,                                        // level
                  GL_RGBA,                                  // format
                  GL_FLOAT,                                 // type
                  right);                                   // pointer to a client memory block
                                                            //  where image data is placed
    GetGLError()

    glFramebufferTexture2D(GL_READ_FRAMEBUFFER,
                           GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
                           cubemapTextureID,
                           0);

    glCopyTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
                     0,
                     GL_RGBA,                           // internal format
                     0,0,
                     width, height,                     // width, height
                     0);
    
    GetGLError()
    // Read image data from the texture carrierText
    glGetTexImage(GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
                  0,
                  GL_RGBA,                              // format
                  GL_FLOAT,
                  left);
    GetGLError()

    glFramebufferTexture2D(GL_READ_FRAMEBUFFER,
                           GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
                           cubemapTextureID,
                           0);
    glCopyTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
                     0,
                     GL_RGBA,                           // internal format
                     0,0,
                     width, height,                     // width, height
                     0);
    glGetTexImage(GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
                  0,
                  GL_RGBA,                              // format
                  GL_FLOAT,
                  top);
    
    
    glFramebufferTexture2D(GL_READ_FRAMEBUFFER,
                           GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
                           cubemapTextureID,
                           0);
    glCopyTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
                     0,
                     GL_RGBA,                           // internal format
                     0,0,
                     width, height,                     // width, height
                     0);
    glGetTexImage(GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
                  0,
                  GL_RGBA,                              // format
                  GL_FLOAT,
                  bottom);

    glFramebufferTexture2D(GL_READ_FRAMEBUFFER,
                           GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
                           cubemapTextureID,
                           0);
    glCopyTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
                     0,
                     GL_RGBA,                           // internal format
                     0,0,
                     width, height,                     // width, height
                     0);
    glGetTexImage(GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
                  0,
                  GL_RGBA,                              // format
                  GL_FLOAT,
                  front);

    glFramebufferTexture2D(GL_READ_FRAMEBUFFER,
                           GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
                           cubemapTextureID,
                           0);
    glCopyTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
                     0,
                     GL_RGBA,                           // internal format
                     0,0,
                     width, height,                     // width, height
                     0);
    glGetTexImage(GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
                  0,
                  GL_RGBA,                              // format
                  GL_FLOAT,
                  back);

    glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1,&carrierFBO);
    glDeleteTextures(1, &carrierTexture);

    // Recover the memory
    free(right);
    free(left);
    free(front);
    free(back);
    free(top);
    free(bottom);
    GetGLError()

    return YES;
}
