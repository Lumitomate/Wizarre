shader_type canvas_item;

// Recolorise le sorcier à partir du sprite commun (variante rouge de
// référence). Les sprites sont du pixel art 32x32 importé sans perte et
// sans anti-aliasing : une correspondance exacte de la palette est donc
// fiable et ne peut pas créer d'artefacts sur les contours.
// Les 4 nuances de la robe (claire -> sombre) restent distinctes.

const vec3 ROBE_SRC_0 = vec3(216.0 / 255.0, 77.0 / 255.0, 77.0 / 255.0); // #d84d4d
const vec3 ROBE_SRC_1 = vec3(172.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0); // #ac3232
const vec3 ROBE_SRC_2 = vec3(137.0 / 255.0, 47.0 / 255.0, 47.0 / 255.0); // #892f2f
const vec3 ROBE_SRC_3 = vec3(101.0 / 255.0, 20.0 / 255.0, 20.0 / 255.0); // #651414
const vec3 EYE_SRC = vec3(95.0 / 255.0, 205.0 / 255.0, 228.0 / 255.0);   // #5fcde4

uniform vec4 robe_color_0 : source_color = vec4(0.847, 0.302, 0.302, 1.0); // rouge clair
uniform vec4 robe_color_1 : source_color = vec4(0.675, 0.196, 0.196, 1.0); // rouge
uniform vec4 robe_color_2 : source_color = vec4(0.537, 0.184, 0.184, 1.0); // rouge sombre
uniform vec4 robe_color_3 : source_color = vec4(0.396, 0.078, 0.078, 1.0); // rouge très sombre
uniform vec4 eye_color : source_color = vec4(0.373, 0.804, 0.894, 1.0);    // #5fcde4

// Hérité de dash_white.gdshader : 0.0 = couleur normale, 1.0 = blanc complet
uniform float white_amount : hint_range(0.0, 1.0) = 0.0;

// Tolérance de comparaison : couvre l'arrondi float du décodage texture,
// tout en restant très en dessous de l'écart entre couleurs de la palette.
const float EPSILON = 0.5 / 255.0;

bool is_color(vec3 c, vec3 reference) {
	return distance(c, reference) < EPSILON;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 col = tex_color.rgb;

	if (is_color(col, ROBE_SRC_0)) {
		col = robe_color_0.rgb;
	} else if (is_color(col, ROBE_SRC_1)) {
		col = robe_color_1.rgb;
	} else if (is_color(col, ROBE_SRC_2)) {
		col = robe_color_2.rgb;
	} else if (is_color(col, ROBE_SRC_3)) {
		col = robe_color_3.rgb;
	} else if (is_color(col, EYE_SRC)) {
		col = eye_color.rgb;
	}

	// Effet dash blanc, appliqué après le recolorisage (comportement identique
	// à l'ancien dash_white.gdshader)
	COLOR = vec4(mix(col, vec3(1.0), white_amount), COLOR.a);
}
