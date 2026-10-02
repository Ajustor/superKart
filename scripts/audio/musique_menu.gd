class_name MusiqueMenu
extends Node

## L'air du menu : composé dans un fil à part au premier affichage (une
## seconde ou deux sur téléphone), puis lancé en fondu et joué en boucle tant
## que le menu est là. Une partie déjà lancée l'a en cache : au retour d'une
## course, il repart tout de suite.

const VOLUME_DB := -6.0
const FONDU := 1.5

var _lecteur: AudioStreamPlayer
var _tache: int = -1


func _ready() -> void:
	_lecteur = AudioStreamPlayer.new()
	_lecteur.bus = GameSettings.BUS_MUSIQUE
	_lecteur.volume_db = -40.0
	add_child(_lecteur)
	if Musique.deja_composee(Musique.Style.MENU) == null:
		_tache = WorkerThreadPool.add_task(Musique.composer.bind(Musique.Style.MENU), false, "musique du menu")
	else:
		_lancer()


func _process(_delta: float) -> void:
	if _tache >= 0 and WorkerThreadPool.is_task_completed(_tache):
		WorkerThreadPool.wait_for_task_completion(_tache)
		_tache = -1
		_lancer()


func _exit_tree() -> void:
	if _tache >= 0:
		WorkerThreadPool.wait_for_task_completion(_tache)
		_tache = -1


func joue() -> bool:
	return _lecteur != null and _lecteur.playing


func _lancer() -> void:
	_lecteur.stream = Musique.deja_composee(Musique.Style.MENU)
	_lecteur.play()
	create_tween().tween_property(_lecteur, "volume_db", VOLUME_DB, FONDU)
