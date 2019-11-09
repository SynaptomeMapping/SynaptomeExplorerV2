#version 400

#include "section.glsl"

layout(location = 0) in vec2 in_position;

uniform mat4 g_ModelViewProjection;
uniform ivec2 g_MtDims;
uniform int g_SectionAxis = 0;
uniform float g_AxisOffset = 0.0;
uniform vec2 g_Flip = vec2(0.0);
uniform vec3 g_LocalOffsets = vec3(0.0);
uniform vec2 g_LocalScales = vec2(1.0);

uniform isamplerBuffer g_StatsBuffer;
uniform int g_HistogramBins; 
uniform int g_PixelBinSize;

uniform vec2 g_DensityRange;
uniform vec2 g_IntensityRange;
uniform vec2 g_AreaRange;

uniform float g_TotalTime = 0.5;

/*
    Display mode mirrors the enum:
        AvgIntensity=0,
        AvgArea,
        Density,
        HistogramIntensity,
        HistogramArea

*/
uniform int g_DisplayMode;

flat out int bufferOffset;
flat out uvec3 accums;
flat out float area_percent_denom;
out vec2 uv;
out vec3 avg_color;

uniform vec3 subtypeColors[38] = vec3[38](
vec3(0, 0, 0),
vec3(0, 0, 1),
vec3(1, 0, 0),
vec3(0, 1, 0),
vec3(1, 0.103448275862069, 0.724137931034483),
vec3(1, 0.827586206896552, 0),
vec3(0, 0.517241379310345, 0.965517241379310),
vec3(0, 0.551724137931035, 0.275862068965517),
vec3(0.655172413793103, 0.379310344827586, 0.241379310344828),
vec3(0.310344827586207, 0, 0.413793103448276),
vec3(0, 1, 0.965517241379310),
vec3(0.241379310344828, 0.482758620689655, 0.551724137931035),
vec3(0.931034482758621, 0.655172413793103, 1),
vec3(0.827586206896552, 1, 0.586206896551724),
vec3(0.724137931034483, 0.310344827586207, 1),
vec3(0.896551724137931, 0.103448275862069, 0.344827586206897),
vec3(0.517241379310345, 0.517241379310345, 0),
vec3(0, 1, 0.586206896551724),
vec3(0.379310344827586, 0, 0.172413793103448),
vec3(0.965517241379310, 0.517241379310345, 0.0689655172413793),
vec3(0.793103448275862, 1, 0),
vec3(0.172413793103448, 0.241379310344828, 0),
vec3(0, 0.206896551724138, 0.758620689655172),
vec3(1, 0.793103448275862, 0.517241379310345),
vec3(0, 0.172413793103448, 0.379310344827586),
vec3(0.620689655172414, 0.448275862068966, 0.551724137931035),
vec3(0.310344827586207, 0.724137931034483, 0.0689655172413793),
vec3(0.620689655172414, 0.758620689655172, 1),
vec3(0.586206896551724, 0.620689655172414, 0.482758620689655),
vec3(1, 0.482758620689655, 0.689655172413793),
vec3(0.620689655172414, 0.0344827586206897, 0),
vec3(1, 0.724137931034483, 0.724137931034483),
vec3(0.517241379310345, 0.379310344827586, 0.793103448275862),
vec3(0.620689655172414, 0, 0.448275862068966),
vec3(0.517241379310345, 0.862068965517241, 0.655172413793103),
vec3(1, 0, 0.965517241379310),
vec3(0, 0.827586206896552, 1),
vec3(1, 0.448275862068966, 0.344827586206897));


int stats_stride(int bins)
{
    return bins*2 + 7;
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, vec3(0.0), vec3(1.0)), vec3(c.y));
}

vec3 heatmap( float value)
{
    return hsv2rgb(vec3((1.0-value)*0.66,1.0, 1.0));
}

float colormap_red(float x) {
    return 1.448953446096850 * x - 5.02253539008443e-1;
}

float colormap_green(float x) {
    return 1.889376646180860 * x - 2.272028094820020e2;
}

float colormap_blue(float x) {
    return 3.92613636363636 * x - 7.46528409090909e+2;
}

vec3 heatmap2(float x) {
    float t = x * 255.0;
    float r = clamp(colormap_red(t) / 255.0, 0.0, 1.0);
    float g = clamp(colormap_green(t) / 255.0, 0.0, 1.0);
    float b = clamp(colormap_blue(t) / 255.0, 0.0, 1.0);
    return vec3(r, g, b);
}

vec2 rotate2d(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, -s, s, c);
	return m * v;
}

vec2 calc_arrow_uv( vec2 local_pos, vec2 deriv, float vmin, float vmax)
{
    float angle = atan(deriv.y, deriv.x);
    float scale = (vmax - vmin) / (length(deriv) - vmin);
    vec2 uv = rotate2d(local_pos, angle)*0.5*scale + 0.5;
    uv += vec2(-1,0) * 0.5*sin(4*g_TotalTime);
    return uv;
}

void main()
{
    vec2 local_pos = in_position;

    // stats buffer offset
    int o = stats_stride(g_HistogramBins)*gl_InstanceID;

    // grab non-vector bin values
    vec2 start_position = vec2( texelFetch(g_StatsBuffer,o+0).x, texelFetch(g_StatsBuffer,o+1).x );
    int puncta_num = texelFetch(g_StatsBuffer,o+2).x;
    accums.x = texelFetch(g_StatsBuffer,o+3).x;
    accums.y = texelFetch(g_StatsBuffer,o+4).x;
    accums.z = uint(puncta_num);
    area_percent_denom = intBitsToFloat(texelFetch(g_StatsBuffer,o+5).x);
    int dominantSubtype = texelFetch(g_StatsBuffer,o+6).x;
    bufferOffset = o+7;

    vec2 averages = uintBitsToFloat(accums.xy);
    vec3 intensity_area_density = vec3(averages, float(puncta_num)*area_percent_denom / float(g_PixelBinSize*g_PixelBinSize));
    vec3 iad_min = vec3(g_IntensityRange.x, g_AreaRange.x, g_DensityRange.x);
    vec3 iad_max = vec3(g_IntensityRange.y, g_AreaRange.y, g_DensityRange.y);
    vec3 iad_norm = clamp( (intensity_area_density - iad_min)/(iad_max - iad_min), vec3(0), vec3(1));

    switch(g_DisplayMode)
    {
        case 0: avg_color.xyz = heatmap2( iad_norm.x ); break;
        case 1: avg_color.xyz = heatmap2( iad_norm.y ); break;
        case 2: avg_color.xyz = heatmap2( iad_norm.z ); break;
        case 5: avg_color.xyz = subtypeColors[dominantSubtype]; break;
        default: avg_color = vec3(1,0,0);
    }

    //avg_color = vec3(puncta_num / 1.0);
    //avg_color = vec3(1,0,0);

    uv = local_pos*0.5 + 0.5;
    // pos_in should be the coords of the tile in the space [-1,1]
    vec2 pos_in = ((start_position + float(g_PixelBinSize) * uv) / vec2(g_MtDims))*2.0 - 1.0;
    vec2 uv_tmp; 
    vec2 mtcoords_tmp;
    section_calc_coords( pos_in, g_ModelViewProjection, vec2(g_MtDims), g_LocalScales, g_LocalOffsets, g_SectionAxis, g_AxisOffset, g_Flip, mtcoords_tmp, uv_tmp, gl_Position);
}