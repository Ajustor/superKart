extends SceneTree

## Mesure du retard d'affichage en réseau, à deux instances :
##
##   godot --headless --path . -s tools/mesure_latence.gd -- hote   [latence_ms] &
##   godot --headless --path . -s tools/mesure_latence.gd -- client [latence_ms]
##   python3 tools/mesure_latence.py
##
## Chaque instance note, à chaque image de physique, l'heure, la vraie position
## de son kart et la position AFFICHÉE du kart de l'autre joueur. Le script
## Python compare ce que le client affiche de l'hôte à là où l'hôte était
## vraiment au même instant, et inversement. `latence_ms` ajoute un retard à
## chaque envoi d'état, dans les deux sens : 40 simule un aller-retour de
## 80 ms, celui d'un bon Wi-Fi chargé ou d'une connexion Internet correcte.

const PORT := 8921
const DOSSIER := "/tmp/superkart_latence"

var role := ""
var latence := 0.0
var _session: RaceSession
var _lance := false
var _lignes: PackedStringArray = []
var _gid_autre := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if not args.is_empty() else "hote"
	latence = float(args[1]) / 1000.0 if args.size() > 1 else 0.0
	root.get_node("GameSettings").chemin = "user://mesure_%s.cfg" % role
	DirAccess.make_dir_recursive_absolute(DOSSIER)


func _process(_delta: float) -> bool:
	var reseau = root.get_node("Reseau")
	if not has_meta("demarre"):
		set_meta("demarre", true)
		if role == "hote":
			reseau.heberger("Hôte", PORT)
		else:
			reseau.rejoindre("127.0.0.1", "Client", PORT)
	if role == "hote" and not _lance and reseau.lobby.joueurs.size() == 2:
		_lance = true
		reseau.choisir_config("circuit_01", 1)
		reseau.lancer_course()
	if _session == null and current_scene != null and current_scene.has_node("Session"):
		_brancher(current_scene)
	# Chacun écrit dès que SON kart a fini, puis laisse à l'autre le temps
	# de finir aussi avant de couper la connexion.
	if _session != null and not has_meta("ecrit") and _session.entries[0].finished:
		set_meta("ecrit", Time.get_ticks_msec())
		var f := FileAccess.open("%s/%s.csv" % [DOSSIER, role], FileAccess.WRITE)
		f.store_string("\n".join(_lignes))
		f.close()
	if has_meta("ecrit") and Time.get_ticks_msec() - int(get_meta("ecrit")) > 8000:
		reseau.quitter()
		return true
	return Time.get_ticks_msec() > 160000


func _physics_process(_delta: float) -> bool:
	if _session == null or not _session.en_course or _gid_autre < 0:
		return false
	var sync = current_scene.get_node("RaceSync")
	var moi: Kart = _session.entries[0].kart
	var autre: Kart = sync.entrees[_gid_autre].kart
	_lignes.append("%.4f,%.3f,%.3f,%.3f,%.3f,%.2f" % [Time.get_unix_time_from_system(),
		moi.global_position.x, moi.global_position.z,
		autre.global_position.x, autre.global_position.z, moi.motor.speed])
	return false


func _brancher(course: Node) -> void:
	_session = course.get_node("Session")
	var sync = course.get_node("RaceSync")
	sync.latence_de_test = latence
	for place in root.get_node("Reseau").plan:
		if place.peer != 0 and place.peer != root.get_node("Reseau").mon_id():
			_gid_autre = place.gid
	var kart: Kart = _session.entries[0].kart
	var ia := AIInput.new()
	kart.add_child(ia)
	kart.changer_pilote(ia)
	_session.brancher_ia(ia)
	ia.track = _session.entries[0].progress.track
