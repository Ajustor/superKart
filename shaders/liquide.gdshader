shader_type spatial;

// L'eau et la lave des circuits : un bruit qui dérive dans deux sens, qui
// mêle deux couleurs et ride la surface. Tout se calcule au pixel : le plan
// n'a que deux triangles, il n'y a rien à onduler aux sommets.
//
// Pour la lave, `lueur` fait briller les veines claires, qui battent
// lentement ; pour l'eau, elle reste à zéro et ce sont les reflets qui
// vivent.

uniform vec4 couleur_profonde : source_color = vec4(0.05, 0.3, 0.55, 1.0);
uniform vec4 couleur_claire : source_color = vec4(0.25, 0.65, 0.85, 1.0);
// Taille des motifs, en mètres.
uniform float echelle = 9.0;
uniform float vitesse = 0.25;
uniform float rides = 0.35;
uniform float lueur = 0.0;
uniform float rugosite = 0.15;

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float motif(vec2 p) {
	float t = TIME * vitesse;
	return 0.6 * bruit(p + vec2(t, t * 0.6)) + 0.4 * bruit(p * 2.1 - vec2(t * 0.8, -t * 1.1));
}

varying vec3 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = monde.xz / echelle;
	float m = motif(p);
	// La pente du motif, pour rider la surface.
	float e = 0.05;
	float dx = motif(p + vec2(e, 0.0)) - m;
	float dz = motif(p + vec2(0.0, e)) - m;
	vec3 n = normalize(vec3(-dx * rides / e * 0.1, 1.0, -dz * rides / e * 0.1));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 couleur = mix(couleur_profonde.rgb, couleur_claire.rgb, smoothstep(0.35, 0.8, m));
	ALBEDO = couleur;
	ROUGHNESS = rugosite;
	SPECULAR = 0.6;
	if (lueur > 0.0) {
		float veines = smoothstep(0.55, 0.85, m);
		float battement = 0.75 + 0.25 * sin(TIME * 1.7 + m * 6.0);
		EMISSION = couleur_claire.rgb * veines * lueur * battement + couleur_profonde.rgb * 0.35 * lueur;
	}
}
