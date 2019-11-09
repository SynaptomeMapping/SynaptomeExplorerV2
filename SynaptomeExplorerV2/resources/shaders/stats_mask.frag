#version 330

uniform int g_HistogramBins; 
uniform int g_DisplayMode;
uniform int g_ShowEmpty = 1;

uniform isamplerBuffer g_StatsBuffer;
uniform isampler2D g_StatsTexture;
uniform vec2 g_DensityRange;
uniform vec2 g_IntensityRange;
uniform vec2 g_AreaRange;

uniform vec2 g_HistMaxFreqsMaskDenom = vec2(1.0/65535.0, 1.0/100.0);

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

in vec2 uv;
in vec3 mtcoords;
out vec4 out_color;

int stats_stride(int bins)
{
    return bins*2 + 5;
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

// cmpi: 0=intensity, 1=area
vec3 histogram_value( int cmpi, int bufferOffset )
{
    int bar = min( int(uv.x * g_HistogramBins), g_HistogramBins-1);
    int freq = texelFetch(g_StatsBuffer,bufferOffset + cmpi*g_HistogramBins + bar).x;
    float freq_percent = freq * g_HistMaxFreqsMaskDenom[cmpi];
    return heatmap(bar / float(g_HistogramBins-1))*step(1.0 - uv.y, freq_percent);
}

void main()
{   
    out_color = vec4(1,0,1,1);
    
    int maskId = texture(g_StatsTexture, uv).x;
    
    if(maskId == -1)
        discard;
    
    int o = stats_stride(g_HistogramBins)*maskId;
    int puncta_num = texelFetch(g_StatsBuffer,o+0).x;
    
    if( puncta_num == 0 && g_ShowEmpty == 0)
        discard;
    
    vec2 averages;
    averages.x = intBitsToFloat(texelFetch(g_StatsBuffer,o+1).x);
    averages.y = intBitsToFloat(texelFetch(g_StatsBuffer,o+2).x);
    float mask_area_denom = intBitsToFloat(texelFetch(g_StatsBuffer,o+3).x);
    int bufferOffset = o+4;
    vec3 intensity_area_density = vec3( averages, float(puncta_num)*mask_area_denom);
    vec3 iad_min = vec3(g_IntensityRange.x, g_AreaRange.x, g_DensityRange.x);
    vec3 iad_max = vec3(g_IntensityRange.y, g_AreaRange.y, g_DensityRange.y);
    vec3 iad_norm = clamp( (intensity_area_density - iad_min)/(iad_max - iad_min), vec3(0), vec3(1));
    
    int dominantSubtype = texelFetch(g_StatsBuffer,o+4).x;
    
    if(puncta_num > 0)
    switch(g_DisplayMode)
    {
        case 3:
        case 0: out_color.xyz = heatmap( iad_norm.x ); break;
        case 4:
        case 1: out_color.xyz = heatmap( iad_norm.y ); break;
        case 2: out_color.xyz = heatmap( iad_norm.z ); break;
        //case 3:
        //case 4:
        //    out_color.xyz = mask_area_denom*histogram_value(g_DisplayMode-3, bufferOffset ); break;
        case 5: out_color.xyz = subtypeColors[dominantSubtype]; break; // TODO: dominant subtype
        default: break;
    }
    
    //out_color.xyz = vec3(float(puncta_num) / 1000000.0);
}
