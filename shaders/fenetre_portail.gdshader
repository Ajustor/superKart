shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

// La surface d'un portail qu'on voit à travers (TrackPortail) : l'image d'une
// seconde caméra, placée exactement comme celle du joueur mais qui ne voit
// que le monde de l'autre côté, posée à l'endroit de l'écran où tombe la
// surface. De face comme de biais, on voit l'autre monde là où il est, avec
// la bonne perspective ; autour du cadre, le monde où l'on est.
//
// Un liseré lumineux tourne sur le bord : un tourbillon pour un portail rond
// (`disque`), des volutes pour un voile rectangulaire.

uniform sampler2D vue : source_color, filter_linear, repeat_disable;
uniform vec4 couleur_a : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform vec4 couleur_b : source_color = vec4(1.0, 0.4, 1.0, 1.0);
// De 0 (refermé) à 1 (grand ouvert).
uniform float ouverture : hint_range(0.0, 1.0) = 1.0;
// 1 : la seconde caméra filme l'autre monde. 0 : elle ne filme rien (trop
// loin, hors champ, qualité basse) et le voile est opaque.
uniform float actif : hint_range(0.0, 1.0) = 1.0;
uniform bool disque = false;
uniform float vitesse = 1.0;

void fragment() {
	vec3 monde = texture(vue, SCREEN_UV).rgb;
	float bord;
	float dedans;
	float volute;
	if (disque) {
		vec2 c = UV - 0.5;
		float r = length(c) * 2.0;
		float angle = atan(c.y, c.x);
		volute = 0.5 + 0.5 * sin(angle * 4.0 + r * 14.0 - TIME * 6.0 * vitesse);
		dedans = 1.0 - smoothstep(0.9, 1.0, r);
		// Le tourbillon mange les bords et laisse voir au cœur.
		bord = smoothstep(0.45, 0.95, r);
	} else {
		vec2 e = min(UV, 1.0 - UV);
		float pres = min(e.x * 2.2, e.y);
		float tord = sin(UV.y * 9.0 + TIME * 1.7) * 0.6 + sin(UV.x * 13.0 - TIME * 1.1) * 0.4;
		volute = 0.5 + 0.5 * sin(UV.x * 18.0 + tord * 3.0 + TIME * 2.5 * vitesse) * sin(UV.y * 11.0 - TIME * 1.3);
		dedans = 1.0;
		bord = 1.0 - smoothstep(0.0, 0.16, pres);
	}
	vec3 lueur = mix(couleur_a.rgb, couleur_b.rgb, volute) * (0.7 + 0.6 * volute);
	// Un voile léger sur tout le portail, plus dense au bord, opaque s'il
	// n'y a rien à montrer.
	float voile = clamp(0.12 + bord * 0.85 + (1.0 - actif), 0.0, 1.0);
	ALBEDO = mix(monde, lueur, voile);
	ALPHA = dedans * ouverture;
}
