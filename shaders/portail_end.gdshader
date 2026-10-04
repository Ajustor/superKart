shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Le portail du bout du monde, posé à plat : un puits d'étoiles. Trois nappes
// d'étoiles à des profondeurs différentes, qui glissent chacune à sa vitesse
// selon l'angle du regard — on croit voir très loin sous la surface.

uniform vec4 fond : source_color = vec4(0.02, 0.05, 0.06, 1.0);
uniform vec4 lueur : source_color = vec4(0.25, 0.85, 0.75, 1.0);

float hasard(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float etoiles(vec2 uv, float densite) {
	vec2 cellule = floor(uv);
	vec2 dedans = fract(uv) - 0.5;
	float h = hasard(cellule);
	if (h > densite) {
		return 0.0;
	}
	vec2 decale = vec2(hasard(cellule + 3.1), hasard(cellule + 7.7)) - 0.5;
	float d = length(dedans - decale * 0.6);
	return smoothstep(0.12, 0.0, d) * (0.5 + 0.5 * sin(TIME * 3.0 + h * 40.0));
}

void fragment() {
	// La direction du regard dans le repère de la surface : plus on regarde
	// en biais, plus les nappes profondes se décalent.
	vec3 regard = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec2 parallaxe = regard.xz / max(abs(regard.y), 0.2);
	vec3 c = fond.rgb;
	for (int i = 1; i <= 3; i++) {
		float profondeur = float(i) * 1.6;
		vec2 uv = UV * vec2(9.0, 9.0) * (1.0 + float(i) * 0.4) - parallaxe * profondeur * 0.3
			+ vec2(TIME * 0.05 * float(i), 0.0);
		float e = etoiles(uv, 0.18);
		vec3 teinte = mix(lueur.rgb, vec3(1.0), hasard(floor(uv) + 1.3));
		c += teinte * e * (1.2 - float(i) * 0.25);
	}
	ALBEDO = c;
}
