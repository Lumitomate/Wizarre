shader_type canvas_item;
render_mode blend_add;

// Lumière de lancement de sort colorée par MASQUE (UV map) : la forme et
// son fondu viennent d'une texture dessinée à la main, en niveaux de
// luminosité.
//
// Règle : plus le pixel du masque est BLANC, plus la lumière est OPAQUE ;
// plus il est FONCÉ, plus elle est TRANSPARENTE. La couleur de la lumière
// suit l'élément du sort (palette des gemmes du HUD) : pixels sombres du
// masque = couleur profonde (halo), pixels clairs = couleur vive (tracé).
//
// La chorégraphie (pop d'échelle, flash blanc, fondu) est pilotée par le
// script cast_shape.gd via les uniforms flash et opacity.

// Le masque de la forme (Carre1 / Triangle1 / Rond), assigné par le script
uniform sampler2D mask : source_color, filter_linear;
uniform vec4 core_color : source_color = vec4(1.0, 0.58, 0.0, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.3, 0.0, 1.0);
// 0.0 = couleurs pures, 1.0 = tracé blanc brûlant (flash d'apparition)
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 m = texture(mask, UV);
	// Luminosité du masque = opacité de la lumière (UV map)
	float b = m.r;
	// Deux tons de la palette : sombre du masque → couleur profonde,
	// clair du masque → couleur vive. Le flash pousse le tout vers le blanc.
	vec3 tint = mix(glow_color.rgb, core_color.rgb, b);
	tint = mix(tint, vec3(1.0), flash);
	COLOR = vec4(tint * opacity, b * opacity);
}
