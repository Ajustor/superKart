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
## Le départ du joueur : Depart.NORMAL, TURBO ou CALE.
signal depart_du_joueur(resultat: int)

## Le turbo au départ, comme dans les jeux de kart : tenir les gaz à partir du
## bon moment du décompte fait partir en trombe ; les tenir dès le début
## fait caler. Les instants sont comptés en secondes avant le vert.
enum Depart { NORMAL, TURBO, CALE }
## Commencer à accélérer plus tôt que ça : calé.
const DEPART_TROP_TOT := 1.5
## Commencer entre les deux : turbo. Plus tard : départ normal.
const DEPART_TURBO_DES := 0.25
const DEPART_TURBO_DUREE := 1.0
const DEPART_TURBO_FORCE := 1.35
const CALAGE := 0.8
## Une IA qui réagit au moins aussi vite réussit son départ.
const IA_REACTION_TURBO := 0.3

## Profondeur sous la route, en mètres, au-delà de laquelle on considère que le
## kart est tombé dans le vide.
##
## Relative à la route, et non à l'altitude zéro. C'était un plancher absolu à
## -10 m, écrit quand la piste était plate : dès qu'elle a gagné du relief,
## 18 % de la chaussée s'est retrouvée SOUS son propre plancher anti-chute et le
## kart était téléporté 88 % des images, immobilisé au premier creux.
const FALL_DEPTH := 12.0
const OFF_TRACK_RESPAWN_MARGIN := 3.0
## Plus bas que la chaussée de tant, à côté d'elle : on n'est plus sur la
## route, on est en dessous (HAUTEUR_SOUS_LA_ROUTE), puis on en est tombé.
const HAUTEUR_SOUS_LA_ROUTE := 2.0
const HAUTEUR_DE_CHUTE := 3.5
## Dans l'herbe, on peut gagner un peu plus de tracé qu'on n'en roule — à
## l'intérieur d'un virage, la corde est plus courte que l'axe —, pas
## couper une épingle.
const RACCOURCI_TOLERE := 1.6
const RACCOURCI_MARGE := 15.0

## Distance de la ligne de départ le long de l'axe.
const DEPART := 0.0

## Recul de la première case derrière la ligne, en mètres. À zéro, le kart en
## pole avait le nez sur la peinture et le portique lui cachait le reste :
## c'était trop proche.
const RECUL_GRILLE := 6.0

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

## Les vrais noms, dans l'ordre de kart_paths, là où `noms` affiche « Vous »
## pour le joueur local. En réseau, c'est sous ce nom que la coupe compte ses
## points, le même sur toutes les machines. Vide en solo : `noms` suffit.
var noms_reels: PackedStringArray = []

## Qui est piloté par un humain, dans l'ordre de kart_paths. Vide en solo :
## seul le premier, le joueur, l'est.
var humains: Array[bool] = []

## En réseau : la case de chaque concurrent, dans l'ordre de kart_paths,
## décidée par l'hôte. Vide en solo, où case_du_joueur suffit.
var cases_imposees: Array[int] = []

## Faux sur un client en réseau : l'hôte décide des arrivées et du
## classement, et RaceSync les recopie ici. Le client compte quand même ses
## tours, pour le chrono et les annonces.
var arbitre: bool = true

## Vrai tant que le départ n'est pas donné. En réseau, le décompte attend que
## toutes les machines aient chargé la course.
var attente_depart: bool = false

var entries: Array[RaceEntry] = []

## Faux pendant le décompte, vrai dès le vert, et le reste après l'arrivée :
## les karts qui ont fini continuent de rouler.
var en_course: bool = false

