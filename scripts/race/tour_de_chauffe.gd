class_name TourDeChauffe
extends Node3D

## Le tour de chauffe : quelques images rendues derrière l'écran de chargement
## depuis une caméra qui voit tout le circuit, avec devant elle un exemplaire
## de chaque objet et de chaque effet.
##
## En GL Compatibility, un matériau n'est compilé que la première fois qu'il
## est dessiné. Sans ce tour, la première carapace, la première explosion, la
## première plaque d'accélération ou la première vue sur la lave figeaient
## l'image en pleine course — sur téléphone, de quoi rater un virage.

const IMAGES := 3

var _camera: Camera3D
var _avant: Camera3D
var _images := 0
## Les portails, montrés grands ouverts le temps du tour, et les ciels de
## leurs mondes, un par image : chacun se compile ici plutôt qu'à
## l'ouverture du portail, en pleine course.
var _portails: Array[TrackPortail] = []
var _ciels: Array[Environment] = []


## Monte le tour dans la course (déjà dans l'arbre). Rend faux s'il n'y a
## rien à chauffer (pas de circuit).
static func lancer(course: Node) -> TourDeChauffe:
	var piste := course.get_node_or_null("Track") as Track
	if piste == null or piste.track_curve == null:
		return null
	var tour := TourDeChauffe.new()
	tour.name = "TourDeChauffe"
	course.add_child(tour)
	tour._installer(course, piste.track_curve)
	return tour


func _installer(course: Node, c: TrackCurve) -> void:
	_avant = get_viewport().get_camera_3d()
	# De haut et de biais, assez loin pour voir tout le circuit.
	var mini := Vector3(INF, INF, INF)
	var maxi := -mini
	var d := 0.0
	while d < c.length:
		var p := c.position_at(d)
		mini = mini.min(p)
		maxi = maxi.max(p)
		d += 10.0
	var centre := (mini + maxi) * 0.5
	var taille := (mini - maxi).length()
	_camera = Camera3D.new()
	_camera.far = 4000.0
	add_child(_camera)
	_camera.global_position = centre + Vector3(0, taille * 0.75, taille * 0.55)
	_camera.look_at(centre)
	_camera.make_current()

	# Les échantillons, alignés devant l'objectif.
	var echantillons: Array[Node3D] = []
	var objets := course.get_node_or_null("Objets") as ItemManager
	if objets != null:
		echantillons.append_array(objets.echantillons())
	for visuel in course.find_children("*", "KartVisuals", true, false):
		echantillons.append_array((visuel as KartVisuals).echantillons())
		break
	var piste := course.get_node_or_null("Track") as Track
	if piste != null:
		_portails = piste.portails()
		for portail in _portails:
			portail.chauffer(_camera)
			if portail.ambiance != null and not _ciels.has(portail.ambiance):
				_ciels.append(portail.ambiance)
	var devant := -_camera.global_basis.z
	var droite := _camera.global_basis.x
	for i in echantillons.size():
		var e := echantillons[i]
		add_child(e)
		var decale := (float(i) - echantillons.size() * 0.5) * 0.9
		e.global_position = _camera.global_position + devant * 12.0 + droite * decale
		if e is GPUParticles3D or e is CPUParticles3D:
			e.set("emitting", true)


func _process(_delta: float) -> void:
	# Une image par ciel des autres mondes, puis celui du circuit.
	_camera.environment = _ciels[_images] if _images < _ciels.size() else null
	_images += 1
	if _images >= IMAGES + _ciels.size():
		finir()


func fini() -> bool:
	return is_queued_for_deletion()


func finir() -> void:
	if is_queued_for_deletion():
		return
	for portail in _portails:
		if is_instance_valid(portail):
			portail.fin_de_chauffe()
	if _avant != null and is_instance_valid(_avant):
		_avant.make_current()
	queue_free()
