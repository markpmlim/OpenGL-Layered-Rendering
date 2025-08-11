/*
 
 OpenGLViewController.m
 Layered Rendering using a Geometry Shader
 
 Created by Mark Lim Pak Mun on 13/04/2023.
 Copyright © 2023 Apple. All rights reserved.
 
 */
#import "OpenGLViewController.h"
#import "CubeRenderer.h"
#import "CubemapImages.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#import "stb_image_write.h"


@implementation OpenGLViewController
{
    // Instance vars
    NSOpenGLView *_view;
    CubeRenderer *_cubeRenderer;
    NSOpenGLContext *_context;
    GLuint _defaultFBOName;

    CVDisplayLinkRef _displayLink;

    BOOL _saveAsHDR;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _view = (NSOpenGLView *)self.view;

    [self prepareView];

    [self makeCurrentContext];

    _cubeRenderer = [[CubeRenderer alloc] initWithDefaultFBOName:_defaultFBOName];

    if (!_cubeRenderer) {
        NSLog(@"OpenGL renderer failed initialization.");
        return;
    }

    [_cubeRenderer resize:self.drawableSize];

    _saveAsHDR = YES;
}



- (CGSize)drawableSize
{
    CGSize viewSizePoints = _view.bounds.size;

    CGSize viewSizePixels = [_view convertSizeToBacking:viewSizePoints];

    return viewSizePixels;
}

- (void)makeCurrentContext
{
    [_context makeCurrentContext];
}

static CVReturn OpenGLDisplayLinkCallback(CVDisplayLinkRef displayLink,
                                          const CVTimeStamp* now,
                                          const CVTimeStamp* outputTime,
                                          CVOptionFlags flagsIn,
                                          CVOptionFlags* flagsOut,
                                          void* displayLinkContext)
{
    OpenGLViewController *viewController = (__bridge OpenGLViewController*)displayLinkContext;

    [viewController draw];
    return YES;
}

// The CVDisplayLink object will call this method whenever a frame update is necessary.
- (void)draw
{
    CGLLockContext(_context.CGLContextObj);

    [_context makeCurrentContext];

    [_cubeRenderer draw];

    CGLFlushDrawable(_context.CGLContextObj);
    CGLUnlockContext(_context.CGLContextObj);
}

- (void)prepareView
{
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0
    };

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];

    NSAssert(pixelFormat, @"No OpenGL pixel format.");

    _context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat
                                          shareContext:nil];

    CGLLockContext(_context.CGLContextObj);

    [_context makeCurrentContext];

    CGLUnlockContext(_context.CGLContextObj);

    glEnable(GL_FRAMEBUFFER_SRGB);
    _view.pixelFormat = pixelFormat;
    _view.openGLContext = _context;
    _view.wantsBestResolutionOpenGLSurface = YES;

    // The default framebuffer object (FBO) is 0 on macOS, because it uses
    // a traditional OpenGL pixel format model. Might be different on other OSes.
    _defaultFBOName = 0;

    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);

    // Set the renderer output callback function.
    CVDisplayLinkSetOutputCallback(_displayLink,
                                   &OpenGLDisplayLinkCallback, (__bridge void*)self);

    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink,
                                                      _context.CGLContextObj,
                                                      pixelFormat.CGLPixelFormatObj);
}

- (void)viewDidLayout
{
    CGLLockContext(_context.CGLContextObj);

    NSSize viewSizePoints = _view.bounds.size;

    NSSize viewSizePixels = [_view convertSizeToBacking:viewSizePoints];

    [self makeCurrentContext];

    [_cubeRenderer resize:viewSizePixels];

    CGLUnlockContext(_context.CGLContextObj);

    if(! CVDisplayLinkIsRunning(_displayLink)) {
        CVDisplayLinkStart(_displayLink);
    }
}

- (void)viewWillDisappear
{
    CVDisplayLinkStop(_displayLink);
}

- (void)viewDidAppear
{
    [_view.window makeFirstResponder:self];
}

- (void)dealloc
{
    CVDisplayLinkStop(_displayLink);

    CVDisplayLinkRelease(_displayLink);
}

- (void)passMouseCoords: (NSPoint)point
{
    _cubeRenderer.mouseCoords = point;
}


- (void)mouseDown:(NSEvent *)event
{
    NSPoint mousePoint = [self.view convertPoint:event.locationInWindow
                                        fromView:nil];

    _cubeRenderer.mouseCoords = mousePoint;
}

- (void)mouseDragged:(NSEvent *)event
{
    NSPoint mousePoint = [self.view convertPoint:event.locationInWindow
                                        fromView:nil];

    _cubeRenderer.mouseCoords = mousePoint;

}

