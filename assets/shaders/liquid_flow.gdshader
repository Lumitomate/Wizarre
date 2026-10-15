shader_type canvas_item;

/** Progression du front de remplissage : 0.0 = départ de l'impact, 1.0 = vague entièrement passée. */
uniform float flow_front : hint_range(0.0, 1.0) = 0.0;
/** Progression du front de retrait : part de l'impact comme le remplissage,
chaque pixel s'estompe PROGRESSIVEMENT pendant que le front le traverse. */
uniform float fade_front : hint_range(0.0, 1.0) = 0.0;
/** Point d'impact en UV de la texture (fixé par le script au moment du tir). */
uniform vec2 hit_uv = vec2(-1.0);
/** Rayon de l'onde en pixels, COMMUN à toutes les lettres (fixé par le
script) : la vague avance à la même vitesse en px/s sur chaque lettre. */
uniform float wave_radius_px = 120.0;
/** Épaisseur de la bande de fondu derrière le front de retrait (px) :
plus elle est large, plus chaque pixel met de temps à s'estomper. */
uniform float fade_band_px = 240.0;
/** Taille de la texture en pixels, fournie par le script (chaque lettre a sa taille). */
uniform vec2 texture_size = vec2(72.0, 88.0);

const vec3 CHANNEL_RED = vec3(77.0 / 255.0, 23.0 / 255.0, 23.0 / 255.0);      // #4d1717 : les canaux -> blanc
const vec3 EDGE_RED = vec3(112.0 / 255.0, 24.0 / 255.0, 24.0 / 255.0);       // #701818 : autour des canaux -> #d84d4d
const vec3 HALO_RED = vec3(216.0 / 255.0, 77.0 / 255.0, 77.0 / 255.0);       // #d84d4d
const vec3 LIQUID_WHITE = vec3(1.0);

/** Tolérance : pixel art importé sans perte, correspondance exacte fiable. */
const float EPSILON = 0.5 / 255.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	float dist = distance(UV * texture_size, hit_uv * texture_size);

	// Onde de remplissage : 1.0 derrière le front qui avance depuis l'impact.
	float filled = smoothstep(-1.0, 1.0, flow_front * wave_radius_px - dist);

	// Onde de retrait : le front balaie la lettre depuis l'impact. Un pixel
	// reste plein tant que le front n'est pas arrivé, puis s'estompe
	// PROGRESSIVEMENT pendant que le front parcourt la bande de fondu.
	// Le front parcourt radius + bande pour tout effacer jusqu'aux coins.
	float drain_px = fade_front * (wave_radius_px + fade_band_px);
	float visible = 1.0 - smoothstep(dist, dist + fade_band_px, drain_px);
	float strength = filled * visible;

	// Canal #4d1717 : blanc une fois la vague passée ; #701818 autour des
	// canaux : #d84d4d ; tous les autres pixels : inchangés.
	if (distance(tex.rgb, CHANNEL_RED) < EPSILON) {
		COLOR = vec4(mix(tex.rgb, LIQUID_WHITE, strength), tex.a);
	} else if (distance(tex.rgb, EDGE_RED) < EPSILON) {
		COLOR = vec4(mix(tex.rgb, HALO_RED, strength), tex.a);
	} else {
		COLOR = tex;
	}
}
