class_name RaceSession
extends Node

## Met les karts et le circuit en rapport. Les karts ignorent le circuit, le
## circuit ignore les karts : c'est ici et nulle part ailleurs que les deux se
## parlent.
##
## Le concurrent d'indice 0 est le joueur — c'est lui que le HUD suit. Rien
## d'autre ne distingue les huit : l'IA passe par le même KartCommand et subit
## la même physique, donc elle ne peut pas tricher.

const FLOOR_LIMIT := -10.0
const OFF_TRACK_RESPAWN_MARGIN := 3.0

## Distance de départ le long de l'axe, pour la première case de grille.
const DEPART := 0.0

@export var track_path: NodePath
@export var kart_paths: Array[NodePath] = []
@export var lap_count: int = 3

var entries: Array[RaceEntry] = []

var _track: Track
var _demi_largeur: float = 0.0


func _ready() -> void:
	# get_node lèverait l'erreur avant l'assert, et les assert disparaissent en
	# export release : le message n'aurait servi à personne.
	var piste := get_node_or_null(track_path) as Track
	assert(piste != null, "track_path doit pointer vers un Track")

	var pilotes: Array[Kart] = []
	for chemin in kart_paths:
		var k := get_node_or_null(chemin) as Kart
		assert(k != null, "chaque entrée de kart_paths doit pointer vers un Kart")
		pilotes.append(k)

	demarrer(piste, pilotes)


## Prend le circuit et les karts en paramètres plutôt que de les lire dans
## l'arbre : c'est toute la différence entre une logique testable et une
## logique qu'on ne peut qu'espérer juste.
func demarrer(piste: Track, pilotes: Array[Kart]) -> void:
	assert(lap_count > 0, "une course sans tour à boucler ne finit jamais")
	assert(not pilotes.is_empty(), "une course a besoin d'au moins un concurrent")
	_track = piste
	_demi_largeur = _track.track_curve.half_width

	entries.clear()
	for i in pilotes.size():
		var depart := DEPART
		pilotes[i].respawn_at(_track.spawn_at(depart))
		entries.append(RaceEntry.new(pilotes[i], _track.track_curve, depart))


func _physics_process(delta: float) -> void:
	for entree in entries:
		avancer(entree, entree.kart.global_position, delta)


## Le point est passé plutôt que lu sur le kart : global_position exige
## l'arbre de scènes, et c'est le seul obstacle qui rendait cette logique
## intestable.
func avancer(entree: RaceEntry, point: Vector3, delta: float) -> void:
	entree.progress.update(point)

	# La comptabilité s'arrête à l'arrivée ; le monde, lui, continue.
	if not entree.finished:
		entree.timer.advance(delta)
		# progress.lap n'est pas monotone : il redescend quand le kart recule.
		# Se déclencher sur sa montée enregistrait un tour à chaque
		# franchissement, donc reculer sur la ligne d'arrivée fabriquait un
		# meilleur temps de deux images. On compte sur une ligne de crue.
		if entree.progress.lap > entree.tours_comptes:
			entree.tours_comptes = entree.progress.lap
			entree.timer.complete_lap()
			if entree.tours_comptes >= lap_count:
				entree.finished = true

	# Une seule projection par image et par kart : is_off_track la referait
	# entièrement, et la remise en piste une troisième fois.
	var ecart := absf(_track.track_curve.lateral_offset(point))
	var dehors := ecart > _demi_largeur
	entree.kart.set_offroad(dehors)
	if not dehors:
		# On remet en piste là où le kart roulait encore, pas là où la courbe
		# projette son point de sortie. Dans l'épingle la courbe se replie sur
		# elle-même : le point le plus proche d'une sortie de 29 m s'y trompe
		# de 48 m — en arrière d'un côté, mais en avant de l'autre. Reprojeter
		# ne punissait donc pas seulement la sortie de route, elle pouvait
		# aussi l'offrir en raccourci.
		entree.derniere_en_piste = entree.progress.distance

	if point.y < FLOOR_LIMIT or ecart > _demi_largeur + OFF_TRACK_RESPAWN_MARGIN:
		entree.kart.respawn_at(_track.spawn_at(entree.derniere_en_piste))
