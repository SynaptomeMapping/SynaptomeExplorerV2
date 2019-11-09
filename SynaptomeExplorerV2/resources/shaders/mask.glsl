#ifndef __MASK_GLSL__
#define __MASK_GLSL__

uniform usampler2D g_MaskTexture;
layout (std140, binding = 0) uniform g_MaskDict
{ 
    uvec4 g_MaskDictData[1024];
};

uniform uvec4 g_DelineationSelection;
uniform uvec4 g_DelineationSelectionParent;

float mask_outline(vec2 mask_uv, bool far_away)
{
    vec2 maskTexStep = 1.0 / vec2(textureSize(g_MaskTexture,0).xy);
    uvec4 val = textureGather( g_MaskTexture, mask_uv);
    val.xy ^= val.zw;
    val.x |= val.y;
    
    if( far_away ) // need more samples. remember, we can't use pixel shader specific code
    {
        for(int i=0; i<9;++i)
        {
            int xoff = (i%3)-1;
            int yoff = (i/3)-1;
            uvec4 val2 = textureGather( g_MaskTexture, mask_uv + 0.75*maskTexStep*vec2(xoff,yoff));
            val2.xy ^= val2.zw;
            val2.x |= val2.y;
            val.x |= val2.x;
        }
    }
    
    return val.x != 0u ? 1.0f : 0.0f;
}

uvec4 u128_rs( in uvec4 v_in, in uint num_in)
{
    uvec4 v = v_in;
    uint num = num_in;
    
    if ( num >= 96u)
    {
        num -= 96u;
        v = uvec4(v.w,0,0,0);
    }
    else if( num >= 64u)
    {
        num -= 64u;
        v = uvec4(v.zw,0,0);
    }
    else if( num >= 32u)
    {
        num -= 32u;
        v = uvec4(v.yzw,0);
    }
    
    uint andval = ( 1u << num) - 1u;
    v.x >>= num;
    v.x |= (v.y & andval) << (32u-num);
    v.y >>= num;
    v.y |= (v.z & andval) << (32u-num);
    v.z >>= num;
    v.z |= (v.w & andval) << (32u-num);
    v.w >>= num;
    return v;
}

uvec4 u128_ls( in uvec4 v_in, in uint num_in)
{
    uvec4 v = v_in;
    uint num = num_in;
    
    if ( num >= 96u)
    {
        num -= 96u;
        v = uvec4(0,0,0,v.x);
    }
    else if( num >= 64u)
    {
        num -= 64u;
        v = uvec4(0,0,v.xy);
    }
    else if( num >= 32u)
    {
        num -= 32u;
        v = uvec4(0,v.xyz);
    }
    
    v.w <<= num;
    v.w |= v.z >> (32u-num);
    v.z <<= num;
    v.z |= v.y >> (32u-num);
    v.y <<= num;
    v.y |= v.x >> (32u-num);
    v.x <<= num;
    return v;
}

uint u128_extract( in uvec4 v, in uint off, in uint num)
{
    uvec4 vbase0 = u128_rs( v, off);
    return vbase0.x & (( 1u << num) - 1u);
}

bool mask_contains_mask(in uvec4 parent, in uvec4 child, in uint parentbitoff)
{
    return u128_rs(parent, parentbitoff) == u128_rs(child, parentbitoff);
}

float mask_selected(vec2 mask_uv, out uint maskDictId)
{
    maskDictId = texture( g_MaskTexture, mask_uv).x;
    
    uvec4 maskVal = g_MaskDictData[maskDictId];
    //maskVal = uvec4(571506688,36,0,0);
    /*
        maskMult =1 when the mask value:
            - has g_MaskParent as supergroup 
            - shifted by leveOffset bits and AND'd with levelBits makes an index. use that as bit index in g_MaskLevelSelectionMask
    */
    
    uint children_mask = g_DelineationSelection.x;
    uint children_bitoff = g_DelineationSelection.y;
    uint children_bitcount = g_DelineationSelection.z;
    
    uvec4 maskParent = g_DelineationSelectionParent;
    bool parent_ok = mask_contains_mask( maskParent, maskVal, children_bitoff + children_bitcount);
    //parent_ok = mask_contains_mask( uvec4(0,32,0,0), uvec4(0,46,0,0), 37);// this doesn't work
    //parent_ok = mask_contains_mask( uvec4(40,0,0,0), uvec4(40,0,0,0), 2); // This works
    //parent_ok = (36 >> 5) == (32 >> 5);
    //return parent_ok ? 1.0 : 0.0;
    uint maskIndexInLevel =  u128_extract(maskVal, children_bitoff, children_bitcount);
    float maskMult = float(parent_ok) * float(maskIndexInLevel > 0u ) * float( (children_mask & (1<<(maskIndexInLevel-1u))) > 0u ) * (-1.0); //(sin(g_TotalTime*6.5)*3.0);
    return maskMult;
    
#if 0
    float zval = 0.235;
    uint maskVal = texture( g_MaskTexture, mask_uv).x;
    bool parent_ok = (g_MaskParent >> (g_MaskLevelBitOffset + g_MaskLevelBitCount)) == (maskVal >> (g_MaskLevelBitOffset + g_MaskLevelBitCount));//(g_MaskParent & maskVal) == g_MaskParent;
    uint maskIndexInLevel = (maskVal >> g_MaskLevelBitOffset) & ((1u << g_MaskLevelBitCount)-1u);
    float maskMult = float(parent_ok) * float(maskIndexInLevel > 0u ) * float( (g_MaskLevelSelectionMask & (1<<(maskIndexInLevel-1u))) > 0u ) * (-1.0); //(sin(g_TotalTime*6.5)*3.0);
    float mask_intensity = (zval + g_Minimap*(1.0 - zval))*maskMult;
    return mask_intensity;
#else
    return 0.0;
#endif
}

#endif // __MASK_GLSL__