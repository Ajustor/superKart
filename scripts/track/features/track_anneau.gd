@tool
class_name TrackAnneau
extends TrackFeature

## Un anneau d'or qui flotte au-dessus du tracé : le kart qui passe dedans
## prend un turbo. Il se vise en l'air — au sommet d'un saut, dans une zone
## d'apesanteur — ou au ras du sol quand il est posé bas : une récompense pour
## qui prend la bonne trajectoire.
##
## On le traverse, on ne le heurte pas : il n'a pas de collision.

## Hauteur du centre au-dessus de la route, en mètres.
@export_range(0.0, 30.0, 0.25) var hauteur: float = 4.0:
	set(valeur):
		hauteur = valeur
		_modifie()

## Rayon intérieur : ce qu'on doit viser.
@export_range(1.0, 8.0, 0.25) var rayon: float = 2.5:
	set(valeur):
		rayon = valeur
		_modifie()

@export_range(0.1, 3.0, 0.05) var duree_turbo: float = 1.0
@export_range(1.0, 2.0, 0.01) var force_turbo: float = 1.4

@export var couleur: Color = Color(1.0, 0.8, 0.15):
	set(valeur):
		couleur = valeur
		_modifie()

## Épaisseur de la tranche où l'on compte la traversée, le long du tracé : à
## 30 m/s, un kart parcourt un demi-mètre par image.
const TRANCHE := 1.5

var _anneau: MeshInstance3D
var _eclat: float = 0.0


func _init() -> void:
	longueur = 1.0


func _validate_property(property: Dictionary) -> void:
	if property.name in ["longueur", "largeur"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Le kart, à cette distance, cet écart et cette hauteur au-dessus de la
## route, passe-t-il dans l'anneau ?
func traverse(distance: float, lateral: float, haut: float, longueur_tour: float) -> bool:
	var ecart := absf(wrapf(distance - debut, -longueur_tour * 0.5, longueur_tour * 0.5))
	if ecart > TRANCHE:
		return false
	# Le centre du kart est à une trentaine de centimètres de la route.
	return Vector2(lateral - decalage, haut - hauteur).length() <= rayon


## L'anneau vient d'être traversé : il s'illumine un instant.
func briller() -> void:
	_eclat = 1.0


func _construire(c: TrackCurve, racine: Node3D) -> void:
	_anneau = MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = rayon
	tore.outer_radius = rayon + 0.45
	tore.rings = 32
	tore.ring_segments = 10
	_anneau.mesh = tore
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.metallic = 0.6
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = couleur
	m.emission_energy_multiplier = 0.8
	_anneau.material_override = m
	var repere := c.basis_at(debut)
	_anneau.transform = Transform3D(Basis(repere.x, -repere.z, repere.y),
		TrackFeature.point(c, debut, decalage, hauteur))
	racine.add_child(_anneau)


func _process(delta: float) -> void:
	if _anneau == null or Engine.is_editor_hint():
		return
	# Il tourne doucement sur son axe, et flambe quand on le traverse.
	_anneau.rotate_object_local(Vector3.UP, delta * 1.5)
	_eclat = maxf(_eclat - delta * 2.0, 0.0)
	(_anneau.material_override as StandardMaterial3D).emission_energy_multiplier = 0.8 + 3.0 * _eclat
