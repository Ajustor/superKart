class_name RaceSession
extends Node

## Met les karts et le circuit en rapport. Les karts ignorent le circuit, le
## circuit ignore les karts : c'est ici et nulle part ailleurs que les deux se
## parlent.
##
## Le concurrent d'indice 0 est le joueur — c'est lui que le HUD suit. Rien
## d'autre ne distingue les huit : l'IA passe par le même KartCommand et subit
## la même physique, donc elle ne peut pas tricher.

## Les karts sont posés sur leur case : la grille existe.
signal grille_prete
## Chaque seconde du décompte, de `duree_decompte` jusqu'à 1.
signal decompte(secondes: int)
## Le feu passe au vert : les karts sont lâchés.
signal depart
## Un concurrent vient de boucler un tour, arrivée comprise.
signal tour_boucle(entree: RaceEntry)
## Un concurrent vient de franchir la ligne pour la dernière fois.
signal arrivee(entree: RaceEntry)
## Tout le monde a fini.
signal course_terminee

## Profondeur sous la route, en mètres, au-delà de laquelle on considère que le
## kart est tombé dans le vide.
##
## Relative à la route, et non à l'altitude zéro. C'était un plancher absolu à
## -10 m, écrit quand la piste était plate : dès qu'elle a gagné du relief,
## 18 % de la chaussée s'est retrouvée SOUS son propre plancher anti-chute et le
## kart était téléporté 88 % des images, immobilisé au premier creux.
const FALL_DEPTH := 12.0
const OFF_TRACK_RESPAWN_MARGIN := 3.0

## Distance de départ le long de l'axe, pour la première case de grille.
const DEPART := 0.0

## Deux colonnes, comme une vraie grille : huit karts en file indienne
## s'étireraient sur trente mètres et le dernier ne verrait jamais le premier.
const GRID_COLUMNS := 2

## Écart entre deux rangées, en mètres le long de l'axe.
const GRID_ROW_SPACING := 5.0

## Demi-écartement des colonnes, en mètres de part et d'autre de la ligne de
## course. Reste bien en deçà de la demi-largeur de 9 m, y compris là où la
## ligne de course mord déjà le bord intérieur d'un virage.
const GRID_COLUMN_OFFSET := 2.5

## Recul de la colonne de droite par rapport à celle de gauche, en mètres.
## Une grille alignée au cordeau n'existe nulle part, et décaler donne à
## chaque kart une distance de départ qui lui est propre.
const GRID_COLUMN_STAGGER := 2.5

@export var track_path: NodePath
@export var kart_paths: Array[NodePath] = []
@export var lap_count: int = 3

## Case de départ du joueur, 1 = pole position. Zéro ou au-delà du nombre de
## concurrents : le fond de la grille, là où l'on part quand personne n'a rien
## choisi.
@export var case_du_joueur: int = 0

## Durée du décompte, en secondes. Les karts sont figés sur leur case tant
## qu'il court : sans lui, le premier arrivé au clavier partait avant les
## autres, et l'IA — qui n'attend personne — avait pris cinq mètres avant que
## la première image ne soit affichée.
@export var duree_decompte: float = 3.0

## Clé des records. Vide quand la course ne vient pas du menu.
@export var id_piste: String = ""

## Noms des concurrents, dans l'ordre de kart_paths.
@export var noms: PackedStringArray = []

var entries: Array[RaceEntry] = []

## Faux pendant le décompte, vrai dès le vert, et le reste après l'arrivée :
## les karts qui ont fini continuent de rouler.
var en_course: bool = false

## Vrai quand le dernier concurrent a franchi la ligne.
var terminee: bool = false

## Temps restant avant le vert, en secondes.
var decompte_restant: float = 0.0

var _arrives: int = 0
var _derniere_seconde_annoncee: int = -1

var _track: Track
var _demi_largeur: float = 0.0
var _cerveaux: Array[AIInput] = []


