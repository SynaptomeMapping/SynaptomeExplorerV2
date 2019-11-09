#version 420 core

out vec4 color;
in vec2 uv;
in vec2 mtcoords;

//#define KS
//#define NATURE

uniform float g_TotalTime;
#ifdef MONTAGE
uniform sampler2D g_Montage;
#else // sparse
uniform sampler2DArray g_SparseTexture;
uniform int g_BigTileSize;
uniform ivec2 g_BigTileNum;
#endif
uniform float g_ShowMaskOutlines = 1.0;
uniform float g_DiscardAreasOutsideMask = 0.0;
uniform vec4 g_ProteinColorScale = vec4(1.0);
uniform vec4 g_ProteinColorBias = vec4(0.0);

uniform sampler2D g_CorrectionTexture;
uniform bool g_UseCorrectionTexture = false;

#ifdef KS
uniform usamplerBuffer g_KSRemapBuffer;
uniform sampler2D g_KSTexture;
uniform uint g_MaskSelDictId = 0;
uniform int g_KSComponent;
#endif

#include "mask.glsl"

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, vec3(0.0), vec3(1.0)), vec3(c.y));
}

float grid(vec2 val)
{
    float thickness = 0.002;

    float x = fract(val.x);
    x = min(x, 1.0 - x);

    float xdelta = fwidth(x);
    x = smoothstep(x - xdelta, x + xdelta, thickness);

    float y = fract(val.y);
    y = min(y, 1.0 - y);

    float ydelta = fwidth(y);
    y = smoothstep(y - ydelta, y + ydelta, thickness);

    float c =clamp(x + y, 0.0, 1.0);
    return c;
}

void main()
{
#if 1

#ifdef MONTAGE
    vec4 c = texture(g_Montage, uv);
#else
    ivec2 bigtile_idx = ivec2(mtcoords / g_BigTileSize);
    int layer = bigtile_idx.x + g_BigTileNum.x*bigtile_idx.y;
    vec2 tile_offset = (mtcoords - bigtile_idx*g_BigTileSize)/g_BigTileSize;
    vec4 c = texture( g_SparseTexture, vec3(tile_offset,layer));
    //vec4 c = textureLod( g_SparseTexture, vec3(tile_offset,layer),0);
#endif

    vec2 colorScale = g_ProteinColorScale.xy;
    vec2 colorBias = g_ProteinColorBias.xy;
    float correction = 1.0;

    if(g_UseCorrectionTexture)
    {
        vec2 corrCoords = mtcoords / vec2(512.0);
        //corrCoords.y = floor(corrCoords.y) + 1.0 - fract(corrCoords.y); // PUP109
        correction = texture(g_CorrectionTexture, corrCoords ).x * 2.0;
    }
    c.xy = c.xy * correction * colorScale + colorBias;

    c.z = c.x;
    color = c;//vec4(uv,0,1.0);
    uint maskDictId;
    float mask_is_selected = mask_selected(uv, maskDictId);
    color.xyz = mix(color.xyz, vec3(1.0,1.0,0.0), vec3(mask_is_selected));
    
    float outline = mask_outline(uv, true);

#ifdef KS
    if( g_KSComponent < 4)
    {
        uint remappedMaskDictId = texelFetch( g_KSRemapBuffer, int(maskDictId)).x;
        vec4 ksval4 = texelFetch(g_KSTexture, ivec2(remappedMaskDictId, g_MaskSelDictId),0);
        float ksval = ksval4[g_KSComponent];//pow(ksval4.y,10.0);
        color.xyz = min(remappedMaskDictId , g_MaskSelDictId) != 0 ? hsv2rgb(vec3(0.66 - ksval*0.66,1.0,1.0)) : color.xyz;
        //color = min(maskDictId , g_MaskSelDictId) != 0 ? vec4(hsv2rgb(vec3(1.0, ksval,ksval)),1.0) : vec4(0.0);
        
        /*
            ... also mess with the outline. Light up the pixels that are on the border of hovered:
                gathered should contain mask id
                gathered should not just contain mask id
        */
        #if 0
        vec2 maskTexStep = 1.0 / vec2(textureSize(g_MaskTexture,0).xy);
        uvec4 gathered = textureGather( g_MaskTexture, uv);
        bvec4 gathered_are_selected = equal( uvec4(g_MaskSelDictId), gathered);
        outline = (any(gathered_are_selected) && (!all(gathered_are_selected))) ? 1.0 : 0.0;
        #endif
    }
#endif

    color.xyz = mix(color.xyz, vec3(1.0), vec3(g_ShowMaskOutlines * outline));
    if( g_DiscardAreasOutsideMask*(1.0 - mask_is_selected) == 1.0 )
        discard;
    //color.xyz = vec3(correction) * 0.5;
    
    float lum = dot( vec3(0.2126,0.7152,0.0722), color.xyz);
    color.a = smoothstep(0.0,0.22,lum);

#ifdef NATURE

#if 1
    float lum = dot( vec3(0.2126,0.7152,0.0722), color.xyz);
    //lum = pow(lum,0.4);
    lum = 1.0 - lum;
    lum = max( pow(lum,5.0),0.0);
    //lum = 0.5*smoothstep(0.5,0.6,lum);
    //lum = 0.998;
    float gridval = grid(mtcoords / 512.0);
    lum = mix(lum, 0.0, gridval);

    //lum = floor(lum*10.0)/10.0;
    //color.xyz = vec3(lum*lum*lum,lum*lum, lum);
    color.a = 1.0;
    color.xyz = vec3(lum);
#else // try grid lines
    float gridval = grid(mtcoords / 512.0);
    color.xyz = mix(color.xyz, vec3(1.0), gridval);
    //color.xyz = vec3(1.0);
    //color.a = 1.0;
#endif
#endif


    //ivec2 modv = ivec2(mtcoords) & 511;
    //if( modv.x < 1 || modv.y < 1)
    //    color = vec4(1,1,1,1);
    
    //color *= 5.0;
#else
    color = vec4(uv,1,1.0);
#endif
} 