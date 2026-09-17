shader_type canvas_item;

// Double cerne autour/sur le sprite d'ammo, pulsant lentement (TIME) :
// - cerne EXTÉRIEURE (outer_*) : dessinée sur les pixels transparents
//   autour du sprite ;
// - cerne INTÉRIEURE (inner_*) : dessinée sur le bord du sprite lui-même.

uniform vec4 outer_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outer_width : hint_range(0.0, 12.0) = 8.0;
uniform vec4 inner_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float inner_width : hint_range(0.0, 4.0) = 0.0;

// Intensité minimale et maximale entre lesquelles les cernes pulsent
uniform float intensity_min : hint_range(0.0, 1.0) = 0.15;
uniform float intensity_max : hint_range(0.0, 1.0) = 0.85;
// Vitesse de la pulsation (radians/seconde) : plus grand = plus rapide
uniform float pulse_speed : hint_range(0.1, 10.0) = 1.5;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE;

	// Distance (en px) au pixel opaque le plus proche (pour la cerne
	// extérieure) et au pixel transparent le plus proche (pour la cerne
	// intérieure)
	float dist_to_sprite = 1e6;
	float dist_to_gap = 1e6;
	float max_width = max(inner_width, outer_width);
	int w = int(ceil(max_width));
	for (int x = -w; x <= w; x++) {
		for (int y = -w; y <= w; y++) {
			if (x == 0 && y == 0) {
				continue;
			}
			vec2 offset_px = vec2(float(x), float(y));
			float d = length(offset_px);
			if (d > max_width + 0.5) {
				continue;
			}
			float a = texture(TEXTURE, UV + offset_px * ps).a;
			if (a > 0.01) {
				dist_to_sprite = min(dist_to_sprite, d);
			} else {
				dist_to_gap = min(dist_to_gap, d);
			}
		}
	}

	// Pulsation sinusoïdale lente entre intensity_min et intensity_max,
	// partagée par les 2 cernes
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float amount = mix(intensity_min, intensity_max, pulse);

	// Cerne extérieure : pixels transparents proches du sprite, avec un
	// dégradé d'opacité du bord intérieur de la cerne (opaque, collé au
	// sprite) vers son bord extérieur (transparent)
	float outer_falloff = 1.0 - clamp(dist_to_sprite / (outer_width + 0.5), 0.0, 1.0);
	float outer_mask = (1.0 - step(0.01, tex.a)) * outer_falloff;
	// Cerne intérieure : pixels du sprite proches d'un bord (transparence)
	float inner_mask = step(0.01, tex.a) * step(dist_to_gap, inner_width + 0.5);

	vec3 rgb = mix(tex.rgb, outer_color.rgb, outer_mask * amount);
	rgb = mix(rgb, inner_color.rgb, inner_mask * amount);
	float alpha = max(tex.a, outer_mask * amount);

	COLOR = vec4(rgb, alpha);
}
