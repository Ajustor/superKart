extends Node

## Les vignettes des circuits (resources/vignettes/<id>.jpg), pour le choix
## des courses : chaque circuit photographié en pleine course, quelques
## secondes après le départ, derrière le kart du joueur confié à l'IA.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##       --fixed-fps 30 -s tools/lance_outil.gd -- vignettes <id> [secondes]
##
## Un circuit par lancement : la mémoire d'un circuit ne déborde pas sur le
## suivant. tools/vignettes.sh les fait tous.

const DOSSIER := "res://resources/vignettes/"
const TAILLE := Vector2i(384, 216)

var _session: RaceSession
var _branche := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[1]
	var secondes := float(args[2]) if args.size() > 2 else 6.0
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.par_id(id))
	reglage.personnage = 7
	reglage.couleur = 1
	var course := RaceLauncher.monter(reglage)
	_session = course.get_node("Session") as RaceSession
	# Sans interface : la vignette montre le circuit, pas le chrono.
	var hud := course.get_node_or_null("HUD")
	if hud != null:
		course.remove_child(hud)
		hud.free()
	add_child(course)
	await get_tree().create_timer(secondes).timeout
	var image := get_viewport().get_texture().get_image()
	image.resize(TAILLE.x, TAILLE.y, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	image.save_jpg(ProjectSettings.globalize_path(DOSSIER + id + ".jpg"), 0.85)
	print("vignette ", id)
	get_tree().quit()


func _physics_process(_delta: float) -> void:
	if _session == null or _branche or not _session.en_course:
		return
	_branche = true
	var joueur := _session.entries[0]
	var ia := AIInput.new()
	joueur.kart.add_child(ia)
	joueur.kart.changer_pilote(ia)
	_session.brancher_ia(ia)
	ia.track = joueur.progress.track
