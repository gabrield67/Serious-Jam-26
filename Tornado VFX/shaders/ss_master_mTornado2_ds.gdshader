shader_type spatial;
render_mode unshaded, cull_disabled;

// Vertex Displacement
uniform sampler2D displacement_tex : source_color, repeat_enable;
uniform sampler2D substract_tex : source_color, repeat_disable, hint_default_black;
uniform sampler2D multiply_vertex : source_color, repeat_disable, hint_default_white;
uniform sampler2D Color_1D_Gradient : source_color, repeat_disable, hint_default_white;
uniform float displacement_strength = 0.5;
uniform vec2 texture_pan_speed = vec2(0.1, 0.2);
uniform vec2 scale_disp_texture = vec2(1.0, 1.0);
uniform vec2 col_texture_pan_speed = vec2(0.1, 0.2);
uniform float height_influence = 1.0; // 0=even displacement, 1=more displacement at top
uniform vec2 scale_tex = vec2(1.0,1.0);

// Visual Appearance
uniform sampler2D albedo_tex : source_color;
uniform vec4 base_color : source_color = vec4(1.0);

uniform float fresnel_pow = 1.0;
uniform bool fresnel_invert = false;

uniform sampler2D Alpha_Mask : source_color, repeat_disable, hint_default_white;

uniform float alpha_scisor_treshold:hint_range(0.0, 1.0, 0.01) = 0.5;

void vertex() {
    // Calculate panning UVs
    vec2 displacement_uv = UV*scale_disp_texture + TIME * texture_pan_speed;

    // Sample displacement texture (using red channel)
    float displacement = texture(displacement_tex, displacement_uv).r * texture(multiply_vertex, UV).r;

    // Apply height influence (0=bottom, 1=top)
    float height_factor = mix(1.0, VERTEX.y + 1.0, height_influence);

    // Displace vertices along normals
    VERTEX += NORMAL * displacement * displacement_strength * height_factor;


}

void fragment() {

	// Fresnel:2
	float fresnel = fresnel_invert ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_pow)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_pow));

    // Sample albedo texture with same panning for consistency
    vec2 albedo_uv = (UV*scale_tex) + TIME * col_texture_pan_speed * 0.5;
    float tex_color = (texture(albedo_tex, albedo_uv).r + fresnel) - texture(substract_tex, UV).r;
    tex_color = clamp(tex_color,0.0,1.0);

	vec4 final = texture(Color_1D_Gradient,vec2(tex_color,tex_color));

	float alpha_masked = texture(Alpha_Mask,UV).r;

    // Final color output
    ALBEDO = final.rgb* base_color.rgb;
    ALPHA = final.a - fresnel + alpha_masked -alpha_scisor_treshold ;
	ALPHA_SCISSOR_THRESHOLD = alpha_scisor_treshold;

}