// Return a CGImage object
- (CGImageRef)makeCGImage:(void *)rawData
                    width:(NSUInteger)width
                   height:(NSUInteger)height
               colorSpace:(CGColorSpaceRef)colorSpace
{
    
    NSUInteger pixelByteCount = 4;
    NSUInteger imageBytesPerRow = width * pixelByteCount;
    NSUInteger imageByteCount = imageBytesPerRow * height;
    // Assumes the raw data of CGImage is in RGB/RGBA format.
    // The alpha component is stored in the least significant bits of each pixel.
    CGImageAlphaInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    // Let the function allocate memory for the bitmap
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL,
                                                       width,
                                                       height,
                                                       8,
                                                       imageBytesPerRow,
                                                       colorSpace,
                                                       bitmapInfo);
    void *imageData = NULL;
    if (bitmapContext != NULL) {
        imageData = CGBitmapContextGetData(bitmapContext);
    }
    if (imageData != NULL) {
        memcpy(imageData, rawData, imageByteCount);
    }
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    if (bitmapContext != NULL) {
        CGContextRelease(bitmapContext);
    }
    // The CGImage object might be NULL.
    // The caller need to release this CGImage object
    return cgImage;
}

/*
 Use the OpenGL function "glGetTexLevelParameteriv"  to query.
 Inputs:
 textureName  - texture ID of a cubemap texture
 basename     - base filename of the six filenames to be saved
 directoryURL - folder in which the six filenames are saved
 
 The instance var `_saveAsHDR` must be set to YES/NO before running the demo.
 
 Output:
 error: returned custom NSError object
 
 If the basename is "image", then the 6 filenames are constructed as:
 "image00", "image01", "image02", "image03", "image04", "image05"
 */
