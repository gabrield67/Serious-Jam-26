shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform sampler2D texture_atlas;
uniform vec2 atlas_dimensions = vec2(2.0, 2.0);

uniform vec2 Texture_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Disolver_Texture : source_color;

uniform vec4 Color_parameter : source_color;

void vertex() {
    // Use COLOR.r as our random value (0-1)
    float random_value = COLOR.r;

    // Calculate tile index (0 to total_tiles-1)
    float total_tiles = atlas_dimensions.x * atlas_dimensions.y;
    float tile_index = floor(random_value * total_tiles);
    // Ensure we stay within bounds
    tile_index = clamp(tile_index, 0.0, total_tiles - 1.0);

    // Calculate tile coordinates (x,y) in the atlas grid
    float tile_x = mod(tile_index, atlas_dimensions.x);
    float tile_y = floor(tile_index / atlas_dimensions.x);

    // Calculate UV mapping for the selected tile
    vec2 tile_size = 1.0 / atlas_dimensions;
    vec2 tile_offset = vec2(tile_x, tile_y) * tile_size;

    // Adjust UVs to sample from the correct tile
    UV = tile_offset + UV * tile_size;
}

void fragment() {

	vec2 disolv_offset = (UV) * Texture_Scale;

	float erosion = texture(Disolver_Texture, disolv_offset).r;

    vec4 tex = texture(texture_atlas, UV);

    ALBEDO = Color_parameter.rgb;
	ALPHA = erosion * tex.r;
	ALPHA_SCISSOR_THRESHOLD = COLOR.a;
}