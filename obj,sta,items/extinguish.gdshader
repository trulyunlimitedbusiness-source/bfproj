shader_type canvas_item;

// 🔒 CLEAN BINARY GATE: 0.0 = Fully operational color | 1.0 = Dark Cooldown mode
uniform float dark_cooldown_factor = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Smoothly blend the native sprite colors down to a dark industrial shadow blue when active
    vec3 dark_shadow = tex_color.rgb * vec3(0.2, 0.25, 0.35);
    
    COLOR = vec4(mix(tex_color.rgb, dark_shadow, dark_cooldown_factor), tex_color.a);
}