## Vrai quand tout le monde est classé : le dernier concurrent l'est d'office
## dès que tous les autres ont franchi la ligne (voir _classer_le_dernier).
var terminee: bool = false
## Mode bataille : pas de tours à compter, les places viennent de Bataille.
var sans_tours: bool = false

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
	# Pendant le décompte, l'accélération automatique du tactile se retient :
	# elle tiendrait les gaz dès le premier feu, et le joueur calerait à
	# chaque course. C'est à lui de toucher GAZ au bon moment.
	TouchControls.gaz_auto_retenus = not en_course
	_derniere_seconde_annoncee = -1

	var cases := cases_attribuees(pilotes.size(), case_du_joueur)
	if cases_imposees.size() == pilotes.size():
		cases = cases_imposees
	for i in pilotes.size():
		var case_ := case_de_grille(cases[i])
		var place := _track.spawn_at(case_.x, case_.y)
		pilotes[i].respawn_at(place)
		pilotes[i].controle_actif = en_course
		var entree := RaceEntry.new(pilotes[i], _track.track_curve, case_.x)
		# L'avancement part de la case elle-même, en négatif : le tour se
		# boucle pour chacun en franchissant la ligne peinte. Donner à tous le
		# même retard faisait boucler les derniers de la grille jusqu'à
		# dix-sept mètres avant la ligne. Partir de plus loin coûte quelques
		# mètres, comme dans les jeux de kart.
		entree.progress.total = case_.x
		entree.nom = noms[i] if i < noms.size() else "Pilote %d" % (i + 1)
		entree.case_de_grille = cases[i]
		entree.humain = humains[i] if i < humains.size() else i == 0
		entries.append(entree)
		# L'IA décide à partir des valeurs de l'image précédente : sans
		# amorçage, sa toute première décision viserait l'origine du monde.
		# On lui donne la case de grille et non kart.global_position, qui
		# échoue hors de l'arbre et rendrait cette ligne intestable.
		_nourrir_ia(entree, place.origin)
	grille_prete.emit()


## Distance le long de l'axe (x) et décalage latéral (y) de la case donnée,
## 0 = pole position, quelques mètres derrière la ligne. Deux colonnes
## décalées, rangées de cinq mètres.
static func case_de_grille(index: int) -> Vector2:
	var rangee := index / GRID_COLUMNS
	var colonne := index % GRID_COLUMNS
	var distance := DEPART - RECUL_GRILLE \
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


## Le nom sous lequel ce concurrent compte dans une coupe.
func nom_reel(entree: RaceEntry) -> String:
	var i := entries.find(entree)
	if i >= 0 and i < noms_reels.size():
		return noms_reels[i]
	return entree.nom


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
	if en_course or entries.is_empty() or attente_depart:
		return
	decompte_restant = maxf(decompte_restant - delta, 0.0)
	for entree in entries:
		if not entree.kart.gaz_tenu:
			entree.gaz_depuis = -1.0
		elif entree.gaz_depuis < 0.0:
			entree.gaz_depuis = decompte_restant
	if decompte_restant > 0.0:
		var seconde := ceili(decompte_restant)
		if seconde != _derniere_seconde_annoncee:
			_derniere_seconde_annoncee = seconde
			decompte.emit(seconde)
		return
	en_course = true
	# Les obstacles mobiles partent du même instant sur toutes les machines.
	_track.horloge = 0.0
	TouchControls.gaz_auto_retenus = false
	for entree in entries:
		entree.kart.controle_actif = true
	depart.emit()
	for i in entries.size():
		var resultat := _partir(entries[i])
		if i == 0:
			depart_du_joueur.emit(resultat)


## Ce que vaut le départ de qui a commencé à tenir les gaz `gaz_depuis`
## secondes avant le vert (-1 : pas de gaz au vert).
static func resultat_du_depart(gaz_depuis: float) -> int:
	if gaz_depuis < 0.0:
		return Depart.NORMAL
	if gaz_depuis > DEPART_TROP_TOT:
		return Depart.CALE
	if gaz_depuis >= DEPART_TURBO_DES:
		return Depart.TURBO
	return Depart.NORMAL


