shader_type canvas_item;

// 🎛️ GLOBAL RENDERING HOOKS (DRIVEN BY CAMERA GDSCRIPT)
uniform vec2 center = vec2(0.5, 0.5);   // The absolute screen UV focal point center of the blast
uniform float force = 0.0;             // How violently the screen pixels warp and zoom outward
uniform float size = 0.0;              // The expanding outer radius footprint boundary circle of the ring
uniform float thickness = 0.05;        // How wide the ripple wave edge blur is

// 📺 GODOT 4 FIXED SCREEN BUFFER ACCESSIBILITY REFERENCE
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Grab the raw, undistorted screen pixel UV texture grid coordinates
	vec2 uv = SCREEN_UV;
	
	// Calculate the raw mathematical distance from the current pixel to the explosion center point
	float current_dist = distance(uv, center);
	
	// If the active pixel falls directly inside our expanding wave ring track, warp its coordinate space!
	if (current_dist <= size && current_dist >= size - thickness) {
		float filter_weight = (1.0 - (size - current_dist) / thickness);
		float wave_sin_multiplier = sin(filter_weight * 3.1415926);
		
		// Calculate the direct directional vector pointing outward away from the center core
		vec2 text_direction = normalize(uv - center);
		
		// Shift the UV coordinate backward along the vector axis line to generate the zoom ripple warping look!
		uv += text_direction * force * wave_sin_multiplier;
	}
	
	// Output the final warped pixels cleanly onto your monitor layout view using the Godot 4 sampler!
	COLOR = texture(screen_texture, uv);
}