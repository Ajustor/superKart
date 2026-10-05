shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

// Un portail d'étincelles : un anneau d'or en fusion qui tourne sans fin et
// crache des étincelles, et dedans l'autre monde (TrackPortail, la fenêtre :
// l'image d'une seconde caméra, posée là où le disque tombe à l'écran).
//
// À l'ouverture, un tout petit cercle de feu apparaît, l'autre monde déjà
// dedans, et grandit jusqu'à sa taille ; à la fermeture, il rapetisse
// jusqu'à disparaître.

uniform sampler2D vue : source_color, filter_linear, repeat_disable;
uniform float ouverture : hint_range(0.0, 1.0) = 1.0;
// 1 : la seconde caméra filme l'autre monde. 0 : rien à montrer (trop loin,
// qualité basse) ; l'intérieur est une braise sombre.
uniform float actif : hint_range(0.0, 1.0) = 0.0;
// Le rayon de l'anneau, en fraction de la demi-largeur du carré : il en
// reste autour pour le halo et les étincelles qui s'échappent.
uniform float anneau = 0.77;
uniform vec4 or_chaud : source_color = vec4(1.0, 0.5, 0.08, 1.0);
uniform vec4 or_clair : source_color = vec4(1.0, 0.86, 0.45, 1.0);

float hasard(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hasard(i), hasard(i + vec2(1.0, 0.0)), u.x),
		mix(hasard(i + vec2(0.0, 1.0)), hasard(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 c = (UV - 0.5) * 2.0;
	float r = length(c) / anneau;
	// L'angle, en tours, compté dans le sens où l'anneau tourne.
	float tour = fract(atan(c.y, c.x) / TAU + 1.0);
	float rotation = TIME * 0.55;
	float s = fract(tour - rotation);

	// L'anneau : un cœur blanc-or, une bande qui crépite.
	float d = abs(r - 1.0);
	float crepite = bruit(vec2(s * 90.0, TIME * 7.0)) * 0.6 + bruit(vec2(s * 23.0 - TIME * 3.0, r * 8.0)) * 0.6;
	float bande = smoothstep(0.1, 0.0, d) * (0.45 + 0.8 * crepite);
	float coeur = smoothstep(0.022, 0.0, d);
	// Les étincelles qui fusent hors du cercle, en traits tangents.
	float dehors = max(r - 1.0, 0.0);
	float traits = pow(bruit(vec2(s * 140.0 + dehors * 30.0, TIME * 14.0 - dehors * 40.0)), 7.0) * 3.0;
	float gerbe = traits * smoothstep(0.32, 0.0, dehors) * step(1.0, r);
	float halo = smoothstep(0.3, 0.0, d) * 0.25;
	float feu = bande + coeur + gerbe + halo;
	vec3 lueur = mix(or_chaud.rgb, or_clair.rgb, clamp(coeur + crepite * 0.4, 0.0, 1.0)) * (1.0 + coeur * 1.5);

	// Dès qu'il existe, l'autre monde est dedans : c'est le cercle tout
	// entier qui grandit (TrackPortail l'agrandit, de presque rien à `rayon`).
	float dedans = (1.0 - smoothstep(0.97, 1.0, r)) * step(0.001, ouverture);
	vec3 monde = textureLod(vue, SCREEN_UV, 0.0).rgb;
	vec3 braise = mix(vec3(0.12, 0.04, 0.01), or_chaud.rgb * 0.35, smoothstep(0.4, 1.0, r));
	vec3 fond = mix(braise, monde, actif);

	ALBEDO = mix(fond * dedans, lueur, clamp(feu, 0.0, 1.0));
	ALPHA = clamp(max(dedans, feu), 0.0, 1.0);
}
