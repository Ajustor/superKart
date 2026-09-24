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
var _turbo_depart: AudioStreamWAV
var _calage: AudioStreamWAV
var _figure: AudioStreamWAV
## Un second lecteur pour les objets : un bip de tour ne doit pas couper le
## bruit du choc qui tombe à la même image.
var _lecteur_objets: AudioStreamPlayer
## Un troisième pour les chocs du joueur (murs, retombées, karts) : ils
## tombent souvent en même temps qu'un objet.
var _lecteur_chocs: AudioStreamPlayer
var _mur: AudioStreamWAV
var _retombee: AudioStreamWAV
var _bousculade: AudioStreamWAV
## Temps, en secondes, avant qu'un autre choc puisse sonner : un kart qui
## frotte un mur le heurte à chaque image.
var _repos_chocs: float = 0.0

## Entre un choc de `force` minimale et un de `force` pleine, le volume va de
## CHOC_MIN à 1.
const CHOC_MIN := 0.25
const REPOS_CHOCS := 0.18


func _ready() -> void:
	_session = get_node_or_null(session_path) as RaceSession
	assert(_session != null, "session_path doit pointer vers une RaceSession")
	_lecteur = AudioStreamPlayer.new()
	_lecteur.bus = &"Effets"
	add_child(_lecteur)
	var musique := RaceMusic.new()
	musique.session = _session
	add_child(musique)

	_bip = Synth.notes([[440.0, 0.18]])
	_go = Synth.notes([[880.0, 0.5]])
	_tour = Synth.notes([[660.0, 0.08], [880.0, 0.12]], 0.4)
	_arrivee = Synth.notes([[523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [1047.0, 0.4]])

	_session.decompte.connect(func(_s: int) -> void: _jouer(_bip))
	_session.depart.connect(func() -> void: _jouer(_go))
	# Après le « go » : une montée pour le turbo, un raté pour le calage.
	_turbo_depart = Synth.notes([[523.0, 0.05], [784.0, 0.05], [1047.0, 0.05], [1568.0, 0.18]], 0.45)
	_calage = Synth.notes([[196.0, 0.08], [0.0, 0.05], [185.0, 0.08], [0.0, 0.05], [147.0, 0.22]], 0.5)
	_session.depart_du_joueur.connect(_sur_depart_du_joueur)
	_figure = Synth.notes([[784.0, 0.04], [988.0, 0.04], [1319.0, 0.08]], 0.4)
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
	# En dernier : la grille n'est peut-être pas encore posée, et attendre
	# plus haut aurait retardé tout le reste.
	if _session.entries.is_empty():
		await _session.grille_prete
	var joueur := _session.entries[0]
	_lecteur_chocs = AudioStreamPlayer.new()
	_lecteur_chocs.bus = &"Effets"
	add_child(_lecteur_chocs)
	# De la tôle pour un mur, un coup sourd pour une retombée, entre les deux
	# pour un autre kart.
	_mur = Synth.choc(0.28, 120.0, 0.55, 0.6)
	_retombee = Synth.choc(0.22, 75.0, 0.12, 0.6)
	_bousculade = Synth.choc(0.16, 210.0, 0.75, 0.5)
	joueur.kart.motor.choc_mur.connect(func(f: float) -> void: _choquer(_mur, f, 3.0, 14.0))
	joueur.kart.atterri.connect(func(v: float) -> void: _choquer(_retombee, v, Kart.ATTERRISSAGE_AUDIBLE, 12.0))
	joueur.kart.bouscule.connect(func(f: float) -> void: _choquer(_bousculade, f, 0.8, 10.0))
	joueur.kart.figure.connect(func() -> void: _jouer_objet(joueur, _figure))
	# Un « ding » à chaque palier de glisse, plus aigu de palier en palier,
	# puis un souffle au lâcher.
	var dings := [
		Synth.notes([[1047.0, 0.07]], 0.3),
		Synth.notes([[1319.0, 0.07]], 0.33),
		Synth.notes([[1568.0, 0.05], [2093.0, 0.08]], 0.36),
	]
	var souffle := Synth.notes([[392.0, 0.03], [523.0, 0.03], [784.0, 0.1]], 0.35)
	joueur.kart.motor.palier_atteint.connect(func(p: int) -> void:
		_jouer_objet(joueur, dings[mini(p, 3) - 1]))
	joueur.kart.motor.mini_turbo.connect(func(_p: int) -> void: _jouer_objet(joueur, souffle))


func _process(delta: float) -> void:
	_repos_chocs = maxf(_repos_chocs - delta, 0.0)


## Joue un choc d'autant plus fort que `force` approche de `pleine` ; rien
## sous `seuil`, ni pendant le repos qui suit le choc précédent.
func _choquer(son: AudioStream, force: float, seuil: float, pleine: float) -> void:
	if force < seuil or _repos_chocs > 0.0:
		return
	_repos_chocs = REPOS_CHOCS
	_lecteur_chocs.stream = son
	_lecteur_chocs.volume_db = linear_to_db(volume_du_choc(force, seuil, pleine))
	_lecteur_chocs.play()


static func volume_du_choc(force: float, seuil: float, pleine: float) -> float:
	return lerpf(CHOC_MIN, 1.0, clampf((force - seuil) / maxf(pleine - seuil, 0.001), 0.0, 1.0))


## Seulement pour le joueur : entendre sept adversaires ramasser des boîtes ne
## dirait rien de ce qui compte.
func _jouer_objet(entree: RaceEntry, son: AudioStream) -> void:
	if _session.entries.is_empty() or entree != _session.entries[0]:
		return
	_lecteur_objets.stream = son
	_lecteur_objets.play()


func _sur_depart_du_joueur(resultat: int) -> void:
	if resultat == RaceSession.Depart.TURBO:
		_jouer_objet(_session.entries[0], _turbo_depart)
	elif resultat == RaceSession.Depart.CALE:
		_jouer_objet(_session.entries[0], _calage)


func _sur_tour(entree: RaceEntry) -> void:
	if _session.entries.is_empty() or entree != _session.entries[0]:
		return
	_jouer(_arrivee if entree.finished else _tour)


func _jouer(son: AudioStream) -> void:
	_lecteur.stream = son
	_lecteur.play()
