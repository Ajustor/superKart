shader_type canvas_item;

// Par-dessus la course, sous le HUD : un léger assombrissement des coins
// (vignette), qui ramène l'œil vers la route, et des traits de vitesse qui
// filent vers les bords pendant un turbo. Rien n'est lu à l'écran : tout se
// calcule au pixel, le coût reste celui d'un rectangle transparent.

uniform float vignette : hint_range(0.0, 1.0) = 0.3;
// De 0 à 1 : la force du turbo en cours.
uniform float turbo : hint_range(0.0, 1.0) = 0.0;
// Largeur sur hauteur de l'écran, pour une vignette ronde.
uniform float rapport = 1.7778;

float hasard(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 c = UV - 0.5;
	c.x *= rapport;
	float r = length(c);
	float sombre = smoothstep(0.45, 1.05, r) * vignette;

	// Des rayons : l'angle découpé en fines tranches, une sur huit allumée,
	// chacune avec ses traits qui partent du centre vers le bord.
	float angle = atan(c.y, c.x);
	float tranche = floor((angle + PI) * 70.0);
	float allumee = step(0.86, hasard(tranche));
	float trait = fract(r * 2.5 - TIME * (3.0 + 2.0 * hasard(tranche + 7.0)) + hasard(tranche + 3.0));
	float ligne = allumee * smoothstep(0.0, 0.25, trait) * (1.0 - smoothstep(0.35, 0.6, trait));
	ligne *= smoothstep(0.32, 0.75, r) * turbo * 0.55;

	float alpha = ligne + sombre * (1.0 - ligne);
	COLOR = vec4(vec3(1.0, 0.97, 0.9) * ligne / max(alpha, 0.0001), alpha);
}
