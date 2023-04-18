/*
 
 QuadRenderer.m
 Layered Rendering using a Geometry Shader
 
 Created by Mark Lim Pak Mun on 13/04/2023.
 Copyright © 2023 Apple. All rights reserved.
 
 */

#import "QuadRenderer.h"
#import "AAPLMathUtilities.h"
#import <Foundation/Foundation.h>
#import <simd/simd.h>
#include "stb_image.h"

// OpenGL textures are limited to 16K in size.
typedef NS_OPTIONS(NSUInteger, ImageSize) {
    QtrK        = 256,
    HalfK       = 512,
    OneK        = 1024,
    TwoK        = 2048,
    ThreeK      = 3072,
    FourK       = 4096,
    EightK      = 8192,
    SixteenK    = 16384
};

@implementation QuadRenderer
{
    GLuint _defaultFBOName;
    CGSize _viewSize;
    GLuint _cubemapProgram;         // use to render a cubemap texture offscreen.
    GLuint _glslProgram;            // display the rendered cubemap


    GLuint _frameBufferObject;      // FrameBuffer to render into
    GLuint _equiRectTexture;        // The EquiRectangular Projection image
    CGSize _tex0Resolution;         // Resolution of the EquiRectangular image: 2:1
    GLuint _quadVAO;                // Needed by the offscreen render ...
    GLuint _quadVBO;                // ... to produce the cubemap

    GLuint _cubeVAO;                // Use to display a textured cube.
    GLuint _cubeVBO;

    GLuint _colorCubemapTexture;    // Generated cubemap texture
    GLint  _cubemapTextureLoc;
    GLfloat _currentTime;
    GLfloat _rotation;

    // Use to render a textured cube/skybox to the screen
    matrix_float4x4 _projectionMatrix;
    matrix_float4x4 _viewMatrix;
    GLint _projectionMatrixLoc;
    GLint _viewMatrixLoc;
    GLint _modelMatrixLoc;
}

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName
{
    self = [super init];
    if(self) {
        NSLog(@"%s %s", glGetString(GL_RENDERER), glGetString(GL_VERSION));
        GLint maxInvocations;
        glGetIntegerv(GL_MAX_GEOMETRY_SHADER_INVOCATIONS, &maxInvocations);
        printf("max # of invocations of the geometry shader:%d\n", maxInvocations);
        GLint maxOutputVertices;
        glGetIntegerv(GL_MAX_GEOMETRY_OUTPUT_VERTICES, &maxOutputVertices);
        printf("max # of output vertices supported by the geometry shader:%d\n", maxOutputVertices);

        // Build all of your objects and setup initial state here.
        _defaultFBOName = defaultFBOName;

        [self buildResources];

        glBindVertexArray(_cubeVAO);
        NSBundle *mainBundle = [NSBundle mainBundle];
        // GLSL program to display the results
        NSURL *vertexSourceURL = [mainBundle URLForResource:@"SimpleVertexShader"
                                              withExtension:@"glsl"];
        NSURL *fragmentSourceURL = [mainBundle URLForResource:@"SimpleFragmentShader"
                                                withExtension:@"glsl"];
        _glslProgram = [QuadRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                               withFragmentSourceURL:fragmentSourceURL
                                               withGeometrySourceURL:nil];
        //printf("display program:%u\n", _glslProgram);
        _cubemapTextureLoc = glGetUniformLocation(_glslProgram, "cubemapTexture");
        //printf("%d\n", _cubemapTextureLoc);
        _viewMatrixLoc = glGetUniformLocation(_glslProgram, "viewMatrix");
        _projectionMatrixLoc = glGetUniformLocation(_glslProgram, "projectionMatrix");
        _modelMatrixLoc = glGetUniformLocation(_glslProgram, "modelMatrix");
        //printf("%d %d %d\n", _modelMatrixLoc, _viewMatrixLoc, _projectionMatrixLoc);
        glBindVertexArray(0);

        glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
        // Load an EquiRectangular Projection image that will be mapped to
        // the six 2D textures of a Cubemap
        _equiRectTexture = [self textureWithContentsOfFile:@"EquiRectImage.png"
                                                resolution:&_tex0Resolution
                                                     isHDR:NO];
        //printf("%f %f\n", _tex0Resolution.width, _tex0Resolution.height);

        _colorCubemapTexture = [self cubemapTextureFromEquiRecTexture:_equiRectTexture
                                                             cubeSize:OneK];

        // Enable depth testing because we won't be culling the faces
        glEnable(GL_DEPTH_TEST);
    }

    return self;
}

