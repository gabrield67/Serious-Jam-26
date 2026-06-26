shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform sampler2D Base_noise : source_color, repeat_enable;
uniform vec2 Speed_XY;
uniform vec2 Scale_XY = vec2(1.000000, 1.000000);
uniform sampler2D Vertex_Color_1D_Intensity : source_color;
uniform float Vertex_Intensity = 2;
uniform sampler2D Texture_multiply : source_color, hint_default_black, repeat_disable;
uniform sampler2D Gradient_Color_1D : source_color, repeat_disable;
uniform float Color_Intensity = 1;

// Add new uniforms for wobble and rotation
uniform float Wobble_Amount = 0.1; // Controls how strong the wobble is
uniform float Wobble_Speed = 1.0;  // Controls how fast the wobble oscillates
uniform float Rotation_Speed = 0.5; // Controls how fast the tornado rotates around Y axis

uniform float Alpha_Scissor: hint_range(0.0, 1.0, 0.1) = 0.5;

void vertex() {
    vec2 n_out9p0 = (UV) * Scale_XY;
    vec2 n_out8p0 = Speed_XY * vec2(TIME) + n_out9p0;
    
    float n_out3p1 = textureLod(Base_noise, n_out8p0, 1.0).r;
    float n_out6p0 = texture(Vertex_Color_1D_Intensity, vec2(n_out3p1)).r * Vertex_Intensity;
    
    // Add wobble effect (sinusoidal movement based on height and time)
    float wobble = sin(TIME * Wobble_Speed + VERTEX.y) * Wobble_Amount;
    
    // Add Y-axis rotation
    float angle = TIME * Rotation_Speed;
    mat2 rotation = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
    
    // Apply rotation to the vertex XZ coordinates
    vec2 rotatedXZ = rotation * VERTEX.xz;
    
    // Combine all effects
    vec3 modifiedVertex = vec3(rotatedXZ.x, VERTEX.y, rotatedXZ.y);
    modifiedVertex += wobble * NORMAL; // Add wobble effect
    
    // Apply the original noise displacement to the modified vertex
    vec3 n_out7p0 = modifiedVertex + vec3(n_out6p0) * NORMAL;
    
    VERTEX = n_out7p0;
}

void fragment() {
    vec2 n_out9p0 = (UV) * Scale_XY;
    vec2 n_out8p0 = Speed_XY * vec2(TIME) + n_out9p0;
    
    float n_out3p1 = texture(Base_noise, n_out8p0).r;
    float n_out6p1 = texture(Texture_multiply, UV).r;
    float n_out15p0 = n_out3p1 * n_out6p1;
    
    vec4 n_out18p0 = texture(Gradient_Color_1D, vec2(n_out15p0));
    vec3 n_out19p0 = vec3(n_out18p0.xyz) * vec3(Color_Intensity);
    
    ALBEDO = n_out19p0.rgb;
	ALPHA = n_out18p0.a;
	ALPHA_SCISSOR_THRESHOLD = Alpha_Scissor;
}