func _partir(entree: RaceEntry) -> int:
	if not entree.kart.simule:
		return Depart.NORMAL
	var cerveau := entree.kart.pilote() as AIInput
	var resultat := resultat_du_depart(entree.gaz_depuis)
	if cerveau != null:
		# L'IA ne lit pas le décompte : les plus vives réussissent leur départ,
		# les autres partent normalement. Aucune ne cale.
		resultat = Depart.TURBO if cerveau.reaction_delay <= IA_REACTION_TURBO else Depart.NORMAL
	match resultat:
		Depart.TURBO:
			entree.kart.motor.accorder_turbo(DEPART_TURBO_DUREE, DEPART_TURBO_FORCE)
		Depart.CALE:
			entree.cale_restant = CALAGE
			entree.kart.controle_actif = false
	return resultat


func _physics_process(delta: float) -> void:
	avancer_decompte(delta)
	_relancer_les_cales(delta)
	for entree in entries:
		avancer(entree, entree.kart.global_position, delta)
	var positions: Array[Vector3] = []
	for entree in entries:
		positions.append(entree.kart.global_position)
	aspirer(positions, delta)
	classer()
	partager_la_course()
	_raconter_au_circuit()


func _relancer_les_cales(delta: float) -> void:
	for entree in entries:
		if entree.cale_restant <= 0.0:
			continue
		entree.cale_restant -= delta
		if entree.cale_restant <= 0.0 and en_course and not entree.finished:
			entree.kart.controle_actif = true


func _exit_tree() -> void:
	TouchControls.gaz_auto_retenus = false


## L'aspiration de chacun, d'après les positions de tous (dans l'ordre de
## `entries`) : dans le sillage d'un autre kart, la jauge monte ; pleine, un
## turbo. Seuls les karts simulés ici aspirent ; tous ont un sillage.
func aspirer(positions: Array[Vector3], delta: float) -> void:
	for i in entries.size():
		var entree := entries[i]
		var kart := entree.kart
		if not kart.simule:
			continue
		var aspire := false
		if en_course and not entree.finished and kart.au_sol \
				and kart.motor.state != KartMotor.State.STUNNED \
				and kart.motor.speed >= Aspiration.VITESSE_MIN * kart.motor.stats.max_speed:
			var cap := Aspiration.cap(kart.motor.velocity_dir)
			for j in entries.size():
				var autre := entries[j].kart
				if j == i or autre.motor.speed < Aspiration.VITESSE_DU_MENEUR:
					continue
				if Aspiration.dans_le_sillage(positions[i], cap, positions[j], Aspiration.cap(autre.motor.velocity_dir)):
					aspire = true
					break
		kart.motor.dans_le_sillage = aspire
		var resultat := Aspiration.charger(entree.aspiration, aspire, delta)
		entree.aspiration = resultat[0]
		if resultat[1]:
			kart.motor.accorder_turbo(Aspiration.DUREE_TURBO, Aspiration.FORCE_TURBO)
			kart.aspire.emit()
		kart.aspiration = entree.aspiration / Aspiration.CHARGE


