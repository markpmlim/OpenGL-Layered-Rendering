uniform sampler2D equirectangularImage;

in GS_OUT
{
    vec3 position;
} fs_in;

// Default to COLOR_ATTACHMENT0
out vec4 fragColor;


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
    vec3 dir = normalize(fs_in.position);
    vec2 uv = SampleSphericalMap(dir);
    fragColor = texture(equirectangularImage, uv);
}
