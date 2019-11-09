#version 330

#include "section.glsl"

uniform mat4 g_ModelViewProjection;
uniform ivec2 g_MtDims;
uniform int g_SectionAxis = 0;
uniform float g_AxisOffset = 0.0;
uniform vec2 g_Flip = vec2(0.0,0.0);
uniform vec3 g_LocalOffsets = vec3(0.0);
uniform vec2 g_LocalScales = vec2(1.0);

uniform mat4 g_Projection;
uniform vec2 g_Viewport;

uniform float g_PunctaScale; // think of it as megapixels-per-screen-pixel
uniform float g_PunctaOpacity;
uniform float g_Zoom = 1.0;
uniform samplerBuffer g_PointBuffer;
uniform int g_BufferOffset = 0;

uniform int g_RenderMode = 0;
uniform vec4 g_FilterLow1;
uniform vec4 g_FilterLow2;
uniform vec4 g_FilterHigh1;
uniform vec4 g_FilterHigh2;
uniform uvec4 g_FilterAreaColocSubtypeProteinLow;
uniform uvec4 g_FilterAreaColocSubtypeProteinHigh;

uniform vec3 g_ProteinColors[2];

//#define YOKOGAWA_DATA


uniform uvec4 g_TypeAndSubtypeMask = uvec4(0xffffffff);

#ifdef YOKOGAWA_DATA
uniform uint g_FilterIntensityLow;
uniform uint g_FilterIntensityHigh;
uniform float g_FilterZLow;
uniform float g_FilterZHigh;
#else
uniform uvec4 g_FilterIntensityMinMaxMeanLow;
uniform uvec4 g_FilterIntensityMinMaxMeanHigh;
#endif

uniform vec4 g_ProteinColorScale = vec4(1.0);
uniform vec4 g_ProteinColorBias = vec4(0.0);
uniform float g_SubtypeColorScale = 1.0;

uniform float g_ColorizeBySubtype = 0.0;
uniform float g_ColorizeByType = 0.0;

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

uniform vec3 typeColors[3] = vec3[3]( 
    vec3(143, 187, 124)/255.0,
    vec3(164, 108, 164)/255.0,
    vec3(232, 185, 103)/255.0
);

out vec4 vars;
out vec4 var_color;


struct punctum_t
{
#ifdef YOKOGAWA_DATA
    float z;
    uint intensity;
#else
    uvec4 intensity_min_max_mean;
#endif
    uvec4 area_coloc_subtype_protein;
    vec4 stddev_circ_skew_kurt;
    vec4 ar_roundness_solidity_coloc;
    uvec2 pos;
};

#define CHECK_BIT(var,pos) ((var) & (1u<<(pos)))
bool CheckTypeAndSubtype( uint type, uint subtype0)
{
    uint t = g_TypeAndSubtypeMask.x & (1u << type);
    //return t > 0;
    // The first 32 subtypes are in .y component, the rest 5 are in .z component
    uint st = g_TypeAndSubtypeMask[1u + (subtype0 >> 5u)] & (1u << (subtype0 & 31u));
    return (subtype0 == 0xffffffffu) || (min(t,st) > 0u); // the 0xffffffff check is for when we don't have subtype in data ( == 0, then deduct 1 in do_render)
}

bool do_render(in punctum_t p)
{   
    //return true;
    //return all(greaterThanEqual(p.stddev_circ_skew_kurt, g_FilterLow1)) &&
    //all(lessThanEqual(p.stddev_circ_skew_kurt, g_FilterHigh1)) &&
    //all(greaterThanEqual(p.ar_roundness_solidity_coloc.xyz, g_FilterLow2.xyz)) &&
    //all(lessThanEqual(p.ar_roundness_solidity_coloc.xyz, g_FilterHigh2.xyz));

    return CheckTypeAndSubtype(p.area_coloc_subtype_protein.w, p.area_coloc_subtype_protein.z-1u) && all(greaterThanEqual(p.stddev_circ_skew_kurt, g_FilterLow1)) &&
    all(lessThanEqual(p.stddev_circ_skew_kurt, g_FilterHigh1)) &&
    all(greaterThanEqual(p.ar_roundness_solidity_coloc, g_FilterLow2)) &&
    all(lessThanEqual(p.ar_roundness_solidity_coloc, g_FilterHigh2)) &&
#ifdef YOKOGAWA_DATA
    (p.intensity >= g_FilterIntensityLow && p.intensity <= g_FilterIntensityHigh) &&
    (p.z >= g_FilterZLow && p.z <= g_FilterZHigh) &&
#else 
    all(greaterThanEqual(p.intensity_min_max_mean, g_FilterIntensityMinMaxMeanLow)) &&
    all(lessThanEqual(p.intensity_min_max_mean, g_FilterIntensityMinMaxMeanHigh)) &&
#endif
    all(greaterThanEqual(p.area_coloc_subtype_protein, g_FilterAreaColocSubtypeProteinLow)) &&
    all(lessThanEqual(p.area_coloc_subtype_protein, g_FilterAreaColocSubtypeProteinHigh));
}

