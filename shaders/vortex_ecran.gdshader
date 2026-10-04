shader_type canvas_item;

// La traversée d'un portail, à l'écran : l'image s'enroule autour du centre
// et s'y étire, de plus en plus fort vers les bords, avec une frange de
// couleur. N'est allumé que dans le couloir (EffetsEcran) : lire l'écran a
// un coût, inutile le reste du temps.

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform float force : hint_range(0.0, 1.0) = 0.0;
uniform float rapport = 1.7778;

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	c.x *= rapport;
	float r = length(c);
	// Un tour qui croît avec la distance au centre, et qui bat doucement.
	float tour = force * (1.4 * r * r + 0.25 * sin(TIME * 3.0)) ;
	float s = sin(tour);
	float k = cos(tour);
	vec2 tourne = vec2(c.x * k - c.y * s, c.x * s + c.y * k);
	// Le centre se creuse : on y voit plus loin qu'il n'y a.
	tourne *= 1.0 - 0.35 * force * smoothstep(0.6, 0.0, r);
	tourne.x /= rapport;
	vec2 uv = tourne + 0.5;
	float frange = 0.008 * force * r;
	vec3 couleur = vec3(
		texture(ecran, uv + vec2(frange, 0.0)).r,
		texture(ecran, uv).g,
		texture(ecran, uv - vec2(frange, 0.0)).b);
	COLOR = vec4(couleur, 1.0);
}
