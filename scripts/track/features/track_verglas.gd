@tool
class_name TrackVerglas
extends TrackFeature

## Une plaque de glace sur la route : le kart y garde sa vitesse, mais il
## n'accroche plus. Le nez tourne, la trajectoire suit avec retard, et les
## roues patinent à l'accélération. Il faut anticiper le virage, ou le prendre
## en glisse — un dérapage reste un dérapage, glace ou pas.
##
## Contrairement à l'herbe, la glace ne ralentit pas : elle se traverse vite
## et se négocie mal.

## De 1 (bitume) vers 0 (patinoire). À 0,3, la trajectoire met une demi-
## seconde à rejoindre le nez.
@export_range(0.05, 0.95, 0.05) var adherence: float = 0.3

@export var couleur: Color = Color(0.7, 0.9, 1.0, 0.75):
	set(valeur):
		couleur = valeur
		_modifie()


func _init() -> void:
	longueur = 40.0
	largeur = 18.0


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var g := decalage - largeur * 0.5
	var r := decalage + largeur * 0.5
	TrackFeature._poser(racine, _nappe(c, g, r, 0.025, true), _materiau(), false)
	for enfant in racine.get_children():
		if enfant is GeometryInstance3D:
			(enfant as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Un miroir bleuté, rayé de fissures blanches : on la voit venir de loin, et
## on comprend tout de suite qu'elle glisse.
func _materiau() -> StandardMaterial3D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	image.fill(couleur)
	# Quelques fissures en diagonale.
	for f in 5:
		var x := rng.randi_range(0, 31)
		var y := rng.randi_range(0, 31)
		for i in 14:
			image.set_pixel(posmod(x + i, 32), posmod(y + i / 2 * (1 if f % 2 == 0 else -1), 32),
				Color(1, 1, 1, 0.95))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.uv1_scale = Vector3(1.0 / 6.0, 1.0 / 6.0, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.3
	m.metallic_specular = 1.0
	m.emission_enabled = true
	m.emission = Color(0.25, 0.4, 0.55)
	m.emission_energy_multiplier = 0.4
	return m
