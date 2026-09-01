shader_type canvas_item;

// 0.0 = couleur normale, 1.0 = blanc complet
uniform float white_amount : hint_range(0.0, 1.0) = 0.0;

uniform float dash_alpha : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 white_mix = mix(tex_color.rgb, vec3(1.0, 1.0, 1.0), white_amount);
	COLOR = vec4(white_mix, tex_color.a);
}