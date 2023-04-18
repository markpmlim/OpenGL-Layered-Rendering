// Specifying the `invocations` layout qualifier means Geometry Shader Instancing
// is enabled. This shader is invoked 6 times for each input primitive
// (which is a triangle)
layout (invocations = 6, triangles) in;
layout (triangle_strip, max_vertices = 3) out;

// Inputs to the geometry shader must be arrays
in VS_OUT
{
    vec3 position;
} gs_in[];

/* */
layout (std140) uniform UniformsBlock
{
    uniform mat4 projectionMatrix;
    uniform mat4 viewMatrices[6];
};

out GS_OUT
{
    vec3 position;
} gs_out;

// OpenGL 4.2 or earlier, the built-in variable `gl_Layer` must be passed as a
// user-defined variable.
void main()
{
    for (int i=0; i<gl_in.length(); ++i) {
        gs_out.position = gs_in[i].position;
        gl_Position = projectionMatrix * viewMatrices[gl_InvocationID] * gl_in[i].gl_Position;
        gl_Layer = gl_InvocationID;
        EmitVertex();
    }
    EndPrimitive();
}