- (BOOL)saveTextures:(GLuint)textureName
        withBasename:(NSString *)basename
       relativeToURL:(NSURL *)directoryURL
               error:(NSError **)error
{
    
    if ([basename containsString:@"."]) {
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"File extension provided."}];
        }
        return NO;
    }
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, textureName);
    
    // Use the OpenGL function "glGetTexLevelParameteriv" to query the texture object.
    GLint width, height;
    GLenum format;
    glGetTexLevelParameteriv(GL_TEXTURE_CUBE_MAP_POSITIVE_X, 0, GL_TEXTURE_WIDTH, &width);
    glGetTexLevelParameteriv(GL_TEXTURE_CUBE_MAP_POSITIVE_X, 0, GL_TEXTURE_HEIGHT, &height);
    printf("%d %d\n", width, height);
    // The following call should return 0x881B which is GL_RGB16F
    //  or 0x8058 which is GL_RGBA8
    glGetTexLevelParameteriv(GL_TEXTURE_CUBE_MAP_POSITIVE_X, 0, GL_TEXTURE_INTERNAL_FORMAT, (GLint*)&format);
    printf("0x%0X\n", format);

    int bits = 0;

    GLint _cbits;
    glGetTexLevelParameteriv(GL_TEXTURE_CUBE_MAP_POSITIVE_X, 0, GL_TEXTURE_RED_SIZE, &_cbits);
    bits += _cbits;
    glGetTexLevelParameteriv(GL_TEXTURE_CUBE_MAP_POSITIVE_X, 0, GL_TEXTURE_GREEN_SIZE, &_cbits);
    bits += _cbits;
    glGetTexLevelParameteriv(GL_TEXTURE_CUBE_MAP_POSITIVE_X, 0, GL_TEXTURE_BLUE_SIZE, &_cbits);
    bits += _cbits;

    glGetTexLevelParameteriv(GL_TEXTURE_CUBE_MAP_POSITIVE_X, 0, GL_TEXTURE_ALPHA_SIZE, &_cbits);
    bits += _cbits;
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_DEPTH_SIZE, &_cbits);
    bits += _cbits;

    printf("# of bits per pixel:%d\n", bits);
    imagesFromCubemap(textureName, width, height);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, textureName);

    if (_saveAsHDR == YES) {
        // The call stbi_write_hdr() outputs 3 Floats/pixel
        // Therefore, each pixel is 3x4 = 12 bytes and not 3x2 = 6 bytes
        // The OpenGL call below glGetTexImage() returns each pixel
        //  as a GL_FLOAT (GLfloat) not a GL_HALF_FLOAT (GLhalf).
        // Apple's OpenGL interfaces define the type GLhalf to be uint16_t.
        const size_t kSrcChannelCount = 3;
        const size_t bytesPerRow = width*kSrcChannelCount*sizeof(GLfloat);
        size_t dataSize = bytesPerRow*height;
        void *srcData = malloc(dataSize);
        BOOL isOK = YES;                    // Expect no errors

        // The size of ".hdr" files is usually bigger than other graphic types.
        // Create and allocate space for a new Pixel Buffer Object (pbo)
        GLuint  pbo;
        glGenBuffers(1, &pbo);
        // Bind the newly-created pixel buffer object (pbo) to initialise it.
        glBindBuffer(GL_PIXEL_PACK_BUFFER, pbo);
        // NULL means allocate GPU memory to the PBO.
        // GL_STREAM_READ is a hint indicating the PBO will stream a texture download
        glBufferData(GL_PIXEL_PACK_BUFFER,
                     dataSize,
                     NULL,
                     GL_STREAM_READ);

        for (int i = 0; i<6; i++) {
            NSString* filename = [NSString stringWithFormat:@"%@%02x.hdr", basename, i];
            NSURL* fileURL = [directoryURL URLByAppendingPathComponent:filename];
            const char *filePath = [fileURL fileSystemRepresentation];
            // The parameters `format` and `type` are the pixel format
            //  and type of the desired data
            // Transfer texture into PBO.
            glGetTexImage(GL_TEXTURE_CUBE_MAP_POSITIVE_X+i, // target
                          0,                                // level of detail
                          GL_RGB,                           // format
                          GL_FLOAT,                         // type (can this be GL_HALF_FLOAT?)
                          NULL);
            GetGLError();
            // We are going to read data from the PBO. The call will only return when
            //  the GPU finishes its work with the buffer object.
            void *mappedPtr = glMapBuffer(GL_PIXEL_PACK_BUFFER, GL_READ_ONLY);
            // This should download the image's raw data from the GPU
            memcpy(srcData, mappedPtr, dataSize);
            // Release pointer to the mapping buffer
            glUnmapBuffer(GL_PIXEL_PACK_BUFFER);

            int err = stbi_write_hdr(filePath,
                                     (int)width, (int)height,
                                     3,
                                     srcData);
            if (err == 0) {
                if (error != NULL) {
                    *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                        code:0xdeadbeef
                                                    userInfo:@{NSLocalizedDescriptionKey : @"Unable to write hdr file."}];
                }
                isOK = NO;
                break;
            }
        } // for

        // Unbind and delete the buffer
        glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
        glDeleteBuffers(1, &pbo);
        free(srcData);
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
        return isOK;
    }
    else {
        // format == GL_RGBA8
        const size_t kSrcChannelCount = 4;
        const size_t bytesPerRow = width*kSrcChannelCount*sizeof(uint8_t);
        size_t dataSize = bytesPerRow*height;
        void *srcData = malloc(dataSize);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        BOOL isOK = YES;                    // Expect no errors

        for (int i=0; i<6; i++) {
            glGetTexImage(GL_TEXTURE_CUBE_MAP_POSITIVE_X+i, // target
                          0,                                // level of detail
                          GL_RGBA,                          // format
                          GL_UNSIGNED_BYTE,                 // type
                          srcData);
            CGImageRef cgImage = [self makeCGImage:srcData
                                             width:width
                                            height:height
                                        colorSpace:colorSpace];
            CGImageDestinationRef imageDestination = NULL;
            if (cgImage != NULL) {
                NSString* filename = [NSString stringWithFormat:@"%@%02x.png", basename, i];
                NSURL* fileURL = [directoryURL URLByAppendingPathComponent:filename];
                imageDestination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL,
                                                                   kUTTypePNG,
                                                                   1, NULL);
                CGImageDestinationAddImage(imageDestination, cgImage, nil);
                isOK = CGImageDestinationFinalize(imageDestination);
                CGImageRelease(cgImage);
                CFRelease(imageDestination);
                if (!isOK) {
                    if (error != NULL) {
                        *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                            code:0xdeadbeef
                                                        userInfo:@{NSLocalizedDescriptionKey : @"Unable to write png file."}];
                    }
                    break;
                }
            } // if cgImage not null
            else {
                if (error != NULL) {
                    *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                        code:0xdeadbeef
                                                    userInfo:@{NSLocalizedDescriptionKey : @"Unable to write png file."}];
                }
                isOK = NO;
                break;
            } // cgImage is null
        } // for

        CGColorSpaceRelease(colorSpace);
        free(srcData);
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
        return isOK;
    }
}

// Override inherited method
- (void)keyDown:(NSEvent *)event
{
    if( [[event characters] length] ) {
        unichar nKey = [[event characters] characterAtIndex:0];
        if (nKey == 83 || nKey == 115) {
            GLuint textureID = _cubeRenderer.colorCubemapTexture;
            if (textureID != 0) {
                NSSavePanel *sp = [NSSavePanel savePanel];
                sp.canCreateDirectories = YES;
                sp.nameFieldStringValue = @"image";
                sp.allowedFileTypes = @[@"hdr", @"png"];
                NSModalResponse buttonID = [sp runModal];
                if (buttonID == NSModalResponseOK) {
                    NSString* baseName = sp.nameFieldStringValue;
                    // Strip away the file extension, the program will append
                    //  it based on the OGL texture's internal format.
                    if ([baseName containsString:@"."]) {
                        baseName = [baseName stringByDeletingPathExtension];
                    }
                    NSURL* folderURL = sp.directoryURL;
                    NSError *err = nil;
                    [self saveTextures:textureID
                          withBasename:baseName
                         relativeToURL:folderURL
                                 error:&err];
                }
            }
        }
        else {
            [super keyDown:event];
        }
    }
}
@end
