// The position attribute is that of a cube.
// This vertex shader will receive 36 vertex positions and
// pass them to the Geometry Shader as 6 separate triangles.
in vec3 position;

// Outputs to the Geometry Shader must be arrays
out VS_OUT
{
    vec3 position;
} vs_out;


void main()
{
    vs_out.position = position;
    gl_Position = vec4(position, 1.0);
}