## Le point est passé plutôt que lu sur le kart : global_position exige
## l'arbre de scènes, et c'est le seul obstacle qui rendait cette logique
## intestable.
func avancer(entree: RaceEntry, point: Vector3, delta: float) -> void:
	entree.progress.update(point)
	entree.lateral = _track.track_curve.lateral_offset_at(point, entree.progress.distance)
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
		if not sans_tours and lineaire():
			_avancer_en_ligne(entree, point)
		elif not sans_tours and entree.progress.lap > entree.tours_comptes:
			entree.tours_comptes = entree.progress.lap
			entree.timer.complete_lap()
			if entree.tours_comptes >= lap_count and arbitre:
				_franchir_l_arrivee(entree, point)
			tour_boucle.emit(entree)

	# Un kart piloté sur une autre machine : celle-ci s'occupe de sa physique,
	# de ses sauts et de ses remises en piste. Ici, on ne fait que le suivre.
	if not entree.kart.simule:
		return

	# Une seule projection par image et par kart : is_off_track la referait
	# entièrement, et la remise en piste une troisième fois.
	var d := entree.progress.distance
	var lateral := _track.track_curve.lateral_offset_at(point, d)
	var ecart := absf(lateral)
	# Hauteur au-dessus de la chaussée, prolongée à plat au-delà du bord
	# (comme le relief, TrackTerrain) : tombé d'un pont dans le pré d'en
	# dessous, on n'est pas sur la route qui passe au-dessus. Le long de la
	# normale, le bas-côté plat d'un virage relevé passait pour un fossé.
	var hauteur := hauteur_sur_la_route(point, d, lateral)
	var zone := _track.en_zone_hors_piste(d, lateral)
	var dehors := hors_piste(point, d, lateral)
	entree.kart.set_offroad(dehors)

	var rampe := _track.rampe_en(d, lateral)
	entree.kart.elan_de_rampe = rampe.vitesse_verticale(entree.kart.motor.speed) if rampe != null else 0.0
	if entree.kart.vient_de_decoller:
		entree.kart.vient_de_decoller = false
		entree.en_vol = true
	elif entree.en_vol and entree.kart.au_sol:
		entree.en_vol = false
	# Tombé dans un portail posé à plat : une chute voulue, un vol comme un
	# autre — il ne sera remis en piste que s'il atterrit à côté.
	var chute := _track.trou_en(d)
	if chute != null and chute.chute_voulue and not entree.kart.au_sol:
		entree.en_vol = true
		# Comme dans un portail du jeu de cubes : on tombe dedans, et l'on
		# ressort de l'autre côté, au bas du plongeon, sans rien perdre.
		var bord := _track.track_curve.position_at(chute.debut).y
		if point.y < bord - PROFONDEUR_DU_PORTAIL:
			var sortie := wrapf(chute.fin() + 6.0, 0.0, _track.track_curve.length)
			entree.kart.teleporter(_track.spawn_at(sortie))
			entree.derniere_en_piste = sortie
			entree.en_vol = false
			return
	var tremplin := _track.tremplin_en(d, lateral)
	if tremplin != null and entree.kart.sauter(tremplin.impulsion):
		entree.en_vol = true
		entree.kart.motor.accorder_turbo(tremplin.duree_turbo, tremplin.force_turbo)
	var plaque := _track.accelerateur_en(d, lateral)
	if plaque != null and entree.kart.au_sol:
		entree.kart.motor.accorder_turbo(plaque.duree_turbo, plaque.force_turbo)
	# La glace, le vent, l'apesanteur : le kart ne sait pas où il est, la
	# session lui dit ce que le sol et l'air lui font.
	var glace := _track.verglas_en(d, lateral)
	entree.kart.motor.adherence = glace.adherence if glace != null else 1.0
	entree.kart.vent = _track.poussee_en(d, lateral)
	entree.kart.gravite_facteur = _track.gravite_en(d, lateral)
	var anneau := _track.anneau_en(d, lateral,
		(point - _track.track_curve.position_at(d)).dot(_track.track_curve.up_at(d)))
	if anneau != null:
		entree.kart.motor.accorder_turbo(anneau.duree_turbo, anneau.force_turbo)
		anneau.briller()

	# Dans l'herbe d'un vrai sol : on y roule, mais on n'y coupe pas. Le
	# repère se pose à la première image dans l'herbe ; sur le bitume ou dans
	# une zone hors-piste — un raccourci voulu —, il n'y en a pas.
	var coupe := false
	if not dehors or zone:
		entree.roule_dehors = -1.0
	elif entree.roule_dehors < 0.0:
		entree.repere_dehors = d
		entree.roule_dehors = 0.0
	else:
		entree.roule_dehors += entree.kart.velocity.length() * delta
		var gagne := wrapf(d - entree.repere_dehors, -_track.track_curve.length * 0.5, _track.track_curve.length * 0.5)
		coupe = gagne > entree.roule_dehors * RACCOURCI_TOLERE + RACCOURCI_MARGE

	if not dehors and _track.trou_en(d) == null:
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
	#
	# Un vrai sol (TrackSol, TrackTerrain) porte le kart sur les bas-côtés,
	# jusqu'à PORTEE_HORS_PISTE du bord. Au-delà, ou tombé plus bas que la
	# route, il est sorti du circuit.
	# Le sol n'est interrogé que hors du bitume : sur la route, il ne sert à
	# rien, et c'est chaque image pour chaque kart.
	var perdu := false
	if not entree.en_vol:
		if ecart > _demi_largeur and hauteur < -HAUTEUR_DE_CHUTE:
			perdu = true
		elif ecart > _demi_largeur + OFF_TRACK_RESPAWN_MARGIN and not _track.sol_praticable(d, lateral):
			perdu = ecart > _demi_largeur + Track.PORTEE_HORS_PISTE or not _track.sol_reel(point, d)
	var noye := point.y < _track.altitude_du_liquide
	if point.y < sol - FALL_DEPTH or perdu or noye or coupe:
		var reprise := _track.point_de_reprise(entree.derniere_en_piste)
		entree.derniere_en_piste = reprise
		entree.kart.respawn_at(_track.spawn_at(reprise))


