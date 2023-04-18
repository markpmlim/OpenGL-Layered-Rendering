# Layered Rendered Cubemap Texture


## Overview

**Geometry shaders** became part of the OpenGL core profile specifications as of OpenGL 3.2. It is possible to render into array textures by first attaching them to a framebuffer object and then using a geometry shader to specify which layer is to be rendered into. Rendering to array textures (aka as texture maps)  using framebuffer objects are supported by the **glFramebufferTexture*** family of calls which allows a mipmap level of a texture map to be attached as a framebuffer attachment.


## Details 

The call below

```c

    void glFramebufferTexture(GLenum target,
                              GLenum attachment,
                              GLuint texture,
                              GLint level);

```

can be used to create simple 2D textures where `texture` is a texture identifier (returned by the call **glGenTextures**) with the texture type `GL_TEXTURE_2D`. However, its texture type is `GL_TEXTURE_CUBE_MAP` or an  array texture (e.g. `GL_TEXTURE_2D_ARRAY`), then the specified texture level is an array of images, and the framebuffer attachment is considered to be layered.


The other calls in the **glFramebufferTexture*** family

```C
    glFramebufferTexture1D(GLenum target,
                           GLenum attachment,
                           GLenum textarget,
                           GLuint texture,
                           GLint level)

    glFramebufferTexture2D(GLenum target,
                           GLenum attachment,
                           GLenum textarget,
                           GLuint texture,
                           GLint level)

    glFramebufferTexture3D(GLenum target,
                           GLenum attachment,
                           GLenum textarget,
                           GLuint texture,
                           GLint level,
                           GLint layer)
    
```

allow a specific texture type (e.g. `GL_TEXTURE_2D`) to be attached to the framebuffer object. However, for **cubemap textures**, this 3rd parameter *textarget* must be a specific face (e.g. `GL_TEXTURE_CUBE_MAP_POSITIVE_X`) of the texture.

So the difference between the 2 calls is the `glFramebufferTexture` call attaches **all** cube map faces of a specific mipmap level as an array of images (layered framebuffer) while the `glFramebufferTexture2D` call only attaches a single face of a specific mipmap level.

The project consist of 2 applications. The first app named **QuadVersion** renders a quad while the second app (named **CubeVersion**) renders a cube. *Geometry Shader Instancing* can be enabled by specifying the **invocations** layout qualifier e.g.

```glsl

    layout (triangles, invocations = 6) in;

```

**Cubemap textures** are a special form of an array texture. The following steps are required to perform layered rendering with a geometry shader.


a) Create an empty cubemap texture.

    glGenTextures(1, &cubemapTexture);
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapTexture);
    for(uint face = 0; face < 6; ++face) {
        // Allocate memory space for the six 2D textures.
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + face, // target
                     0,                                     // level
                     GL_RGBA32F,                            // internal format
                     size, size,                            // width & height
                     0,                                     // border
                     GL_RGBA,                               // format
                     GL_FLOAT,                              // type
                     NULL);                                 // allocate
    }


Notice the internal format is `GL_RGBA32F`; each pixel of an image of the texture map consists of four 32-bit floats. 


b) Create a framebuffer object with the call:

    glGenFrameBuffer(1, &_frameBufferObject);


c) Call the function *glBindFramebuffer* so that all rendering to be directed to framebuffer object.


d) Call the function *glFramebufferTexture* to attach a level of the cubemap texture to the framebuffer object.

    glFramebufferTexture(GL_FRAMEBUFFER,        // target
                         GL_COLOR_ATTACHMENT0,  // attachment
                         cubemapTexture,        // texture ID
                         0);                    // level

The cubemap texture would be layered rendered with a mipmap level of 0 (the base level).


e) Setup for rendering with a previously created GLSL program which is instantiated from 3 shader source codes.


f) Render of the vertices of any geometrical shape e.g. quad, cube or even a torus.



The **QuadVersion** is relatively simpler. A 2x2 quad is sent from the client side to the GLSL program's vertex shader with a call

    glDrawArrays(GL_TRIANGLES, 0, 6);

A 2D texture instantiated from an EquiRectangular Projection (ERP) image is passed as a uniform to the fragment shader. The geometry shader just pass through the vertices to the fragment shader which remaps the ERP texture to the correct face of the cubemap texture. The built-in variable `glLayer` must be passed  (as a flat interpolated integer) together with the position attribute of a vertex of the quad.


