@tool
class_name TrackBoost
extends TrackFeature

## Une plaque d'accélération : le kart qui roule dessus prend un turbo, comme
## sur les flèches d'un Mario Kart. Posée sur la trajectoire idéale, elle
## récompense qui la suit ; posée à côté, elle vaut un écart.
##
## Ses flèches défilent dans le sens de la course : on la reconnaît de loin,
## et on sait de quel côté elle pousse.

@export_range(0.1, 3.0, 0.05) var duree_turbo: float = 1.0:
	set(valeur):
		duree_turbo = valeur
		_modifie()

## Force du turbo, en multiple de la vitesse maximale.
@export_range(1.0, 2.0, 0.01) var force_turbo: float = 1.35

## Vitesse de défilement des flèches, en longueurs de motif par seconde.
const DEFILEMENT := 1.6

var _materiau_plaque: StandardMaterial3D


func _init() -> void:
	longueur = 6.0
	largeur = 4.5


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var g := decalage - largeur * 0.5
	var r := decalage + largeur * 0.5
	_materiau_plaque = _materiau()
	TrackFeature._poser(racine, _nappe(c, g, r, 0.035), _materiau_plaque, false)


func _process(delta: float) -> void:
	if _materiau_plaque != null and not Engine.is_editor_hint():
		var decale := _materiau_plaque.uv1_offset
		decale.x = fposmod(decale.x - DEFILEMENT * delta * _materiau_plaque.uv1_scale.x * 2.0, 1.0)
		_materiau_plaque.uv1_offset = decale


## Des flèches claires sur fond bleu, en émissif.
func _materiau() -> StandardMaterial3D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var fond := Color(0.1, 0.35, 0.95)
	var fleche := Color(0.55, 0.95, 1.0)
	for y in 32:
		for x in 32:
			var v := absf(float(y) - 15.5) / 16.0
			var phase := fposmod(float(x) / 32.0 + v * 0.45, 1.0)
			image.set_pixel(x, y, fleche if phase < 0.3 and v < 0.8 else fond)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.uv1_scale = Vector3(1.0 / 2.0, 1.0 / largeur, 1.0)
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m
