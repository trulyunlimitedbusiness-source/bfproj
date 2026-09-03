shader_type canvas_item;

// 🎛️ CINEMATIC RADIAL BORDER CONTROLLERS
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 0.0; // Driven by script (0 = Clear, 1 = Dark Border)
uniform float vignette_softness : hint_range(0.0, 2.0) = 0.45; // Smoothness of the gradient fade boundary
uniform float vignette_radius : hint_range(0.0, 2.0) = 0.15; // Size of the un-obscured safe center zone
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Solid cinematic black (#000000)

void fragment() {
	// 📐 1. Calculate the absolute distance pixel coordinates from the dead center of your monitor (0.5, 0.5)
	vec2 center_distance = UV - vec2(0.5);
	
	// 🧮 2. Compute the radial falloff intensity loop using a smooth vector dot multiplier
	float radial_shadow = dot(center_distance, center_distance);
	
	// 📈 3. Mask out the boundaries smoothly using a smoothstep interpolation gate curve
	float vignette_opacity = smoothstep(vignette_radius, vignette_radius + vignette_softness, radial_shadow);
	
	// 🎬 4. Combine calculations and layer our black mask while respecting our script's alpha_multiplier
	COLOR = vec4(shadow_color.rgb, vignette_opacity * alpha_multiplier);
}