The vertex shader of the **CubeVersion** is sent the position attribute of 36 vertices of a 2x2x2 cube. In order to project the ERP image into six 2D images, a projection matrix and 6 view matrices are passed as uniforms to the geometry shader. To upload these matrices, we could have used the following lines.

    glUniformMatrix4fv(_cubeProjectionLoc, 1, GL_FALSE, (const GLfloat*)&_cubeProjectionMatrix);
    for (int i=0; i<6; i++) {
        glUniformMatrix4fv(_cubViewMatricesLocs[i], 1, GL_FALSE, (const GLfloat*)&_cubeViewMatrices[i]);
    }

where the locations of the matrix uniforms were obtained by the code:

    _cubeProjectionLoc = glGetUniformLocation(_cubemapProgram, "projectionMatrix");
    for (int i=0; i<6; i++) {
        NSString *locName = [NSString stringWithFormat:@"%@%u]", @"viewMatrices[", i];
        _cubViewMatricesLocs[i] = glGetUniformLocation(_cubemapProgram, locName.cString);
    }


Instead the matrix uniforms are passed in the form of a uniform buffer.

    GLuint uniformsBuffer;
    glGenBuffers(1, &uniformsBuffer);
    glBindBuffer(GL_UNIFORM_BUFFER, uniformsBuffer);
    glBufferData(GL_UNIFORM_BUFFER,
                 7 * sizeof(matrix_float4x4),
                 NULL,                      // allocate data store only
                 GL_STATIC_DRAW);           // upload once only



Uploading the data of the 7 matrices is performed by the lines:

    glBindBufferBase(GL_UNIFORM_BUFFER, UNIFORMS_BLOCK_BINDING0, uniformsBuffer);
    UNIFORMS_BUFFER *buffer = (UNIFORMS_BUFFER *)glMapBufferRange(GL_UNIFORM_BUFFER,
                                                                  0,
                                                                  sizeof(UNIFORMS_BUFFER),
                                                                  GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    buffer->projectionMatrix = _cubeProjectionMatrix;
    for (int i=0; i<6; i++) {
        buffer->viewMatrices[i] = _cubeViewMatrices[i];
    }
    glUnmapBuffer(GL_UNIFORM_BUFFER);



## Saving the images.

Certain graphic cards, notably those produced by NVidia do not allow the six textures to be saved as images. Only the image associated with the +X face of the cubemap texture can be saved. There is a workaround solution posted on the Internet. A modified version is included in the project.

The following lines must be uncommented:

    printf("# of bits per pixel:%d\n", bits);
    //imagesFromCubemap(textureName, width, height);
    //glActiveTexture(GL_TEXTURE0);
    //glBindTexture(GL_TEXTURE_CUBE_MAP, textureName);

    if (_saveAsHDR == YES) {
        ...


if the user could not save the six generated images to disk.


Notes: Apple's implementation of OpenGL ES (3.0) for the iOS does not support geometry shaders or tessellation shaders.


**System Requirements**

OpenGL 3.2 or later

## Development Environment

XCode 9.x running on macOS 10.13.x

The project can be back-ported to earlier versions of XCode. Storyboards were introduced in XCode 10.10.x. So porting back to XCode 6.x or XCode 7.x should be relatively easy. 

For macOS 7.x - 9.x, a barebones MainMenu.xib file is automatically created as part of an XCode project. The source code will have to be re-arranged.


**GLUT** running on macOS 10.9 or later can support OpenGL Core Profile. During initialization, a call similar to the one below

    glutInitDisplayMode(GLUT_RGBA | GLUT_DEPTH | GLUT_3_2_CORE_PROFILE);

should be made if the app's OpenGL shaders are written in Modern OpenGL's GLSL format.


## Resources:

https://computergraphics.stackexchange.com/questions/10254/draw-on-cubemap-with-help-of-geometry-shader-each-triangle-covers-each-cubemap-f

https://stackoverflow.com/questions/73479854/why-is-my-cubemap-rendered-to-fbo-only-rendering-one-side-of-my-cube

https://sites.google.com/site/john87connor/framebuffer-object/4-1-layered-rendering-cubemap

https://stackoverflow.com/questions/53803833/layered-rendering-cubemap-in-one-pass

https://stackoverflow.com/questions/37707875/draw-a-cubemap-in-a-single-pass-opengl

https://stackoverflow.com/questions/462721/rendering-to-cube-map

https://community.khronos.org/t/output-cubemap-texture-object-as-bitmap-images/75445

https://discourse.libcinder.org/t/single-pass-cubemap-solved/1299

https://community.khronos.org/t/glgetteximage-and-cube-maps/43311

https://community.khronos.org/t/output-cubemap-texture-object-as-bitmap-images/75445

