class_name RaceLauncher
extends RefCounted

## Monte une course à partir des choix du menu, puis la lance.
##
## La scène est modifiée AVANT d'entrer dans l'arbre : aucun _ready n'a encore
## tourné, donc on peut y remplacer le circuit et régler la session sans que
## rien n'ait eu le temps de lire l'ancien. race.tscn n'a qu'un circuit
## minimal (la courbe des Collines, sans décor) : charger la scène de course
## ne charge ainsi aucun circuit complet, seul celui qu'on court l'est.
## Lancée seule depuis l'éditeur, elle roule sur ce circuit nu.

const SCENE_COURSE := "res://scenes/race.tscn"
const SCENE_MENU := "res://scenes/ui/main_menu.tscn"
## Les nœuds d'ambiance de race.tscn qu'un circuit peut remplacer par les siens.
const AMBIANCE := ["WorldEnvironment", "DirectionalLight3D"]


## Passe par l'écran de chargement (EcranChargement) : il s'affiche tout de
## suite, charge et monte la course derrière lui, et s'efface au départ.
static func lancer(arbre: SceneTree, reglage: RaceSetup) -> void:
	arbre.paused = false
	_par_l_ecran(arbre, EcranChargement.pour_reglage(reglage))


## Une course en réseau : même scène, mais la grille vient du plan de l'hôte,
## et chaque kart est simulé sur la machine de son pilote. L'écran de
## chargement attend en plus que tous les joueurs soient prêts.
static func lancer_reseau(arbre: SceneTree, plan: Array, config: Dictionary, moi: int, hote: bool) -> void:
	arbre.paused = false
	var ecran := EcranChargement.new()
	ecran.fabrique = func() -> Node: return monter_reseau(plan, config, moi, hote)
	ecran.a_charger = PackedStringArray([SCENE_COURSE])
	var piste := TrackCatalog.par_id(str(config.get("piste", "")))
	if piste != null:
		ecran.a_charger.append(piste.chemin_scene)
		ecran.titre = piste.nom
		ecran.description = piste.description
	var classe := Cylindree.nom(int(config.get("cylindree", Cylindree.Classe.CC150)))
	ecran.sous_titre = "En ligne · %s · %d tour%s" % [classe, int(config.get("tours", 3)),
		"s" if int(config.get("tours", 3)) > 1 else ""]
	if config.has("gp"):
		var gp := GrandPrix.depuis(config.gp)
		ecran.sous_titre = "En ligne · %s · course %d/%d · %s" % [gp.nom(), gp.manche + 1, gp.manches(), classe]
	_par_l_ecran(arbre, ecran)


## L'écran devient la scène courante le temps du chargement ; il se glisse
## ensuite lui-même dans la course.
##
## En réseau, l'attente porte le nom de la course et une doublure de RaceSync,
## sans course : entre deux manches, les états envoyés par l'autre machine
## juste avant le changement arrivent encore, adressés à « Race/RaceSync ».
## Sans nœud à ce chemin, Godot les rejette avec une erreur ; la doublure
## les reçoit et les ignore.
static func _par_l_ecran(arbre: SceneTree, ecran: EcranChargement) -> void:
	var attente := Node.new()
	attente.name = "Chargement"
	if Reseau.actif():
		attente.name = "Race"
		var doublure := RaceSync.new()
		doublure.name = "RaceSync"
		attente.add_child(doublure)
	attente.add_child(ecran)
	arbre.change_scene_to_node(attente)


static func retour_au_menu(arbre: SceneTree) -> void:
	arbre.paused = false
	arbre.change_scene_to_file(SCENE_MENU)


