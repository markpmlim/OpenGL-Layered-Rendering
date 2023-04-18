// Specifying the `invocations` layout qualifier means Geometry Shader Instancing
// is enabled. This shader is invoked 6 times for each input primitive
// (which is a triangle)
// Note: We are using `gl_InvocationID` instead of an outer for-loop.
layout (triangles, invocations=6) in;
layout (triangle_strip, max_vertices=3) out;

// Inputs to the geometry shader must be arrays
in VS_OUT
{
    vec3 position;
} gs_in[];

out GS_OUT
{
    vec3 position;
    flat uint layer;    // `uint` must be preceded by a flat interpolation qualifer.
} gs_out;

// For OpenGL 4.2 or earlier, the built-in variable `gl_Layer` must be passed as a
// user-defined variable.
// The special built-in input variable `gl_in` is an array containing built-in
// outputs that are available in the previous (vertex or tessellation) stage.
// It is implicit declared as an array. 
void main()
{
    for (int i=0; i<gl_in.length(); ++i) {
        gs_out.position = gs_in[i].position;
        gl_Position = vec4(gs_out.position, 1.0);
        gl_Layer = gl_InvocationID;
        gs_out.layer = gl_InvocationID;
        EmitVertex();
    }
    EndPrimitive();
}
