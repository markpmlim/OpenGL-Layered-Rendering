in vec3 objectPos;

out vec4 fragColor;

uniform samplerCube cubemapTexture;

/*
 The six 2D textures of the cubemap are flipped vertically when viewed
 with Apple's OpenGL Profiler.
 */
void main()
{
    vec3 direction = normalize(vec3(objectPos.x, objectPos.y, objectPos.z));

    fragColor = texture(cubemapTexture, direction);
}
