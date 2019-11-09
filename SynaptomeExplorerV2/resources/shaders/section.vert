#version 330 core

#include "section.glsl"

layout(location = 0) in vec2 in_position;

uniform mat4 g_ModelViewProjection;
uniform ivec2 g_MtDims;
uniform int g_SectionAxis = 0;
uniform float g_AxisOffset = 0.0;
uniform vec2 g_Flip = vec2(0.0);
uniform vec3 g_LocalOffsets = vec3(0.0);
uniform vec2 g_LocalScales = vec2(1.0);

out vec2 uv;
out vec2 mtcoords;

// Flip THEN scale THEN offset to convert from 2d to 3d

void main()
{
    section_calc_coords( in_position, g_ModelViewProjection, vec2(g_MtDims), g_LocalScales, g_LocalOffsets, g_SectionAxis, g_AxisOffset, g_Flip, mtcoords, uv, gl_Position);
}