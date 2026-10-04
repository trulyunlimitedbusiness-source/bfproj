shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_nearest;

// Palette Defaults (Red/Pink Palette)
uniform vec4 bottom_color : source_color = vec4(0.24, 0.05, 0.05, 1.0); // Dark Crimson Base
uniform vec4 middle_color : source_color = vec4(0.91, 0.28, 0.32, 1.0); // Coral Red Body
uniform vec4 top_color    : source_color = vec4(0.98, 0.82, 0.84, 1.0); // Light Pinkish-White Tips

uniform float fire_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec2 fire_speed = vec2(0.0, 2.0);
uniform float fire_aperture : hint_range(0.0, 3.0) = 0.22;

// Curvature & Edge Controls
uniform float top_curve : hint_range(0.0, 2.0) = 0.5; // Controls the downward arc at the top edges
uniform float edge_fade_margin : hint_range(0.01, 0.5) = 0.1;

// Horizontal repetition across wide bars
uniform float horizontal_scale : hint_range(0.1, 10.0) = 4.0;

// Set higher default (256.0 = very subtle pixelation). Slide up to 512.0+ for even smoother flames.
uniform float pixel_grid_size : hint_range(32.0, 1024.0, 1.0) = 256.0;
uniform bool enable_pixelation = true;

vec4 tri_color_mix(vec4 color1, vec4 color2, vec4 color3, float pos) {
    pos = clamp(pos, 0.0, 1.0);
    if (pos < 0.5) {
        return mix(color1, color2, pos * 2.0);
    } else {
        return mix(color2, color3, (pos - 0.5) * 2.0);
    }
}

void fragment() {
    // 1. High-resolution UV grid snapping for fine pixel detail
    vec2 work_uv = UV;
    if (enable_pixelation) {
        work_uv = floor(UV * pixel_grid_size) / pixel_grid_size;
    }

    // 2. Scale horizontal UV.x independently across long bar length
    vec2 base_uv = vec2(work_uv.x * horizontal_scale, work_uv.y);
    
    // 3. Dual-layer scrolling noise
    vec2 shifted_uv1 = base_uv + TIME * fire_speed;
    vec2 shifted_uv2 = base_uv + TIME * fire_speed * 1.5;
    
    float fire_noise1 = texture(noise_tex, shifted_uv1).r;
    float fire_noise2 = texture(noise_tex, shifted_uv2).r;
    float combined_noise = (fire_noise1 + fire_noise2) * 0.5;
    
    // 4. Fire shape calculation
    float noise = work_uv.y * (((work_uv.y + fire_aperture) * combined_noise - fire_aperture) * 75.0);
    
    // 5. Horizontal wave movement
    noise += sin(base_uv.x * 4.0 + work_uv.y * 10.0 + TIME * 2.0) * 0.1;

    // --- 6. TOP CURVE SHAPING ---
    // Calculates a parabolic curve centered at x = 0.5 that suppresses height near the left/right corners
    float x_offset = UV.x - 0.5;
    float curve_mask = x_offset * x_offset * 4.0 * top_curve;
    noise -= curve_mask;
    
    // --- 7. EDGE SMOOTHING ---
    float side_fade = smoothstep(0.0, edge_fade_margin, UV.x) * smoothstep(1.0, 1.0 - edge_fade_margin, UV.x);
    noise *= side_fade;
    
    // 8. Calculate gradient position & mix colors
    float gradient_pos = clamp(noise * 0.08, 0.0, 1.0);
    vec4 fire_color = tri_color_mix(bottom_color, middle_color, top_color, gradient_pos);
    
    // 9. Output final pixels and alpha cutoff
    float calculated_alpha = clamp(noise, 0.0, 1.0) * fire_alpha;

    if (calculated_alpha > 0.05) {
        COLOR = fire_color;
        COLOR.a = calculated_alpha;
    } else {
        discard;
    }
}