- (void) dealloc
{
    glDeleteProgram(_cubemapProgram);
    glDeleteProgram(_glslProgram);
    glDeleteVertexArrays(1, &_cubeVAO);
    glDeleteBuffers(1, &_cubeVBO);
    glDeleteVertexArrays(1, &_quadVAO);
    glDeleteBuffers(1, &_quadVBO);
    glDeleteTextures(1, &_equiRectTexture);
    glDeleteTextures(1, &_colorCubemapTexture);
    glDeleteFramebuffers(1, &_frameBufferObject);
}


- (void)resize:(CGSize)size
{
    // Handle the resize of the draw rectangle. In particular, update the perspective projection matrix
    // with a new aspect ratio because the view orientation, layout, or size has changed.
    _viewSize = size;
    float aspect = (float)size.width / size.height;

    _projectionMatrix = matrix_perspective_right_hand_gl(radians_from_degrees(65),
                                                         aspect,
                                                         1.0f, 10.0);
    _viewMatrix = matrix_look_at_right_hand_gl((vector_float3){ 0.0f, 0.0f, 5.0f},  // eye
                                               (vector_float3){ 0.0f, 0.0f, 0.0f},  // target 
                                               (vector_float3){ 0.0f, 1.0f, 0.0f}); // up
}

- (GLuint)textureWithContentsOfFile:(NSString *)name
                         resolution:(CGSize *)size
                              isHDR:(BOOL)isHDR
{
    GLuint textureID = 0;

    NSBundle *mainBundle = [NSBundle mainBundle];
    if (isHDR == YES) {
        NSArray<NSString *> *subStrings = [name componentsSeparatedByString:@"."];
        NSString *path = [mainBundle pathForResource:subStrings[0]
                                              ofType:subStrings[1]];
        GLuint width;
        GLuint height;
        
        // Todo: add code to instantiate an OpenGL 2D texture from an .hdr file

    }
    else {
        NSArray<NSString *> *subStrings = [name componentsSeparatedByString:@"."];

        NSURL* url = [mainBundle URLForResource: subStrings[0]
                                  withExtension: subStrings[1]];
        NSDictionary *loaderOptions = @{
            GLKTextureLoaderOriginBottomLeft : @YES,
        };
        NSError *error;
        GLKTextureInfo *textureInfo = [GLKTextureLoader textureWithContentsOfURL:url
                                                                         options:loaderOptions
                                                                           error:&error];
        //NSLog(@"%@", textureInfo);
        textureID = textureInfo.name;
        size->width = textureInfo.width;
        size->height = textureInfo.height;
    }
    return textureID;
}

- (void)updateScene
{
    // frames/per sec = 60.
    _currentTime += 1.0/60.0;
    _rotation = _currentTime;
}

- (void)draw
{
    [self updateScene];

    // Display a rotating box; all 6 faces will be seen
    glViewport(0, 0,
               _viewSize.width, _viewSize.height);
    // The function glClearColor should be called before glClear
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glUseProgram(_glslProgram);
    glUniform1i(_cubemapTextureLoc, 0);     // not necessary
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, _colorCubemapTexture);

    vector_float3 rotationAxis = {1, 1, 0};
    matrix_float4x4 modelMatrix = matrix4x4_rotation(_rotation, rotationAxis);
    glUniformMatrix4fv(_projectionMatrixLoc, 1, GL_FALSE, (const GLfloat*)&_projectionMatrix);
    glUniformMatrix4fv(_viewMatrixLoc, 1, GL_FALSE, (const GLfloat*)&_viewMatrix);
    glUniformMatrix4fv(_modelMatrixLoc, 1, GL_FALSE, (const GLfloat*)&modelMatrix);
    [self renderCube];
    glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    glUseProgram(0);
} // draw

- (void)renderCube
{
    glBindVertexArray(_cubeVAO);
    glDrawArrays(GL_TRIANGLES, 0, 36);
    glBindVertexArray(0);
}

