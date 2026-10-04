@tool
class_name TrackPortail
extends TrackFeature

## Un portail : un tourbillon de lumière en travers de la route, qui s'ouvre
## quand le premier approche et se referme une fois le dernier passé. On le
## traverse sans rien sentir sous les roues — ce n'est pas un obstacle —,
## mais pas sans rien voir.
##
## Il est plus grand dedans que dehors : l'anneau d'entrée fait `rayon`
## mètres, puis le couloir s'évase jusqu'au double avant de se resserrer à la
## sortie. La caméra qui le traverse change de perspective en même temps
## (ChaseCamera.vortex : le champ s'ouvre pendant qu'elle se rapproche du
## kart), si bien que le couloir semble s'étirer bien au-delà de sa longueur :
## une perspective qui ne tient pas debout, celle d'un voyage dans le temps.
##
## De l'autre côté, le monde a changé : `ambiance`, le ciel et la lumière de
## la portion qui suit, jusqu'au prochain portail (Track.ambiance_en).
##
## Il s'ouvre et se ferme d'après la course (Track.tete_total et
## queue_total) : en réseau, chaque machine voit le même portail ouvert.

@export_range(3.0, 20.0, 0.5) var rayon: float = 8.0:
	set(valeur):
		rayon = valeur
		_modifie()

@export var couleur_a: Color = Color(0.3, 0.65, 1.0)
@export var couleur_b: Color = Color(1.0, 0.45, 1.0)

## Le ciel et la lumière de l'autre côté. Rien : on garde ceux du circuit.
@export var ambiance: Environment

## Il s'ouvre quand le premier en est à cette distance, en mètres.
const AVANCE := 90.0
## Il reste ouvert jusqu'à ce que le dernier l'ait dépassé de ça.
const APRES := 8.0
## Les anneaux du couloir, tous les tant de mètres.
const PAS_DES_ANNEAUX := 6.0
## Le couloir s'évase jusqu'à ce multiple du rayon d'entrée.
const EVASEMENT := 2.0

var _ouverture: float = 0.0
var _materiaux: Array[ShaderMaterial] = []
var _anneaux: Array[Node3D] = []
var _lumiere: OmniLight3D

const SHADER := preload("res://shaders/vortex.gdshader")


func _init() -> void:
	longueur = 36.0
	largeur = 18.0


func _validate_property(property: Dictionary) -> void:
	if property.name in ["decalage", "largeur"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Ouvert pour ce peloton ? `tete` et `queue` : la distance parcourue depuis
## le départ par le premier et par le dernier, `tour` la longueur d'un tour.
## Il s'ouvre quand le premier arrive à AVANCE mètres, et reste ouvert tant
## que le dernier ne l'a pas dépassé — au même tour.
func ouvert(tete: float, queue: float, tour: float) -> bool:
	if tour <= 0.0:
		return false
	var passage := floorf((tete - debut + AVANCE) / tour) * tour + debut
	if tete < passage - AVANCE:
		return false
	return queue < passage + longueur + APRES


## Le rayon du couloir à cette fraction de sa longueur : plus grand dedans.
func rayon_du_couloir(t: float) -> float:
	return rayon * lerpf(1.0, EVASEMENT, sin(clampf(t, 0.0, 1.0) * PI))


## La force de l'effet sur la caméra d'un kart à cette distance le long du
## tracé : 0 loin du portail, 1 en plein couloir.
func effet_a(distance: float, tour: float) -> float:
	var etendue := longueur + 30.0
	var t := wrapf(distance - debut + 15.0, 0.0, tour)
	if t > etendue:
		return 0.0
	return sin(t / etendue * PI) * _ouverture


func ouverture() -> float:
	return _ouverture


func _materiau(couloir: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("couleur_a", couleur_a)
	m.set_shader_parameter("couleur_b", couleur_b)
	m.set_shader_parameter("couloir", couloir)
	m.set_shader_parameter("ouverture", 0.0)
	_materiaux.append(m)
	return m


func _construire(c: TrackCurve, racine: Node3D) -> void:
	_materiaux.clear()
	_anneaux.clear()
	var lumineux := StandardMaterial3D.new()
	lumineux.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lumineux.albedo_color = couleur_a.lerp(Color.WHITE, 0.4)
	# L'entrée : un anneau lumineux et le disque du tourbillon.
	var entree := Node3D.new()
	entree.transform = Transform3D(c.basis_at(debut), TrackFeature.point(c, debut, 0.0, rayon * 0.8))
	racine.add_child(entree)
	var cercle := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = rayon - 0.35
	tore.outer_radius = rayon + 0.35
	tore.rings = 48
	cercle.mesh = tore
	cercle.material_override = lumineux
	cercle.rotation.x = PI * 0.5
	entree.add_child(cercle)
	var disque := MeshInstance3D.new()
	var plan := QuadMesh.new()
	plan.size = Vector2(rayon * 2.0, rayon * 2.0)
	disque.mesh = plan
	disque.material_override = _materiau(false)
	entree.add_child(disque)
	_anneaux.append(entree)
	# Le couloir : des anneaux de tourbillon qui s'évasent puis se resserrent.
	var n := maxi(int(longueur / PAS_DES_ANNEAUX), 2)
	var materiau_couloir := _materiau(true)
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var d := debut + longueur * t
		var r := rayon_du_couloir(t)
		var anneau := Node3D.new()
		anneau.transform = Transform3D(c.basis_at(d), TrackFeature.point(c, d, 0.0, r * 0.55))
		racine.add_child(anneau)
		var forme := MeshInstance3D.new()
		var tube := TorusMesh.new()
		tube.inner_radius = r - 0.8
		tube.outer_radius = r + 0.8
		tube.rings = 40
		tube.ring_segments = 6
		forme.mesh = tube
		forme.material_override = materiau_couloir
		forme.rotation.x = PI * 0.5
		anneau.add_child(forme)
		_anneaux.append(anneau)
	if not Engine.is_editor_hint():
		_lumiere = OmniLight3D.new()
		_lumiere.light_color = couleur_b
		_lumiere.omni_range = rayon * 4.0
		_lumiere.light_energy = 0.0
		_lumiere.position = Vector3(0, 0, -2.0)
		entree.add_child(_lumiere)
	_appliquer()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_ouverture = 1.0
		_appliquer()
		return
	var p := piste()
	if p == null:
		return
	var cible := 1.0 if ouvert(p.tete_total, p.queue_total, p.track_curve.length) else 0.0
	_ouverture = move_toward(_ouverture, cible, delta * (1.2 if cible > _ouverture else 0.8))
	_appliquer()


func _appliquer() -> void:
	for m in _materiaux:
		m.set_shader_parameter("ouverture", _ouverture)
	# Il naît d'un point et y retourne : tout le portail grandit avec lui.
	var echelle := lerpf(0.04, 1.0, smoothstep(0.0, 1.0, _ouverture))
	for anneau in _anneaux:
		anneau.scale = Vector3.ONE * echelle
		anneau.visible = _ouverture > 0.01
	if _lumiere != null:
		_lumiere.light_energy = 3.0 * _ouverture
