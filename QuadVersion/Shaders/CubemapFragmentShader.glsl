uniform sampler2D equirectangularImage;

in GS_OUT
{
    vec3 position;
    flat uint layer;    // `int` must be preceded by a flat interpolation qualifer.
} fs_in;

// Default to COLOR_ATTACHMENT0
out vec4 fragColor;

// We map the interpolated 2D position attribute of the vertices of a quad
// to the texture coordinates of a face of a cube.
vec3 cubeFace2Direction(uint face, vec2 position)
{
    // The range of `position` is already in [-1.0, 1.0]
    float uc = position.x;
    float vc = position.y;
    vec3 direction = vec3(0);

    switch (face) {
        case 0:
            // POSITIVE X
            direction.x =  1.0f;
            direction.y =    vc;
            direction.z =   -uc;
            break;
        case 1:
            // NEGATIVE X
            direction.x = -1.0f;
            direction.y =    vc;
            direction.z =    uc;
            break;
        case 2:
            // POSITIVE Y
            direction.x =    uc;
            direction.y =  1.0f;
            direction.z =   -vc;
            break;
        case 3:
            // NEGATIVE Y
            direction.x =    uc;
            direction.y = -1.0f;
            direction.z =    vc;
            break;
        case 4:
            // POSITIVE Z
            direction.x =    uc;
            direction.y =    vc;
            direction.z =  1.0f;
            break;
        case 5:
            // NEGATIVE Z
            direction.x =   -uc;
            direction.y =    vc;
            direction.z = -1.0f;
            break;
    }
    return direction;
}

#define M_PI 3.1415926535897932384626433832795
// invAtan = vec2(1/2π, 1/π)
const vec2 invAtan = vec2(1.0/(2.0*M_PI), 1.0/M_PI);
vec2 SampleSphericalMap(vec3 v)
{
    // tan(θ) = v.z/v.x and sin(φ) = v.y/1.0
    vec2 uv = vec2(atan(v.x, v.z),
                   asin(v.y));

    // Range of uv.x: [-π, π]
    // Range of uv.y: [-π/2, π/2]
    uv *= invAtan;          // range of uv: [-0.5, 0.5]
    uv += 0.5;              // range of uv: [ 0.0, 1.0]
    return uv;
}

// This fragment shader will output the texture of a face of the cubemap.
void main()
{
    // May need to flip the vertical coords.
    vec2 pos = fs_in.position.xy;
    pos.y = -pos.y;

    vec3 dir = normalize(cubeFace2Direction(fs_in.layer, pos));
    vec2 uv = SampleSphericalMap(dir);
    fragColor = texture(equirectangularImage, uv);
}
