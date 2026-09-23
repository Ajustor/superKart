extends SceneTree

## Photographie un circuit, pour le voir sans lancer une partie :
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##       -s tools/capture_circuit.gd -- <id> <dossier> [distance…]
##
## Une vue d'ensemble, prise de haut, puis une vue à hauteur de kart à chaque
## distance demandée le long du tracé — ou de haut, si elle finit par « h ».

var _course: Node
var _camera: Camera3D
var _vues: Array = []
var _dossier := ""
var _attente := 0
var _id := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var reglage := RaceSetup.new()
	_id = args[0]
	reglage.choisir_piste(TrackCatalog.par_id(_id))
	_dossier = args[1] if args.size() > 1 else "user://"
	_course = RaceLauncher.monter(reglage)
	root.add_child(_course)
	current_scene = _course
	_camera = Camera3D.new()
	_camera.far = 3000.0
	_course.add_child(_camera)
	# La caméra de poursuite se rend active à chaque image : on la coupe.
	for autre in _course.find_children("*", "Camera3D", true, false):
		if autre != _camera:
			autre.process_mode = Node.PROCESS_MODE_DISABLED
	_vues.append(["ensemble", -1.0, false])
	for i in range(2, args.size()):
		_vues.append([args[i], float(args[i].trim_suffix("h")), args[i].ends_with("h")])


func _process(_delta: float) -> bool:
	var piste: Track = _course.get_node("Track")
	if piste.track_curve == null:
		return false
	_attente += 1
	if _attente < 20:
		return false
	# Une image pour placer la caméra, quelques-unes pour que le rendu la rattrape.
	var tic := (_attente - 20) % 8
	if tic == 0:
		if _vues.is_empty():
			return true
		_placer(piste.track_curve, _vues[0][1], _vues[0][2])
		_camera.make_current()
	elif tic == 7:
		var vue: Array = _vues.pop_front()
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("%s/%s_%s.png" % [_dossier, _id, vue[0]])
	return false


func _placer(c: TrackCurve, d: float, de_haut: bool) -> void:
	if d < 0.0:
		# De haut et de biais, assez loin pour tout voir.
		var mini := Vector3(INF, INF, INF)
		var maxi := -mini
		var e := 0.0
		while e < c.length:
			var p := c.position_at(e)
			mini = mini.min(p)
			maxi = maxi.max(p)
			e += 10.0
		var centre := (mini + maxi) * 0.5
		var taille := (maxi - mini).length()
		_camera.position = centre + Vector3(0, taille * 0.75, taille * 0.55)
		_camera.look_at(centre)
		return
	if de_haut:
		_camera.position = c.position_at(d - 25.0) + Vector3.UP * 35.0
		_camera.look_at(c.position_at(d))
		return
	_camera.position = c.position_at(d - 9.0) + c.up_at(d - 9.0) * 3.2
	_camera.look_at(c.position_at(d + 14.0) + c.up_at(d + 14.0) * 0.8)
