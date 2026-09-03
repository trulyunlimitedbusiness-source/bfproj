shader_type canvas_item;

// 🎛️ GLOBAL CONTROLLERS (0 = Normal, 1 = Solid Whitish-Pink, >1 = Dissolving Away!)
uniform float flash_modifier : hint_range(0.0, 20.0) = 0.0; 
uniform vec4 flash_color : source_color = vec4(1.0, 0.6, 0.8, 1.0); // Whitish-Pink

void fragment() {
	vec4 current_color = texture(TEXTURE, UV);
	
	// 🎯 YOUR ORIGINAL WORKING FLASH MATH (Keeps your white-pink hit flash perfect!)
	float clamp_flash = clamp(flash_modifier, 0.0, 1.0);
	vec4 flashed_pixel = mix(current_color, vec4(flash_color.rgb, current_color.a), clamp_flash);
	
	// =========================================================================
	// 🔓 THE MATHEMATICAL SHADER DISSOLVE
	// If the flash_modifier goes above 1.0 during our death function, it begins 
	// reducing the transparency alpha channel smoothly down to absolute zero!
	// =========================================================================
	if (flash_modifier > 1.0) {
		flashed_pixel.a *= clamp(1.0 - ((flash_modifier - 1.0) / 10.0), 0.0, 1.0);
	}
	
	COLOR = flashed_pixel;
}