shader_type spatial;
render_mode cull_back;

// Le châssis du kart Kenney, repeint : sa palette (une seule texture pour
// tout le Car Kit) est lue telle quelle, sauf le gris-bleu de la carrosserie,
// qui prend la teinte du joueur en gardant ses ombres et ses lumières. Les
// détails jaunes, le noir des plastiques restent ce qu'ils sont.

uniform sampler2D palette : source_color, filter_linear_mipmap;
uniform vec4 teinte : source_color = vec4(0.2, 0.45, 0.85, 1.0);
// La luminance du gris-bleu le plus clair de la carrosserie (#bdc6ee),
// en couleurs linéaires : là, la teinte est pure.
const float CLAIR = 0.56;

void fragment() {
	vec3 c = texture(palette, UV).rgb;
	float haut = max(c.r, max(c.g, c.b));
	float bas = min(c.r, min(c.g, c.b));
	float saturation = (haut - bas) / max(haut, 0.001);
	// Le gris-bleu : le bleu en tête, peu saturé.
	float cadre = step(c.r, c.b) * step(c.g, c.b) * smoothstep(0.08, 0.14, saturation)
		* (1.0 - smoothstep(0.5, 0.6, saturation));
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 peint = teinte.rgb * clamp(lum / CLAIR, 0.0, 1.3);
	ALBEDO = mix(c, peint, cadre);
	ROUGHNESS = 0.6;
}