## Rend la course prête à entrer dans l'arbre. Séparé de `lancer` pour pouvoir
## être testé sans changer de scène.
static func monter(reglage: RaceSetup, rng: RandomNumberGenerator = null) -> Node:
	var course := (load(SCENE_COURSE) as PackedScene).instantiate()

	if reglage.piste != null and reglage.piste.scene != null:
		var ancienne := course.get_node("Track")
		var nouvelle := reglage.piste.scene.instantiate()
		if reglage.miroir and nouvelle is Track:
			Miroir.appliquer(nouvelle as Track)
		# Pas replace_by : il déménage les enfants de l'ancien circuit dans le
		# nouveau, et chaque circuit héritait des murs, rampes et trous du
		# circuit par défaut de race.tscn.
		var place := ancienne.get_index()
		course.remove_child(ancienne)
		ancienne.free()
		nouvelle.name = "Track"
		course.add_child(nouvelle)
		course.move_child(nouvelle, place)
		# Un circuit peut apporter son ciel et sa lumière : ils remplacent
		# ceux de la scène de course, qui restent ceux des autres.
		for nom in AMBIANCE:
			if nouvelle.has_node(nom) and course.has_node(nom):
				course.get_node(nom).free()

	QualiteGraphique.appliquer_a(course, GameSettings.qualite)

	var session := course.get_node("Session") as RaceSession
	session.lap_count = maxi(reglage.tours, 1)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	session.case_du_joueur = reglage.case_effective(session.kart_paths.size(), rng)
	session.id_piste = reglage.cle_record()

	match reglage.mode:
		RaceSetup.Mode.GRAND_PRIX:
			if reglage.grand_prix != null:
				session.cases_imposees = reglage.grand_prix.cases(session.noms)
		RaceSetup.Mode.CONTRE_LA_MONTRE:
			_seul_en_piste(course, session)
		RaceSetup.Mode.BATAILLE:
			_en_bataille(course, session)
	_habiller(session, reglage)
	Cylindree.appliquer(course, reglage.classe_effective())
	return course


## Le kart du joueur prend le modèle et la couleur choisis au garage ; l'IA,
## les autres couleurs de la palette.
static func _habiller(session: RaceSession, reglage: RaceSetup) -> void:
	var libres := ModeleKart.couleurs_libres([reglage.couleur])
	for k in session.kart_paths.size():
		var kart := session.get_node_or_null(session.kart_paths[k]) as Kart
		if kart == null:
			continue
		if k == 0:
			kart.stats = ModeleKart.stats(kart.stats, reglage.modele)
			ModeleKart.habiller(kart, reglage.modele, ModeleKart.couleur(reglage.couleur))
		else:
			ModeleKart.habiller(kart, ModeleKart.STANDARD, ModeleKart.couleur(libres[(k - 1) % libres.size()]))


## La bataille : pas de tours ni de record, la table d'objets de l'arène, et
## l'arbitre des ballons.
static func _en_bataille(course: Node, session: RaceSession) -> void:
	session.sans_tours = true
	session.id_piste = ""
	var objets := course.get_node_or_null("Objets") as ItemManager
	if objets != null:
		objets.bataille = true
		objets.table = Bataille.table()
	# Ni grille, ni damier, ni portique : on ne part ni n'arrive nulle part.
	var marquage := course.get_node_or_null("GridMarkings")
	if marquage != null:
		course.remove_child(marquage)
		marquage.free()
	var bataille := Bataille.new()
	bataille.name = "Bataille"
	bataille.session_path = NodePath("../Session")
	bataille.objets_path = NodePath("../Objets")
	course.add_child(bataille)


## Le contre-la-montre : le kart du joueur seul, sans boîtes, trois
## champignons en poche, et son fantôme s'il en a un.
static func _seul_en_piste(course: Node, session: RaceSession) -> void:
	var joueur := session.kart_paths[0]
	for chemin in session.kart_paths.slice(1):
		var kart := session.get_node_or_null(chemin)
		if kart != null:
			kart.get_parent().remove_child(kart)
			kart.free()
	var seul: Array[NodePath] = [joueur]
	session.kart_paths = seul
	session.noms = PackedStringArray([session.noms[0] if not session.noms.is_empty() else "Vous"])
	session.case_du_joueur = 1
	var objets := course.get_node_or_null("Objets") as ItemManager
	if objets != null:
		objets.contre_la_montre = true
	var fantome := FantomeCourse.new()
	fantome.name = "Fantome"
	fantome.session_path = NodePath("../Session")
	course.add_child(fantome)


