// The position attribute is that of a quad not a cube.
// This Vertex Shader will receive 6 vertex positions of a quad and
// pass them to the Geometry Shader as 2 separate triangles.
// In other words, the Vertex Shader invokes the attached Geometry Shader twice
// since the latter is run once for every input primitive (triangle)
in vec3 position;

// Outputs to the geometry shader must be arrays
out VS_OUT
{
    vec3 position;
} vs_out;


void main()
{
    // The range of values of `position' must be [-1.0, 1.0]
    vs_out.position = position;
    // We will assign a value to the built-in `gl_position`
    // in the geometry shader
}
