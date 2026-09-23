@tool
class_name TrackGap
extends TrackFeature

## Un trou : sur cette portion du tracé, la route n'est pas construite. On la
## franchit en sautant — une rampe ou un tremplin juste avant — et on atterrit
## sur la suite du circuit, qui peut être ailleurs sur la carte : la courbe
## continue de décrire la trajectoire au-dessus du vide, c'est elle qu'on
## dessine pour relier les deux rives.
##
## Tomber dedans remet le kart en piste APRÈS le trou : le reposer avant, à
## l'arrêt, sans élan pour sauter, le ferait retomber indéfiniment — l'IA
## comprise.

## Largeur des bandes jaunes et noires peintes sur chaque rive.
const BANDE_BORD := 1.5


func _init() -> void:
	longueur = 25.0


func _validate_property(property: Dictionary) -> void:
	# Un trou coupe toute la largeur de la route : ces deux réglages n'ont
	# pas de sens ici.
	if property.name in ["decalage", "largeur"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func fin() -> float:
	return debut + longueur


## Couvre-t-il ce point ? Toute la largeur, sur toute sa longueur.
func contient(distance: float, _lateral: float, longueur_tour: float) -> bool:
	return couvre(distance, longueur_tour)


## Les portions sans route, pour TrackBuilder : un couple (début, fin) dans
## [0, longueur_tour], ou deux si le trou chevauche la ligne d'arrivée.
func portions(longueur_tour: float) -> Array[Vector2]:
	var a := wrapf(debut, 0.0, longueur_tour)
	var b := a + longueur
	var morceaux: Array[Vector2] = []
	if b <= longueur_tour:
		morceaux.append(Vector2(a, b))
	else:
		morceaux.append(Vector2(a, longueur_tour))
		morceaux.append(Vector2(0.0, b - longueur_tour))
	return morceaux


## Régler un trou, c'est refaire la route, qui refait à son tour tous les
## éléments posés dessus, celui-ci compris.
func _apres_modification() -> void:
	var p := piste()
	if p != null and p.is_node_ready():
		p.reconstruire()
	else:
		reconstruire()


func _ready() -> void:
	super()
	# Ajouté dans l'éditeur après coup : la route doit s'ouvrir tout de suite.
	var p := piste()
	if Engine.is_editor_hint() and p != null and p.is_node_ready():
		p.reconstruire.call_deferred()


func _exit_tree() -> void:
	# Retiré : la route doit se refermer. Différé, pour qu'au moment de
	# reconstruire ce trou ne soit plus parmi les enfants du circuit.
	var p := piste()
	if Engine.is_editor_hint() and p != null and not p.is_queued_for_deletion():
		p.reconstruire.call_deferred()


func _get_configuration_warnings() -> PackedStringArray:
	var avertissements := super()
	var p := piste()
	if p != null and p.track_curve != null and not a_un_elan(p):
		avertissements.append("Ni rampe ni tremplin dans les %d m avant ce trou : " % int(DISTANCE_D_ELAN) \
			+ "personne ne pourra le sauter. Pose un TrackRamp ou un TrackJump juste avant.")
	return avertissements


## Distance, avant le trou, où chercher de quoi sauter.
const DISTANCE_D_ELAN := 30.0


## Une rampe ou un tremplin finit-il dans les derniers mètres avant le trou ?
func a_un_elan(p: Track) -> bool:
	var tour := p.track_curve.length
	for element in p.elements():
		if not (element is TrackRamp or element is TrackJump):
			continue
		var ecart := wrapf(debut - (element.debut + element.longueur), -tour * 0.5, tour * 0.5)
		if ecart >= -1.0 and ecart <= DISTANCE_D_ELAN:
			return true
	return false


## Des bandes jaunes et noires sur chaque rive : un bord de vide doit se voir
## de loin, surtout au sommet d'une rampe.
func _construire(c: TrackCurve, racine: Node3D) -> void:
	var demi := c.half_width
	var materiau := _materiau_bord()
	for d in [debut - BANDE_BORD, fin()]:
		TrackFeature._poser(racine, TrackFeature.nappe(c, d, BANDE_BORD, -demi, demi, 0.03), materiau, false)


func _materiau_bord() -> StandardMaterial3D:
	# Deux pixels superposés : la couleur change en travers de la route (v).
	var image := Image.create(1, 2, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color(1.0, 0.8, 0.05))
	image.set_pixel(0, 1, Color(0.08, 0.08, 0.08))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# v compte en mètres : une bande de couleur par mètre de largeur.
	m.uv1_scale = Vector3(1.0, 0.5, 1.0)
	return m