func _ready() -> void:
	# get_node lèverait l'erreur avant l'assert, et les assert disparaissent en
	# export release : le message n'aurait servi à personne.
	var piste := get_node_or_null(track_path) as Track
	assert(piste != null, "track_path doit pointer vers un Track")
	# Un circuit posé par RaceLauncher à la place de celui de la scène n'est
	# plus forcément prêt avant nous : mesuré, il l'était après, et sa courbe
	# n'existait pas encore. Son signal tombe dans la même image, avant la
	# première image de physique : personne ne roule entre-temps.
	if not piste.is_node_ready():
		await piste.ready

	var pilotes: Array[Kart] = []
	for chemin in kart_paths:
		var k := get_node_or_null(chemin) as Kart
		assert(k != null, "chaque entrée de kart_paths doit pointer vers un Kart")
		pilotes.append(k)

	for k in pilotes:
		for enfant in k.get_children():
			if enfant is AIInput:
				brancher_ia(enfant as AIInput)

	demarrer(piste, pilotes)


## Déclare une IA à nourrir. Appelée depuis _ready pour chaque kart dont
## l'entrée en est une ; les tests l'appellent directement.
func brancher_ia(cerveau: AIInput) -> void:
	if cerveau != null and not _cerveaux.has(cerveau):
		_cerveaux.append(cerveau)


## Prend le circuit et les karts en paramètres plutôt que de les lire dans
## l'arbre : c'est toute la différence entre une logique testable et une
## logique qu'on ne peut qu'espérer juste.
func demarrer(piste: Track, pilotes: Array[Kart]) -> void:
	assert(lap_count > 0, "une course sans tour à boucler ne finit jamais")
	assert(not pilotes.is_empty(), "une course a besoin d'au moins un concurrent")
	_track = piste
	_demi_largeur = _track.track_curve.half_width

	entries.clear()
	_arrives = 0
	terminee = false
	decompte_restant = maxf(duree_decompte, 0.0)
	en_course = decompte_restant <= 0.0
	_derniere_seconde_annoncee = -1

	var cases := cases_attribuees(pilotes.size(), case_du_joueur)
	for i in pilotes.size():
		var case_ := case_de_grille(cases[i])
		var place := _track.spawn_at(case_.x, case_.y)
		pilotes[i].respawn_at(place)
		pilotes[i].controle_actif = en_course
		var entree := RaceEntry.new(pilotes[i], _track.track_curve, case_.x)
		entree.nom = noms[i] if i < noms.size() else "Pilote %d" % (i + 1)
		entree.case_de_grille = cases[i]
		entries.append(entree)
		# L'IA décide à partir des valeurs de l'image précédente : sans
		# amorçage, sa toute première décision viserait l'origine du monde.
		# On lui donne la case de grille et non kart.global_position, qui
		# échoue hors de l'arbre et rendrait cette ligne intestable.
		_nourrir_ia(entree, place.origin)
	grille_prete.emit()


## Distance le long de l'axe (x) et décalage latéral (y) de la case donnée,
## 0 = pole position. Deux colonnes décalées, rangées de cinq mètres.
static func case_de_grille(index: int) -> Vector2:
	var rangee := index / GRID_COLUMNS
	var colonne := index % GRID_COLUMNS
	var distance := DEPART \
		- float(rangee) * GRID_ROW_SPACING \
		- float(colonne) * GRID_COLUMN_STAGGER
	# -1 pour la colonne de gauche, +1 pour celle de droite.
	var lateral := (float(colonne) - 0.5) * 2.0 * GRID_COLUMN_OFFSET
	return Vector2(distance, lateral)