## Monte une course en réseau à partir du plan de l'hôte. La scène a toujours
## le même casting — un kart de joueur, sept karts d'IA du plus rapide au plus
## lent — et chaque machine le distribue à sa façon :
## - le kart de joueur est toujours le pilote local : c'est lui que suivent la
##   caméra, le HUD, le son et les vibrations ;
## - chaque IA du plan prend le kart d'IA de son niveau ;
## - les autres humains prennent les karts d'IA restants, qui ne sont alors
##   plus pilotés ici mais recopiés depuis le réseau.
static func monter_reseau(plan: Array, config: Dictionary, moi: int, hote: bool) -> Node:
	var reglage := RaceSetup.new()
	var piste := TrackCatalog.par_id(str(config.get("piste", "")))
	if piste != null:
		reglage.choisir_piste(piste)
	reglage.tours = int(config.get("tours", reglage.tours))
	reglage.classe = int(config.get("cylindree", Cylindree.Classe.CC150))
	reglage.miroir = bool(config.get("miroir", false))
	var course := monter(reglage)
	var session := course.get_node("Session") as RaceSession

	var libres: Array[String] = []
	for i in range(1, Lobby.PLACES):
		libres.append("AIKart%d" % i)
	var noeuds := {}  # gid -> nom de nœud
	var local_gid := -1
	for place in plan:
		if place.peer == moi:
			local_gid = place.gid
			noeuds[place.gid] = "Kart"
		elif place.niveau_ia > 0:
			noeuds[place.gid] = "AIKart%d" % place.niveau_ia
			libres.erase(noeuds[place.gid])
	for place in plan:
		if not noeuds.has(place.gid):
			noeuds[place.gid] = libres.pop_front()

	# Le joueur local d'abord : le HUD suit toujours la première entrée.
	var ordre: Array = [local_gid]
	for place in plan:
		if place.gid != local_gid:
			ordre.append(place.gid)
	var chemins: Array[NodePath] = []
	var cases: Array[int] = []
	var noms := PackedStringArray()
	var noms_reels := PackedStringArray()
	var humains: Array[bool] = []
	for gid in ordre:
		var place: Dictionary = plan[gid]
		chemins.append(NodePath("../" + noeuds[gid]))
		cases.append(gid)
		noms.append("Vous" if gid == local_gid else place.nom)
		noms_reels.append(place.nom)
		humains.append(place.peer != 0)
		var kart := course.get_node(noeuds[gid]) as Kart
		# Simulé ici : le joueur local, et l'IA quand on est l'hôte.
		kart.simule = gid == local_gid or (hote and place.niveau_ia > 0)
	session.kart_paths = chemins
	session.cases_imposees = cases
	session.noms = noms
	session.noms_reels = noms_reels
	session.humains = humains
	session.arbitre = hote
	session.attente_depart = true
	# Pas de record en réseau : les temps dépendent de qui roule devant qui.
	session.id_piste = ""

	# Chaque humain dans le kart de son garage, sur toutes les machines : la
	# couleur se voit, le poids compte dans les chocs. L'IA prend les
	# couleurs restantes.
	var prises := []
	for place in plan:
		if int(place.peer) != 0:
			prises.append(int(place.get("couleur", 0)))
	var teintes_ia := ModeleKart.couleurs_libres(prises)
	var n_ia := 0
	for place in plan:
		var kart := course.get_node(noeuds[place.gid]) as Kart
		if int(place.peer) != 0:
			var modele := int(place.get("modele", ModeleKart.STANDARD))
			kart.stats = ModeleKart.stats(kart.stats, modele)
			ModeleKart.habiller(kart, modele, ModeleKart.couleur(int(place.get("couleur", 0))))
		else:
			ModeleKart.habiller(kart, ModeleKart.STANDARD, ModeleKart.couleur(teintes_ia[n_ia % teintes_ia.size()]))
			n_ia += 1

	var objets := course.get_node_or_null("Objets") as ItemManager
	if objets != null:
		objets.autorite = hote

	var sync := RaceSync.new()
	sync.name = "RaceSync"
	sync.configurer(plan, moi, hote)
	course.add_child(sync)
	return course
