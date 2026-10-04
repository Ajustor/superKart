shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Le tourbillon d'un portail (TrackPortail) : des bras de spirale qui
// tournent, deux couleurs qui se mêlent. Sur le disque d'entrée, la spirale
// s'enroule vers le centre, où l'on voit à travers ; sur les anneaux du
// couloir (`couloir`), les bandes filent le long du passage.

uniform vec4 couleur_a : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform vec4 couleur_b : source_color = vec4(1.0, 0.4, 1.0, 1.0);
// De 0 (refermé) à 1 (grand ouvert).
uniform float ouverture : hint_range(0.0, 1.0) = 1.0;
uniform float vitesse = 1.0;
uniform bool couloir = false;
// Un voile plat qui ondule, sans spirale : le portail encadré d'obsidienne.
uniform bool plat = false;

void fragment() {
	float bras;
	float voile;
	if (plat) {
		// Des volutes qui montent et se tordent, d'un bord à l'autre.
		float tord = sin(UV.y * 9.0 + TIME * 1.7) * 0.6 + sin(UV.x * 13.0 - TIME * 1.1) * 0.4;
		bras = sin(UV.x * 18.0 + tord * 3.0 + TIME * 2.5 * vitesse) * sin(UV.y * 11.0 - TIME * 1.3);
		voile = 1.0;
	} else if (couloir) {
		// UV.x fait le tour de l'anneau, UV.y sa section.
		bras = sin(UV.x * 6.2832 * 3.0 + TIME * 5.0 * vitesse);
		voile = 0.55;
	} else {
		vec2 c = UV - 0.5;
		float r = length(c) * 2.0;
		float angle = atan(c.y, c.x);
		bras = sin(angle * 4.0 + r * 14.0 - TIME * 6.0 * vitesse);
		// Plein au bord, transparent au cœur : on voit le couloir au travers.
		voile = smoothstep(1.0, 0.85, r) * smoothstep(0.15, 0.6, r);
	}
	float m = 0.5 + 0.5 * bras;
	vec3 couleur = mix(couleur_a.rgb, couleur_b.rgb, m);
	ALBEDO = couleur * (0.6 + 0.8 * m);
	ALPHA = clamp(voile * ouverture * (0.35 + 0.65 * m), 0.0, 1.0);
}
