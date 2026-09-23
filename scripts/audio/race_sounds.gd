class_name RaceSounds
extends Node

## Les sons de la course : les bips du décompte, le signal du départ, le tour
## bouclé et l'arrivée du joueur. N'écoute que la session : ne sait rien des
## karts ni de l'écran.

@export var session_path: NodePath

var _session: RaceSession
var _lecteur: AudioStreamPlayer
var _bip: AudioStreamWAV
var _go: AudioStreamWAV
var _tour: AudioStreamWAV
var _arrivee: AudioStreamWAV


func _ready() -> void:
	_session = get_node_or_null(session_path) as RaceSession
	assert(_session != null, "session_path doit pointer vers une RaceSession")
	_lecteur = AudioStreamPlayer.new()
	_lecteur.bus = &"Effets"
	add_child(_lecteur)

	_bip = Synth.notes([[440.0, 0.18]])
	_go = Synth.notes([[880.0, 0.5]])
	_tour = Synth.notes([[660.0, 0.08], [880.0, 0.12]], 0.4)
	_arrivee = Synth.notes([[523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [1047.0, 0.4]])

	_session.decompte.connect(func(_s: int) -> void: _jouer(_bip))
	_session.depart.connect(func() -> void: _jouer(_go))
	_session.tour_boucle.connect(_sur_tour)


func _sur_tour(entree: RaceEntry) -> void:
	if _session.entries.is_empty() or entree != _session.entries[0]:
		return
	_jouer(_arrivee if entree.finished else _tour)


func _jouer(son: AudioStream) -> void:
	_lecteur.stream = son
	_lecteur.play()
