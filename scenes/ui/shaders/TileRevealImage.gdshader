shader_type canvas_item;

uniform sampler2D image;
uniform vec2 uv_offset = vec2(0.0);
uniform vec2 uv_scale = vec2(1.0);

void fragment() {
	vec2 uv = uv_offset + UV * uv_scale;
	COLOR = texture(image, uv);
}