- (void)buildResources
{
    // initialize (if necessary)
    if (_cubeVAO == 0) {
        float vertices[] = {
            // back face
            //  positions               normals       texcoords
            -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, // A bottom-left
             1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, // C top-right
             1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 0.0f, // B bottom-right
             1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, // C top-right
            -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, // A bottom-left
            -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 1.0f, // D top-left
            // front face (anti-clockwise when viewed outside the box.
            -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, // E bottom-left
             1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 0.0f, // F bottom-right
             1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, // G top-right
             1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, // G top-right
            -1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 1.0f, // H top-left
            -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, // E bottom-left
            // left face
            -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // H top-right
            -1.0f,  1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 1.0f, // D top-left
            -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // A bottom-left
            -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // A bottom-left
            -1.0f, -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 0.0f, // E bottom-right
            -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // H top-right
            // right face
             1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // G top-left
             1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // B bottom-right
             1.0f,  1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 1.0f, // C top-right
             1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // B bottom-right
             1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // G top-left
             1.0f, -1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 0.0f, // F bottom-left
            // bottom face
            -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, // F top-right
             1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 1.0f, // E Atop-left
             1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, // A bottom-left
             1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, // A bottom-left
            -1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 0.0f, // B bottom-right
            -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, // F top-right
            // top face
            -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, // D top-left
             1.0f,  1.0f , 1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, // G bottom-right
             1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 1.0f, // C top-right
             1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, // G bottom-right
            -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, // D top-left
            -1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 0.0f  // H bottom-left
        };
 
        glGenVertexArrays(1, &_cubeVAO);
        glGenBuffers(1, &_cubeVBO);
        // fill buffer
        glBindBuffer(GL_ARRAY_BUFFER, _cubeVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
        // Link vertex attributes
        glBindVertexArray(_cubeVAO);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), BUFFER_OFFSET(0));
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    }

    if (_quadVAO == 0) {
        // Array for quad
        GLfloat quadVertices[] = {
            -1.0f, -1.0f, 0.0f, // vert 0
             1.0f, -1.0f, 0.0f, // vert 1
             1.0f,  1.0f, 0.0f, // vert 2

             1.0f,  1.0f, 0.0f, // vert 2
            -1.0f,  1.0f, 0.0f, // vert 3
            -1.0f, -1.0f, 0.0f, // vert 0
        };

        glGenVertexArrays(1, &_quadVAO);
        glBindVertexArray(_quadVAO);
        glGenBuffers(1, &_quadVBO);
        glBindBuffer(GL_ARRAY_BUFFER, _quadVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), (void*)0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    }
}

/*
 Generate a Cubemap Projection from an EquiRectangular Projection
 No depth texture is required.
 */
- (GLuint)cubemapTextureFromEquiRecTexture:(GLuint)equiRectTexture
                                  cubeSize:(unsigned int)size
{
    GLuint cubemapTexture;

    glBindVertexArray(_quadVAO);
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSURL *vertexSourceURL = [mainBundle URLForResource:@"CubemapVertexShader"
                                          withExtension:@"glsl"];
    NSURL *fragmentSourceURL = [mainBundle URLForResource:@"CubemapFragmentShader"
                                            withExtension:@"glsl"];
    NSURL *geometrySourceURL = [mainBundle URLForResource:@"CubemapGeometryShader"
                                            withExtension:@"glsl"];
    
    // GLSL program to render an offscreen cubemap texture.
    _cubemapProgram = [QuadRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                              withFragmentSourceURL:fragmentSourceURL
                                              withGeometrySourceURL:geometrySourceURL];
    //printf("Cubemap Program:%u\n", _cubemapProgram);
    GLint equiRectangularLoc = glGetUniformLocation(_cubemapProgram, "equirectangularImage");
    //printf("%d\n", equiRectangularLoc);

    // Colour cubemap texture
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
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    // Attach cubemap texture to the framebuffer
    // We may need the FBO for a call to glBlitFramebuffer or
    // glCopyTexSubImage2D
    glGenFramebuffers(1, &_frameBufferObject);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferObject);
    glFramebufferTexture(GL_FRAMEBUFFER,        // target
                         GL_COLOR_ATTACHMENT0,  // attachment
                         cubemapTexture,        // texture ID
                         0);                    // level
    CheckFramebuffer();

    glViewport(0, 0,
               size, size);
    glClearColor(0.0, 0.0, 0.5, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);       // There is no depth texture
    glUseProgram(_cubemapProgram);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, equiRectTexture);

    glBindVertexArray(_quadVAO);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);

    glBindTexture(GL_TEXTURE_2D, 0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    glUseProgram(0);

    // Back to the window supplied framebuffer which is 0
    glBindFramebuffer(GL_FRAMEBUFFER, _defaultFBOName);
    return cubemapTexture;
}

/*
 Build a GLSL program by loading the source codes of the shaders.
 */
