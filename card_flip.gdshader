shader_type canvas_item;

// Progression: 0.0 -> 1.0 (Full flip cycle)
uniform float flip_progress : hint_range(0.0, 5.0) = 0.0;

// Resting scale inside the slot cell
uniform float default_scale : hint_range(0.1, 2.0) = 0.85;

void fragment() {
	// Map progress (0 to 1) to radians (0 to PI)
	float angle = flip_progress * 3.14159265;
	
	// Abs(cos) shrinks horizontal width to 0 and stretches it back out
	float horizontal_scale = max(abs(cos(angle)), 0.0001);
	
	// Center UV coordinates around (0.0, 0.0)
	vec2 uv = UV - vec2(0.5);
	
	// Apply horizontal scale reduction only
	uv.x /= (horizontal_scale * default_scale);
	uv.y /= default_scale;
	
	// Shift UV coordinates back to normalized space (0.0 .. 1.0)
	vec2 final_uv = uv + vec2(0.5);
	
	// Discard out-of-bounds pixels as the width collapses
	if (final_uv.x < 0.0 || final_uv.x > 1.0 || final_uv.y < 0.0 || final_uv.y > 1.0) {
		discard;
	}
	
	COLOR = texture(TEXTURE, final_uv);
}