## La hauteur de ce point au-dessus de la chaussée, prolongée à plat au-delà
## du bord.
func hauteur_sur_la_route(point: Vector3, d: float, lateral: float) -> float:
	var c := _track.track_curve
	var niveau := c.position_at(d).y + c.right_at(d).y * clampf(lateral, -c.half_width, c.half_width)
	return point.y - niveau


## Hors piste en ce point : tout ce qui n'est pas le bitume — un sol, un
## relief, un bas-côté, une zone hors-piste posée sur la route, le pré sous un
## pont. Seule la chaussée entre ses deux bords (bordures comprises) est la
## piste.
func hors_piste(point: Vector3, d: float, lateral: float) -> bool:
	return absf(lateral) > _track.track_curve.half_width or _track.en_zone_hors_piste(d, lateral) \
		or hauteur_sur_la_route(point, d, lateral) < -HAUTEUR_SOUS_LA_ROUTE


## Une course linéaire : chaque section franchie se compte comme un tour (le
## compteur et la musique s'en servent), et l'arrivée est au bout du tracé,
## pas sur la ligne de départ. tours_comptes ne fait que monter : reculer
## dans la section précédente ne la fait pas recompter.
func _avancer_en_ligne(entree: RaceEntry, point: Vector3) -> void:
	if entree.tours_comptes >= etapes():
		return
	if entree.progress.total >= _track.arrivee:
		entree.tours_comptes = etapes()
		entree.timer.complete_lap()
		if arbitre:
			_franchir_l_arrivee(entree, point)
		tour_boucle.emit(entree)
		return
	var franchies := _track.section_en(entree.progress.total) - 1
	if franchies > entree.tours_comptes:
		entree.tours_comptes = franchies
		tour_boucle.emit(entree)


## Une course d'un bout à l'autre du circuit (Track.arrivee), sans tours.
func lineaire() -> bool:
	return _track != null and _track.lineaire()


## Les étapes de la course : ses tours, ou ses sections.
func etapes() -> int:
	return _track.nombre_de_sections() if lineaire() else lap_count


## L'étape où en est ce concurrent, de 1 à etapes().
func etape(entree: RaceEntry) -> int:
	if lineaire():
		return mini(_track.section_en(entree.progress.total), etapes())
	return mini(entree.progress.lap + 1, lap_count)


## « TOUR 2/3 », ou « SECTION 2/3 » en course linéaire.
func texte_etape(entree: RaceEntry) -> String:
	return "%s %d/%d" % ["SECTION" if lineaire() else "TOUR", etape(entree), etapes()]


## La profondeur, sous le bord d'un trou où l'on tombe exprès, où le kart
## passe de l'autre côté du portail.
const PROFONDEUR_DU_PORTAIL := 3.0


## En réseau, sur un client : l'hôte annonce une arrivée, on la recopie.
func appliquer_arrivee(entree: RaceEntry, place: int, temps: float, hors_temps := false) -> void:
	if entree.finished:
		return
	entree.temps_course = temps
	entree.hors_temps = hors_temps
	_arriver(entree, place, entree.kart.global_position if entree.kart.is_inside_tree() else Vector3.ZERO)


func _franchir_l_arrivee(entree: RaceEntry, point: Vector3) -> void:
	_arriver(entree, _arrives + 1, point)


