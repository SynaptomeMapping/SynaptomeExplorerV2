#version 330

// u, v, intensity, radius
in vec4 vars;
in vec4 var_color;
out vec4 out_color;

uniform float g_ColorizeBySubtype = 0.0;

void main()
{
    vec2 pos = gl_PointCoord*2.0 - 1.0;
    float dpos = dot(pos,pos);
    float dpos2 = dpos*dpos;
    if(dpos2 > 1.0)
        discard;
    dpos2 *= dpos2;
    dpos2 *= dpos2;
    dpos = mix(dpos, dpos2, g_ColorizeBySubtype); // for subtype coloring, sharpen the border quite a bit
    out_color = var_color* vars.z * mix( max(1.0 - dpos,0.0), 1.0, 0.55);
    //out_color.a = 1.0;
}