## La case de chaque concurrent, dans l'ordre des concurrents, à partir de 0.
## Le joueur (indice 0) prend celle qu'il a choisie ; les autres remplissent
## les cases restantes dans leur ordre de déclaration — la scène déclare l'IA
## de la plus rapide à la plus lente, donc la plus rapide part devant.
static func cases_attribuees(concurrents: int, case_joueur: int) -> Array[int]:
	var cases: Array[int] = []
	if concurrents <= 0:
		return cases
	var du_joueur := case_joueur - 1
	if du_joueur < 0 or du_joueur >= concurrents:
		du_joueur = concurrents - 1
	cases.append(du_joueur)
	var libre := 0
	for i in range(1, concurrents):
		if libre == du_joueur:
			libre += 1
		cases.append(libre)
		libre += 1
	return cases


## Le circuit monté. ItemManager en a besoin pour faire rebondir les
## carapaces sur ses murs.
func circuit() -> Track:
	return _track


## Transformée de la case donnée sur le circuit monté. Le marquage au sol s'en
## sert pour peindre la grille exactement là où les karts sont posés.
func transformee_de_case(index: int) -> Transform3D:
	var case_ := case_de_grille(index)
	return _track.spawn_at(case_.x, case_.y)


## Fait avancer le décompte et lâche les karts au vert. Séparé de
## _physics_process pour que les tests le pilotent à la main.
func avancer_decompte(delta: float) -> void:
	if en_course or entries.is_empty():
		return
	decompte_restant = maxf(decompte_restant - delta, 0.0)
	if decompte_restant > 0.0:
		var seconde := ceili(decompte_restant)
		if seconde != _derniere_seconde_annoncee:
			_derniere_seconde_annoncee = seconde
			decompte.emit(seconde)
		return
	en_course = true
	for entree in entries:
		entree.kart.controle_actif = true
	depart.emit()


func _physics_process(delta: float) -> void:
	avancer_decompte(delta)
	for entree in entries:
		avancer(entree, entree.kart.global_position, delta)
	classer()


## Le point est passé plutôt que lu sur le kart : global_position exige
## l'arbre de scènes, et c'est le seul obstacle qui rendait cette logique
## intestable.
func avancer(entree: RaceEntry, point: Vector3, delta: float) -> void:
	entree.progress.update(point)
	_nourrir_ia(entree, point)

	# La comptabilité s'arrête à l'arrivée ; le monde, lui, continue. Et elle
	# ne commence qu'au vert : le décompte ne compte dans aucun chrono.
	if en_course and not entree.finished:
		entree.timer.advance(delta)
		entree.temps_course += delta
		# progress.lap n'est pas monotone : il redescend quand le kart recule.
		# Se déclencher sur sa montée enregistrait un tour à chaque
		# franchissement, donc reculer sur la ligne d'arrivée fabriquait un
		# meilleur temps de deux images. On compte sur une ligne de crue.
		if entree.progress.lap > entree.tours_comptes:
			entree.tours_comptes = entree.progress.lap
			entree.timer.complete_lap()
			if entree.tours_comptes >= lap_count:
				_franchir_l_arrivee(entree, point)
			tour_boucle.emit(entree)

	# Une seule projection par image et par kart : is_off_track la referait
	# entièrement, et la remise en piste une troisième fois.
	var d := entree.progress.distance
	var lateral := _track.track_curve.lateral_offset(point)
	var ecart := absf(lateral)
	# Hors du bitume, ou sur une zone hors-piste posée sur la route.
	var dehors := ecart > _demi_largeur or _track.en_zone_hors_piste(d, lateral)
	entree.kart.set_offroad(dehors)

	if entree.en_vol and entree.kart.au_sol:
		entree.en_vol = false
	var tremplin := _track.tremplin_en(d, lateral)
	if tremplin != null and entree.kart.sauter(tremplin.impulsion):
		entree.en_vol = true
		entree.kart.motor.accorder_turbo(tremplin.duree_turbo, tremplin.force_turbo)

	if not dehors:
		# On remet en piste là où le kart roulait encore, pas là où la courbe
		# projette son point de sortie. Dans l'épingle la courbe se replie sur
		# elle-même : le point le plus proche d'une sortie de 29 m s'y trompe
		# de 48 m — en arrière d'un côté, mais en avant de l'autre. Reprojeter
		# ne punissait donc pas seulement la sortie de route, elle pouvait
		# aussi l'offrir en raccourci.
		entree.derniere_en_piste = entree.progress.distance

	# L'altitude de la route sous le kart, et non une constante : sur une piste
	# à plusieurs niveaux, « en bas » ne veut rien dire dans l'absolu.
	var sol := _track.track_curve.position_at(entree.progress.distance).y
	# Trop loin du bitume, et sans rien sous les roues : ni zone hors-piste, ni
	# saut en cours. Un kart qui survole un virage depuis un tremplin a le
	# droit d'être loin de la route ; il n'a pas celui d'y atterrir à côté.
	var perdu := ecart > _demi_largeur + OFF_TRACK_RESPAWN_MARGIN \
		and not entree.en_vol and not _track.sol_praticable(d, lateral)
	if point.y < sol - FALL_DEPTH or perdu:
		entree.kart.respawn_at(_track.spawn_at(entree.derniere_en_piste))