func _arriver(entree: RaceEntry, place: int, point: Vector3) -> void:
	entree.finished = true
	_arrives += 1
	entree.place_finale = place
	# Seulement s'il roule ici : sur un serveur en ligne, le kart du joueur de
	# la scène porte un autre humain, piloté chez lui.
	if entree.kart.est_pilote_par_le_joueur() and entree.kart.simule:
		_passer_en_pilote_automatique(entree, point)
	arrivee.emit(entree)
	entree.kart.geste.emit(Kart.GESTE_VICTOIRE if place <= 3 else Kart.GESTE_DEFAITE)
	if _arrives >= entries.size():
		terminee = true
		course_terminee.emit()
	else:
		_classer_le_dernier()


## Quand il ne reste qu'un concurrent en piste, la course s'arrête : il est
## classé à la dernière place libre, sans attendre qu'il finisse ses tours.
##
## Pas en contre-la-montre, où l'on court seul : c'est son arrivée qui finit
## la course. Pas en bataille, qui classe elle-même (sans_tours). Et pas sur
## un client en réseau : l'hôte décide, et envoie cette arrivée comme les
## autres.
func _classer_le_dernier() -> void:
	if not arbitre or sans_tours or entries.size() < 2 or _arrives != entries.size() - 1:
		return
	for entree in entries:
		if not entree.finished:
			entree.hors_temps = true
			var point := entree.kart.global_position if entree.kart.is_inside_tree() else Vector3.ZERO
			_arriver(entree, _place_libre(), point)
			return


## La plus petite place que personne n'a prise.
func _place_libre() -> int:
	var prises := {}
	for entree in entries:
		if entree.finished:
			prises[entree.place_finale] = true
	var place := 1
	while prises.has(place):
		place += 1
	return place


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
	# Sur un client en réseau, les places viennent de l'hôte.
	if not arbitre:
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


## Ce que chaque IA sait des autres : où ils sont sur la route (distance le
## long de l'axe, écart latéral) et à quelle vitesse. Un tableau partagé, dans
## l'ordre de `entries` ; chaque IA y connaît sa propre place.
func partager_la_course() -> void:
	if _cerveaux.is_empty():
		return
	var etat := PackedVector3Array()
	etat.resize(entries.size())
	for i in entries.size():
		var e := entries[i]
		etat[i] = Vector3(e.progress.distance, e.lateral, e.kart.motor.speed)
	for cerveau in _cerveaux:
		cerveau.voisins = etat
		for i in entries.size():
			if entries[i].kart == cerveau.kart:
				cerveau.mon_index = i
				break


## Le circuit sait où en sont le premier et le dernier encore en course :
## ses portails s'ouvrent et se ferment d'après eux (TrackPortail).
func _raconter_au_circuit() -> void:
	if _track == null or entries.is_empty():
		return
	var tete := -INF
	var queue := INF
	for e in entries:
		tete = maxf(tete, e.progress.total)
		if not e.finished:
			queue = minf(queue, e.progress.total)
	_track.tete_total = tete
	_track.queue_total = queue if queue < INF else tete
	_track.tours_course = lap_count
	# Chaque kart n'est dessiné que dans le monde où il roule : de ce côté-ci
	# d'un portail, ceux qui l'ont passé ne se voient qu'à travers lui.
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	for e in entries:
		var calque := _track.calque_a(e.progress.distance)
		if calque != 0 and calque != e.calque:
			e.calque = calque
			Track.poser_calque(e.kart, calque)
		# Caché à la caméra, il ne fait pas d'ombre non plus : son ombre
		# tomberait de ce côté-ci du portail, sous un kart invisible.
		if e.calque != 0 and camera != null:
			var vu := camera.cull_mask & e.calque != 0
			if vu != e.ombre_visible:
				e.ombre_visible = vu
				Track.poser_ombres(e.kart, vu)


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
			cerveau.zones_prudentes = _track.zones_prudentes()
			cerveau.plaques = _track.plaques_d_acceleration()
			cerveau.distance = entree.progress.distance
			cerveau.position = point
			return
