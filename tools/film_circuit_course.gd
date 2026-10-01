extends Node

## Filme un circuit depuis la caméra de poursuite, comme le verrait le
## joueur : son kart est confié à l'IA, et le tournage s'arrête une seconde
## après qu'il a bouclé le nombre de tours demandé (un par défaut).
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 \
##       --fixed-fps 30 --write-movie tour.avi -s tools/film_circuit.gd -- <id> [case] [tours]
##
## `--write-movie` est le mode Movie Maker de Godot : une image tous les
## trentièmes de seconde de jeu, quel que soit le temps qu'elle prend à
## rendre, et le son avec. ffmpeg en fait ensuite une vidéo légère :
##
##   ffmpeg -i tour.avi -c:v libx264 -crf 28 -preset veryfast -c:a aac tour.mp4

## Au-delà, on coupe : un kart bloqué ne doit pas filmer sans fin.
const LIMITE := 240.0

var _session: RaceSession
var _tours := 1
var _fin := -1.0
var _temps := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var piste := TrackCatalog.par_id(args[0] if not args.is_empty() else "circuit_01")
	if piste == null:
		printerr("circuit inconnu")
		get_tree().quit(1)
		return
	var reglage := RaceSetup.new()
	reglage.choisir_piste(piste)
	# Au milieu de la grille : on voit les autres karts, devant et derrière.
	reglage.case_de_depart = int(args[1]) if args.size() > 1 else 4
	_tours = int(args[2]) if args.size() > 2 else 1
	var course := RaceLauncher.monter(reglage)
	get_tree().root.add_child.call_deferred(course)
	_session = course.get_node("Session")
	_session.id_piste = ""
	# Pas de commandes tactiles à l'écran : elles cacheraient la piste.
	GameSettings.tactile = GameSettings.Tactile.JAMAIS


func _physics_process(delta: float) -> void:
	if _session == null or _session.entries.is_empty():
		return
	_temps += delta
	var joueur := _session.entries[0]
	if not joueur.kart.pilote() is AIInput:
		var ia := AIInput.new()
		joueur.kart.add_child(ia)
		joueur.kart.changer_pilote(ia)
		_session.brancher_ia(ia)
		ia.track = joueur.progress.track
	if _fin < 0.0 and joueur.tours_comptes >= _tours:
		_fin = _temps + 1.0
	if (_fin > 0.0 and _temps >= _fin) or _temps > LIMITE:
		get_tree().quit()
