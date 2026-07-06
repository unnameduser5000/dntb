shader_type canvas_item;

uniform float glow_radius : hint_range(0.0, 64.0) = 12.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float core_brightness : hint_range(0.5, 3.0) = 1.5;

void fragment() {
	vec4 core = COLOR;
	vec2 ps = TEXTURE_PIXEL_SIZE;
	float glow = 0.0;
	float samples = 0.0;
	for (float x = -glow_radius; x <= glow_radius; x += 2.0) {
		for (float y = -glow_radius; y <= glow_radius; y += 2.0) {
			vec2 uv = UV + vec2(x, y) * ps;
			glow += texture(TEXTURE, uv).a;
			samples += 1.0;
		}
	}
	glow = glow / samples * glow_intensity;
	COLOR.rgb = core.rgb * (core.a * core_brightness + glow);
	COLOR.a = min(core.a + glow, 1.0);
}