+ (GLuint)buildProgramWithVertexSourceURL:(NSURL *)vertexSourceURL
                    withFragmentSourceURL:(NSURL *)fragmentSourceURL
                    withGeometrySourceURL:(NSURL * __nullable)geometrySourceURL
{

    NSError *error;

    NSString *vertSourceString = [[NSString alloc] initWithContentsOfURL:vertexSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(vertSourceString, @"Could not load vertex shader source, error: %@.", error);

    NSString *fragSourceString = [[NSString alloc] initWithContentsOfURL:fragmentSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(fragSourceString, @"Could not load fragment shader source, error: %@.", error);

    // Prepend the #version definition to the vertex and fragment shaders.
    float  glLanguageVersion;

    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "%f", &glLanguageVersion);

    // `GL_SHADING_LANGUAGE_VERSION` returns the standard version form with decimals, but the
    //  GLSL version preprocessor directive simply uses integers (e.g. 1.10 should be 110 and 1.40
    //  should be 140). You multiply the floating point number by 100 to get a proper version number
    //  for the GLSL preprocessor directive.
    GLuint version = 100 * glLanguageVersion;

    NSString *versionString = [[NSString alloc] initWithFormat:@"#version %d", version];

    vertSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, vertSourceString];
    fragSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, fragSourceString];

    GLuint prgName;

    GLint logLength, status;

    // Create a GLSL program object.
    prgName = glCreateProgram();

    /*
     * Specify and compile a vertex shader.
     */
    GLchar *vertexSourceCString = (GLchar*)vertSourceString.UTF8String;
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, (const GLchar **)&(vertexSourceCString), NULL);
    glCompileShader(vertexShader);
    glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar*) malloc(logLength);
        glGetShaderInfoLog(vertexShader, logLength, &logLength, log);
        NSLog(@"Vertex Shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the vertex shader:\n%s.\n", vertexSourceCString);

    // Attach the vertex shader to the program.
    glAttachShader(prgName, vertexShader);

    // Delete the vertex shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(vertexShader);

    /*
     * Specify and compile a fragment shader.
     */

    GLchar *fragSourceCString =  (GLchar*)fragSourceString.UTF8String;
    GLuint fragShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragShader, 1, (const GLchar **)&(fragSourceCString), NULL);
    glCompileShader(fragShader);
    glGetShaderiv(fragShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetShaderInfoLog(fragShader, logLength, &logLength, log);
        NSLog(@"Fragment shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(fragShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the fragment shader:\n%s.", fragSourceCString);

    // Attach the fragment shader to the program.
    glAttachShader(prgName, fragShader);

    // Delete the fragment shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(fragShader);

    /*
     * Specify and compile a geometry shader (if any).
     */
    if (geometrySourceURL != nil) {
        NSString *geomSourceString = [[NSString alloc] initWithContentsOfURL:geometrySourceURL
                                                                    encoding:NSUTF8StringEncoding
                                                                       error:&error];

        NSAssert(geomSourceString, @"Could not load geometry shader source, error: %@.", error);
 
        geomSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, geomSourceString];

        GLchar *geometrySourceCString = (GLchar*)geomSourceString.UTF8String;
        GLuint geometryShader = glCreateShader(GL_GEOMETRY_SHADER);
        glShaderSource(geometryShader, 1, (const GLchar **)&(geometrySourceCString), NULL);
        glCompileShader(geometryShader);
        glGetShaderiv(geometryShader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar*) malloc(logLength);
            glGetShaderInfoLog(geometryShader, logLength, &logLength, log);
            NSLog(@"Geometry shader compile log:\n%s.\n", log);
            free(log);
        }

        glGetShaderiv(geometryShader, GL_COMPILE_STATUS, &status);

        NSAssert(status, @"Failed to compile the geometry shader:\n%s.\n", geometrySourceCString);

        // Attach the geometry shader to the program.
        glAttachShader(prgName, geometryShader);

        // Delete the geometry shader because it's now attached to the program, which retains
        // a reference to it.
        glDeleteShader(geometryShader);
    }

    // Before linking, we could get the locations of attributes with the
    // call glBindAttribLocation(). This call is somewhat redundant if
    // a layout qualifier is used before the attribute name.

    /*
     * Link the program.
     */
    glLinkProgram(prgName);
    glGetProgramiv(prgName, GL_LINK_STATUS, &status);
    //NSAssert(status, @"Failed to link program.");
    if (status == GL_FALSE) {
        glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar*)malloc(logLength);
            glGetProgramInfoLog(prgName, logLength, &logLength, log);
            NSLog(@"Program link log:\n%s.\n", log);
            free(log);
        }
    }

    // Added code
    // Call the 2 functions below if VAOs have been bound prior to creating the shader program
    // iOS will not complain if VAOs have NOT been bound.
    glValidateProgram(prgName);
    glGetProgramiv(prgName, GL_VALIDATE_STATUS, &status);
    //NSAssert(status, @"Failed to validate program.");
    if (status == GL_FALSE) {
        fprintf(stderr,"Program cannot run with current OpenGL State\n");
        glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar*)malloc(logLength);
            glGetProgramInfoLog(prgName, logLength, &logLength, log);
            NSLog(@"Program validate log:\n%s\n", log);
            free(log);
        }
    }

    GetGLError();
    GLint numInvocations;
    // Problem with this call?
    //glGetProgramiv(prgName, GL_GEOMETRY_SHADER_INVOCATIONS, &numInvocations);
    //printf("# of invocations of the geometry shader:%d\n", numInvocations);
    return prgName;
}

@end
