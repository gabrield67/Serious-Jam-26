shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_toon, specular_toon;

uniform sampler2D Color_1D_Timed : source_color, repeat_disable;
uniform float Intensity = 1;
uniform sampler2D Base_Texture : source_color, repeat_disable;

uniform float Light_attenuation = 1.3;
uniform float Shadow_roundness = 1.0;
uniform sampler2D Color_1D_Gradient : source_color, hint_default_black;

uniform vec2 Scale = vec2(1.0,1.0);


void fragment() {

	vec4 n_out6p0 = texture(Color_1D_Timed, vec2(COLOR.g));

	vec3 n_out7p0 = vec3(n_out6p0.xyz) * vec3(Intensity);

	vec4 n_out3p0 = texture(Base_Texture, UV*Scale);


// Output:0
	ALBEDO = n_out7p0;
	ALPHA = n_out3p0.r;
	ALPHA_SCISSOR_THRESHOLD = COLOR.r;


}

void light() {

	float dot_result = dot(NORMAL, LIGHT);
	float add_some_math = (clamp(dot_result, -0.90, 0.90) + 1.0)*0.47*Light_attenuation;
	float fresnel = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), Shadow_roundness);
	float round_cell_shade = clamp(add_some_math,0.04, 0.98) * fresnel;
	vec4 color_1D_gradient = texture(Color_1D_Gradient, vec2(round_cell_shade));
	DIFFUSE_LIGHT = clamp(LIGHT_COLOR * vec3(color_1D_gradient.xyz), vec3(0), vec3(1));

}
