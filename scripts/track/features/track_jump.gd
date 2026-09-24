@tool
class_name TrackJump
extends TrackFeature

## Un tremplin : le kart qui roule dessus décolle. De quoi franchir un virage
## par la voie des airs, sauter un trou, ou atteindre un raccourci — tout ce
## qu'un Mario Kart fait avec ses rampes bleues.
##
## Pendant le vol, le kart n'est pas remis en piste même s'il survole le
## décor : il ne l'est qu'en atterrissant hors de tout sol praticable, ou en
## tombant sous la route.

## Vitesse verticale au décollage, en m/s. Avec la gravité du kart (30 m/s²),
## 10 donne 0,67 s de vol, 1,7 m de haut et une quinzaine de mètres de saut à
## pleine vitesse ; 14 double la durée de vol à peu près.
@export_range(1.0, 40.0, 0.5) var impulsion: float = 10.0:
	set(valeur):
		impulsion = valeur
		_modifie()

## Turbo accordé au décollage, en secondes. Zéro : pas de turbo.
@export_range(0.0, 3.0, 0.05) var duree_turbo: float = 0.0:
	set(valeur):
		duree_turbo = valeur
		_modifie()

## Force de ce turbo, en multiple de la vitesse maximale.
@export_range(1.0, 2.0, 0.01) var force_turbo: float = 1.3


func _init() -> void:
	longueur = 4.0
	largeur = 8.0


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var g := decalage - largeur * 0.5
	var r := decalage + largeur * 0.5
	TrackFeature._poser(racine, _nappe(c, g, r, 0.04), _materiau(), false)


## Des chevrons qui pointent dans le sens de la course, orange sur jaune, en
## émissif : un tremplin doit se voir de loin, c'est une invitation.
func _materiau() -> StandardMaterial3D:
	var image := TrackFeature.image_de_chevron(Color(1.0, 0.8, 0.1), Color(0.95, 0.35, 0.05))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.uv1_scale = Vector3(1.0 / 2.0, 1.0 / largeur, 1.0)
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m
