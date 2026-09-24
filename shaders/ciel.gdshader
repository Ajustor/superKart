shader_type sky;

// Le ciel des circuits : un dégradé, des nuages posés sur un plafond
// imaginaire, le disque du soleil (la première lumière de la scène) et, la
// nuit, des étoiles. Rien ne bouge : un ciel immobile ne se recalcule
// qu'une fois pour les reflets.

uniform vec4 haut : source_color = vec4(0.3, 0.55, 0.9, 1.0);
uniform vec4 horizon : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform vec4 sol_horizon : source_color = vec4(0.6, 0.7, 0.6, 1.0);
uniform vec4 sol_bas : source_color = vec4(0.3, 0.4, 0.3, 1.0);
// Part du ciel couverte, de 0 à 1.
uniform float nuages : hint_range(0.0, 1.0) = 0.45;
uniform vec4 couleur_nuages : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float etoiles : hint_range(0.0, 1.0) = 0.0;
uniform float soleil = 1.0;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * bruit(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 c;
	if (h >= 0.0) {
		c = mix(horizon.rgb, haut.rgb, pow(h, 0.55));
		if (etoiles > 0.0) {
			vec3 q = d * 160.0;
			float s = hasard(floor(q.xz) + floor(q.y) * 13.0);
			float eclat = step(0.994, s) * (0.5 + 0.5 * hasard(floor(q.xz) * 1.7));
			c += vec3(eclat * etoiles * smoothstep(0.0, 0.25, h));
		}
		if (nuages > 0.0) {
			// Un plafond de nuages : plus on regarde bas, plus ils sont loin
			// et serrés.
			vec2 p = d.xz / (h + 0.12) * 1.3;
			float n = fbm(p);
			float couvert = smoothstep(1.0 - nuages, 1.0 - nuages + 0.28, n);
			vec3 teinte = couleur_nuages.rgb * (0.82 + 0.25 * fbm(p * 2.0 + 3.0));
			c = mix(c, teinte, couvert * smoothstep(0.0, 0.12, h) * 0.9);
		}
	} else {
		c = mix(sol_horizon.rgb, sol_bas.rgb, pow(-h, 0.5));
	}
	if (LIGHT0_ENABLED && soleil > 0.0) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		c += LIGHT0_COLOR * soleil * (smoothstep(0.9993, 0.9997, s) * 4.0 + pow(s, 220.0) * 0.4);
	}
	COLOR = c;
}