void parse_punctum(out punctum_t p, int offset)
{
    int off = (offset + g_BufferOffset)*3;
    
    vec4 v0f = texelFetch(g_PointBuffer, off + 0);
    uvec4 v0 = floatBitsToUint(v0f);
    p.stddev_circ_skew_kurt = texelFetch(g_PointBuffer, off + 1);
    p.ar_roundness_solidity_coloc = texelFetch(g_PointBuffer, off + 2);

    p.pos = uvec2(ivec2(v0.xy));// + 2*g_PunctaOffsets[int(p.ar_roundness_solidity_coloc.z)]);

#ifdef YOKOGAWA_DATA
    p.z = v0f.z;
    p.intensity = v0.w & 65535u;
#else
    p.intensity_min_max_mean.x = v0.z & 65535u;
    p.intensity_min_max_mean.y = v0.z >> 16u;
    p.intensity_min_max_mean.z = v0.w & 65535u;
#endif
    p.area_coloc_subtype_protein.x = (v0.w >> 16u) & 127u; // 7 bits
    p.area_coloc_subtype_protein.y = (v0.w >> 23u) & 1u; // 1 bits
    p.area_coloc_subtype_protein.z = (v0.w >> 24u) & 63u; // 6 bits
    p.area_coloc_subtype_protein.w = (v0.w >> 30u) & 3u; // 2 bits
    
#if 0 // found grid_ind bug using this. 
    // This is getting weirder. For the test melissa dataset, it looks like SAP behaves right with the below enabled, while PSD95 with the below disabled. Does that mean that the order in the text files can vary and I need to detect it? Would I detect it via the "filename" instead of the grid index?
    if(p.area_coloc_subtype_protein.w == 0u)
    {
        uvec2 off256 = p.pos & 255u;
        uvec2 grididx = (p.pos >> 8u) & 1u;
        //grididx.x = 1u - grididx.x;
        grididx.xy = grididx.yx;
        p.pos = ((p.pos >> 9u) << 9u) + (grididx.xy << 8u) + off256;
    }
#endif
}

void main()
{
    
    vec2 in_position = vec2(0.0);
    int punctumId = gl_VertexID;
    
    vec2 pos = in_position;
    vars.xy = in_position;

    punctum_t p;
    parse_punctum(p, punctumId);
    vec2 position = vec2(p.pos);
    //position.x -= 512.0;

    if(!do_render(p))
    {
        gl_Position = vec4(0.0);
        return;
    }

    float radius = sqrt(float(p.area_coloc_subtype_protein.x) / 3.14159);

    //float scale = 0.5*float( p.area_coloc_subtype_protein.x) ;//radius / min( g_Zoom, 1.0);
    float scale = radius * g_PunctaScale;
    

    // multiply intensity by 2 to match raw!
#ifdef YOKOGAWA_DATA
    vars.zw = vec2(2.0 * float(p.intensity) / 65535.0, radius);
    vars.z = mix(vars.z, 1.0, g_ColorizeBySubtype);
#else
    vars.zw = vec2(2.0 * float(p.intensity_min_max_mean.z) / 65535.0, radius);
#endif 
    uint subtype = p.area_coloc_subtype_protein.z;
    uint uprotein = p.area_coloc_subtype_protein.w;
    float protein = float(uprotein);
    //vec4 proteinColor = vec4(1-protein, protein,1-protein,0.0);
    vec4 proteinColor = vec4( g_ProteinColors[uprotein], 0.0);
    proteinColor.xyz *= g_ProteinColorScale[uprotein];
    proteinColor.xyz += vec3(g_ProteinColorBias[uprotein]);

    int typeIdx = subtype <= 11u ? 0 : (subtype <= 18u ? 1 : 2);
    vec3 subtypeCol = mix(subtypeColors[subtype], typeColors[typeIdx], g_ColorizeByType);    

    proteinColor.xyz = mix(proteinColor.xyz, subtypeCol* g_SubtypeColorScale, g_ColorizeBySubtype);

    vec2 uv_tmp; 
    vec2 mtcoords_tmp;
    vec2 pos_in = (vec2(p.pos) / vec2(g_MtDims))*2.0 - 1.0;
    section_calc_coords( pos_in, g_ModelViewProjection, vec2(g_MtDims), g_LocalScales, g_LocalOffsets, g_SectionAxis, g_AxisOffset, g_Flip, mtcoords_tmp, uv_tmp, gl_Position);
    
    // if real point size < 1, then adjust opacity. NOT FOR SUBTYPES
    float opacity = g_PunctaOpacity;
    float pointSize =  g_Viewport.y * g_Projection[1][1] * scale / gl_Position.w;
    gl_PointSize = pointSize;
    opacity *= max( min(pointSize, 1.0), g_ColorizeBySubtype); 
    var_color = opacity * proteinColor;

    if(g_ColorizeBySubtype > 0.0 && subtype == 0u) 
        var_color.xyz = vec3(0.0);
}