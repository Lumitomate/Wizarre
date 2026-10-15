shader_type canvas_item;

// Onde de chaleur autour des objets de boutique : réfraction d'écran.
// Anneau simple qui décale radialement — de façon UNIFORME sur tout le
// pourtour, sans variation angulaire — l'image derrière lui (mirage
// thermique, aucune couleur ajoutée, cf. hint_screen_texture).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// Amplitude de la distorsion (en UV écran)
uniform float force : hint_range(0.0, 0.05) = 0.012;
// Bande annulaire (rayon normalisé du sprite : 0 = centre, 1 = bord)
// — fine et discrète : l'anneau ne vit que sur la périphérie externe
uniform float bande_interieure : hint_range(0.0, 1.0) = 0.70;
uniform float bande_exterieure : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 delta = UV - vec2(0.5);
	float d = length(delta) / 0.5;
	// Bande annulaire fine : montée courte au bord interne, fondu court
	// vers le bord externe. Hors bande : échantillon écran intact =
	// anneau invisible.
	float bande = smoothstep(bande_interieure, bande_interieure + 0.1, d)
			* (1.0 - smoothstep(bande_exterieure - 0.12, bande_exterieure, d));
	// Distorsion radiale uniforme : pas de variation angulaire (cercle
	// simple), juste une respiration douce et commune à tout le pourtour.
	float respiration = 0.7 + 0.3 * sin(TIME * 6.0);
	vec2 radial = normalize(delta + vec2(0.0001));
	vec2 uv_ecran = SCREEN_UV + radial * force * bande * respiration;
	COLOR = vec4(texture(screen_texture, uv_ecran).rgb, 1.0);
}