func _franchir_l_arrivee(entree: RaceEntry, point: Vector3) -> void:
	entree.finished = true
	_arrives += 1
	entree.place_finale = _arrives
	if entree.kart.est_pilote_par_le_joueur():
		_passer_en_pilote_automatique(entree, point)
	arrivee.emit(entree)
	if _arrives >= entries.size():
		terminee = true
		course_terminee.emit()


## Une fois la ligne franchie, le kart du joueur finit son tour d'honneur tout
## seul, comme dans tous les jeux de kart : le joueur regarde ses résultats,
## et un kart abandonné au milieu de la piste serait un obstacle pour ceux qui
## courent encore.
func _passer_en_pilote_automatique(entree: RaceEntry, point: Vector3) -> void:
	var cerveau := AIInput.new()
	cerveau.name = "PiloteAutomatique"
	entree.kart.add_child(cerveau)
	entree.kart.changer_pilote(cerveau)
	brancher_ia(cerveau)
	# Nourrie tout de suite : le kart la consultera avant notre prochaine
	# image, et une IA sans circuit ne sait pas où viser.
	_nourrir_ia(entree, point)


## Attribue les places, 1 au plus avancé. Ceux qui ont fini sont classés
## dans leur ordre d'arrivée, devant tous les autres.
##
## Les autres sont triés sur la distance parcourue et sur rien d'autre : un
## couple (tour, position sur l'axe) mettrait devant un kart qui a reculé sous
## la ligne, parce que sa position d'axe est alors proche de la fin du tour.
## `total` porte le signe que ce couple perd.
func classer() -> void:
	# Sur la grille, la place est la case. Tous les `total` valent zéro à
	# quelques millimètres de tassement près, et ce bruit-là affichait le
	# joueur en pole « 8e ».
	if not en_course:
		for entree in entries:
			entree.position = entree.case_de_grille + 1
		return
	var ordre := entries.duplicate()
	ordre.sort_custom(func(a: RaceEntry, b: RaceEntry) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.place_finale < b.place_finale
		return a.progress.total > b.progress.total)
	for i in ordre.size():
		ordre[i].position = i + 1


## Les concurrents dans l'ordre du classement.
func classement() -> Array[RaceEntry]:
	var ordre: Array[RaceEntry] = entries.duplicate()
	ordre.sort_custom(func(a: RaceEntry, b: RaceEntry) -> bool:
		return a.position < b.position)
	return ordre


## Donne à l'IA de ce kart ce qu'elle ne peut pas aller chercher seule. Elle
## pourrait projeter sa propre position, mais ce serait une projection de plus
## par kart et par image — et lire global_position l'empêcherait d'être testée
## hors de l'arbre.
func _nourrir_ia(entree: RaceEntry, point: Vector3) -> void:
	for cerveau in _cerveaux:
		if cerveau.kart == entree.kart:
			cerveau.track = _track.track_curve
			cerveau.distance = entree.progress.distance
			cerveau.position = point
			return
