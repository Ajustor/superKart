class_name RaceSounds
extends Node

## Les sons de la course : les bips du décompte, le signal du départ, le tour
## bouclé et l'arrivée du joueur. N'écoute que la session : ne sait rien des
## karts ni de l'écran.

@export var session_path: NodePath
@export var items_path: NodePath

var _session: RaceSession
var _lecteur: AudioStreamPlayer
var _bip: AudioStreamWAV
var _go: AudioStreamWAV
var _tour: AudioStreamWAV
var _arrivee: AudioStreamWAV
var _boite: AudioStreamWAV
var _lancer: AudioStreamWAV
var _choc: AudioStreamWAV
## Un second lecteur pour les objets : un bip de tour ne doit pas couper le
## bruit du choc qui tombe à la même image.
var _lecteur_objets: AudioStreamPlayer


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

	_lecteur_objets = AudioStreamPlayer.new()
	_lecteur_objets.bus = &"Effets"
	add_child(_lecteur_objets)
	_boite = Synth.notes([[988.0, 0.05], [1319.0, 0.07]], 0.35)
	_lancer = Synth.notes([[523.0, 0.04], [392.0, 0.06]], 0.35)
	_choc = Synth.notes([[220.0, 0.07], [165.0, 0.09], [110.0, 0.16]], 0.55)
	var objets := get_node_or_null(items_path) as ItemManager
	if objets != null:
		objets.objet_recu.connect(func(e: RaceEntry, _o: int) -> void: _jouer_objet(e, _boite))
		objets.objet_utilise.connect(func(e: RaceEntry, _o: int) -> void: _jouer_objet(e, _lancer))
		objets.kart_touche.connect(func(e: RaceEntry) -> void: _jouer_objet(e, _choc))


## Seulement pour le joueur : entendre sept adversaires ramasser des boîtes ne
## dirait rien de ce qui compte.
func _jouer_objet(entree: RaceEntry, son: AudioStream) -> void:
	if _session.entries.is_empty() or entree != _session.entries[0]:
		return
	_lecteur_objets.stream = son
	_lecteur_objets.play()


func _sur_tour(entree: RaceEntry) -> void:
	if _session.entries.is_empty() or entree != _session.entries[0]:
		return
	_jouer(_arrivee if entree.finished else _tour)


func _jouer(son: AudioStream) -> void:
	_lecteur.stream = son
	_lecteur.play()
