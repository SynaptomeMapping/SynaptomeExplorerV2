#version 330

uniform int g_HistogramBins; 
uniform int g_DisplayMode;

uniform isamplerBuffer g_StatsBuffer;

uniform vec2 g_HistMaxFreqsMaskDenom = vec2(1.0/65535.0, 1.0/100.0);

uniform int g_ShowEmpty = 1;

flat in int bufferOffset;
flat in uvec3 accums;
flat in float area_percent_denom;
in vec2 uv;
in vec3 avg_color;
out vec4 out_color;

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

// cmpi: 0=intensity, 1=area
vec3 histogram_value( int cmpi )
{
    int bar = min( int(uv.x * g_HistogramBins), g_HistogramBins-1);
    int freq = texelFetch(g_StatsBuffer,bufferOffset + cmpi*g_HistogramBins + bar).x;
    float freq_percent = freq * g_HistMaxFreqsMaskDenom[cmpi];
    return heatmap2(bar / float(g_HistogramBins-1))*step(1.0 - uv.y, freq_percent);
}

void main()
{   
    out_color = vec4(1,0,1,1);
    if(accums.z != 0u)
    {
        out_color.w = sign(accums.z);
        switch(g_DisplayMode)
        {
            case 5: 
            case 0: 
            case 1: 
            case 2: out_color.xyz = avg_color; break;
            case 3:
            case 4:
                out_color.xyz = area_percent_denom*histogram_value(g_DisplayMode-3 ); break;
            default: break;
        }
    }
    else if(g_ShowEmpty == 0)
        discard;
}
