// The geometry is called twice with the vertices of the 2 triangles of a quad.
// Note: We can use `gl_InvocationID` instead of an outer for-loop
layout (triangles) in;
layout (triangle_strip, max_vertices = 18) out;

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

// OpenGL 4.2 or earlier, the built-in variable `gl_Layer` must be passed as a
// user-defined variable.
// The special built-in input variable `gl_in` is an array containing built-in
// outputs that are available in the previous (vertex or tessellation) stage.
// It is implicit declared as an array. Refer 561 (OGL 8)
void main()
{
    // 6 layers
    for (int face = 0; face < 6; ++face) {
        gl_Layer = face;
        for (int i=0; i<gl_in.length(); ++i) {
            gs_out.position = gs_in[i].position;
            gl_Position = vec4(gs_out.position, 1.0);
            gs_out.layer = face;
            EmitVertex();
        }
        EndPrimitive();
    }
}
