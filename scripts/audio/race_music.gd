class_name RaceMusic
extends Node

## La musique de la course : l'air du circuit (Track.musique), lancé au vert,
## plus vite au dernier tour, et qui s'efface à l'arrivée du joueur.
##
## La boucle se compose dans un fil à part pendant le décompte ; si elle
## n'est pas prête au vert, elle démarre dès qu'elle l'est. Une boucle déjà
## composée dans la partie démarre tout de suite.

## Au dernier tour, la musique accélère — et monte un peu, comme dans les jeux de kart.
const DERNIER_TOUR := 1.12
const VOLUME_DB := -4.0

var session: RaceSession

var _lecteur: AudioStreamPlayer
var _style: int = Musique.Style.COLLINES
var _tache: int = -1
var _depart_donne := false


func _ready() -> void:
	_lecteur = AudioStreamPlayer.new()
	_lecteur.bus = GameSettings.BUS_MUSIQUE
	_lecteur.volume_db = VOLUME_DB
	add_child(_lecteur)
	# L'air ne boucle pas de lui-même (voir Musique._en_wav) : on le relance.
	# À l'arrivée, stop() ne déclenche pas finished, et la musique se tait.
	_lecteur.finished.connect(_lecteur.play)
	if session.entries.is_empty():
		await session.grille_prete
	var piste := session.circuit()
	_style = piste.musique if piste != null else Musique.Style.COLLINES
	if Musique.deja_composee(_style) == null:
		_tache = WorkerThreadPool.add_task(Musique.composer.bind(_style), false, "musique")
	session.depart.connect(func() -> void:
		_depart_donne = true
		_lancer())
	session.tour_boucle.connect(_sur_tour)


func _process(_delta: float) -> void:
	if _tache >= 0 and WorkerThreadPool.is_task_completed(_tache):
		WorkerThreadPool.wait_for_task_completion(_tache)
		_tache = -1
		if _depart_donne:
			_lancer()


func _exit_tree() -> void:
	# Un fil qui compose encore ne doit pas survivre à la course sans qu'on
	# l'ait attendu : Godot le signale, et la boucle reste utile au cache.
	if _tache >= 0:
		WorkerThreadPool.wait_for_task_completion(_tache)
		_tache = -1


func _lancer() -> void:
	var flux := Musique.deja_composee(_style)
	if flux == null or _lecteur.playing:
		return
	_lecteur.stream = flux
	_lecteur.play()


func _sur_tour(entree: RaceEntry) -> void:
	if session.entries.is_empty() or entree != session.entries[0]:
		return
	if entree.finished:
		var fondu := create_tween()
		fondu.tween_property(_lecteur, "volume_db", -40.0, 1.5)
		fondu.tween_callback(_lecteur.stop)
	elif entree.tours_comptes == session.etapes() - 1:
		create_tween().tween_property(_lecteur, "pitch_scale", DERNIER_TOUR, 0.6)
