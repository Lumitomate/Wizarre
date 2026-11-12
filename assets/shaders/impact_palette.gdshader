shader_type canvas_item;

// Recolorise les particules d'explosion d'impact (cf. ImpactExplosion) à
// partir des sprites communs (variante rouge de référence). Même patron
// que wizard_color.gdshader : pixel art importé sans perte et sans
// anti-aliasing.
//
// Deux différences avec une correspondance exacte de palette :
// - chaque pixel coloré est rapproché de la NUANCE LA PLUS PROCHE de la
//   rampe de référence puis remplacé par la nuance correspondante de la
//   rampe cible : couvre les nuances intermédiaires dessinées dans
//   certaines frames (sans ça, des restes de rouge subsistaient sur les
//   explosions d'autres éléments) ;
// - seuls les pixels COLORÉS (saturation suffisante) sont remappés : le
//   blanc du cœur lumineux, les gris et le noir restent inchangés.
//
// Les 4 nuances de chaque rampe sont données du sombre au clair.

// Rampe de référence dessinée dans les sprites (rouge feu) :
const vec3 SRC_0 = vec3(255.0 / 255.0, 0.0 / 255.0, 0.0 / 255.0);    // #ff0000
const vec3 SRC_1 = vec3(255.0 / 255.0, 77.0 / 255.0, 0.0 / 255.0);   // #ff4d00
const vec3 SRC_2 = vec3(255.0 / 255.0, 148.0 / 255.0, 0.0 / 255.0);  // #ff9400
const vec3 SRC_3 = vec3(255.0 / 255.0, 186.0 / 255.0, 0.0 / 255.0);  // #ffba00

uniform vec4 ramp_color_0 : source_color = vec4(1.0, 0.0, 0.0, 1.0);        // ff0000
uniform vec4 ramp_color_1 : source_color = vec4(1.0, 0.302, 0.0, 1.0);      // ff4d00
uniform vec4 ramp_color_2 : source_color = vec4(1.0, 0.58, 0.0, 1.0);       // ff9400
uniform vec4 ramp_color_3 : source_color = vec4(1.0, 0.729, 0.0, 1.0);      // ffba00

// Seuil de saturation en dessous duquel un pixel est considéré « non
// coloré » (blanc, gris, noir) et reste inchangé.
const float SEUIL_SATURATION = 0.15;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 col = tex_color.rgb;

	float saturation = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
	if (saturation > SEUIL_SATURATION) {
		// Nuance de la rampe de référence la plus proche → nuance cible.
		float d0 = distance(col, SRC_0);
		float d1 = distance(col, SRC_1);
		float d2 = distance(col, SRC_2);
		float d3 = distance(col, SRC_3);
		float dmin = min(d0, min(d1, min(d2, d3)));
		if (dmin == d0) {
			col = ramp_color_0.rgb;
		} else if (dmin == d1) {
			col = ramp_color_1.rgb;
		} else if (dmin == d2) {
			col = ramp_color_2.rgb;
		} else {
			col = ramp_color_3.rgb;
		}
	}
	// Patron du projet (cf. wizard_color.gdshader) : la couleur est
	// REMPLACÉE, jamais re-multipliée. En Godot 4, COLOR en entrée du
	// fragment contient déjà texture × modulate — écrire « vec4(col, a) *
	// COLOR » re-multipliait la texture sur elle-même (remappage × source
	// → rendu noir/olive). Le modulate des particules est blanc : le
	// remplacer par tex_color.a ne perd rien ici.
	COLOR = vec4(col, tex_color.a);
}
