#ifndef __SECTION_GLSL__
#define __SECTION_GLSL__

// old-to-new mapping, reflect Coord3D code. "2" is reserved for the axis offset
ivec3 reindex_all[3] = ivec3[3]( 
    ivec3(2, 0, 1), 
    ivec3(0, 2, 1), 
    ivec3(0, 1, 2)
);

void section_calc_coords( in vec2 pos_in, in mat4 mvp, in vec2 mtdims, in vec2 localScales, in vec3 localOffsets, in int sectionAxis, in float axisOffset, in vec2 flip, out vec2 mtcoords_out, out vec2 uv_out, out vec4 sspos_out)
{
    uv_out = pos_in*0.5 + 0.5;
    vec2 in_pos = mix(uv_out, 1.0-uv_out, flip); // in [0,1]
    mtcoords_out = localScales*in_pos* mtdims + localOffsets.xy;
    vec3 pos3d_tmp = vec3(mtcoords_out, axisOffset + localOffsets.z);
    vec3 pos3d;
    ivec3 reindex = reindex_all[sectionAxis];
    //pos3d[ reindex.x ] = pos3d_tmp.x;
    //pos3d[ reindex.y ] = pos3d_tmp.y;
    //pos3d[ reindex.z ] = pos3d_tmp.z;
    pos3d.x = pos3d_tmp[ reindex.x ];
    pos3d.y = pos3d_tmp[ reindex.y ];
    pos3d.z = pos3d_tmp[ reindex.z ];
    sspos_out = mvp* vec4(pos3d,1.0);
    mtcoords_out = uv_out* mtdims; // the mt coords that go to the pixel shader don't use flipping!
}

#endif // __SECTION_GLSL__