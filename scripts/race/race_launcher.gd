class_name RaceLauncher
extends RefCounted

## Monte une course à partir des choix du menu, puis la lance.
##
## La scène est modifiée AVANT d'entrer dans l'arbre : aucun _ready n'a encore
## tourné, donc on peut y remplacer le circuit et régler la session sans que
## rien n'ait eu le temps de lire l'ancien. Lancée seule depuis l'éditeur,
## race.tscn garde son circuit et ses valeurs par défaut.

const SCENE_COURSE := "res://scenes/race.tscn"
const SCENE_MENU := "res://scenes/ui/main_menu.tscn"
## Les nœuds d'ambiance de race.tscn qu'un circuit peut remplacer par les siens.
const AMBIANCE := ["WorldEnvironment", "DirectionalLight3D"]


static func lancer(arbre: SceneTree, reglage: RaceSetup) -> void:
	arbre.paused = false
	arbre.change_scene_to_node(monter(reglage))


## Une course en réseau : même scène, mais la grille vient du plan de l'hôte,
## et chaque kart est simulé sur la machine de son pilote.
static func lancer_reseau(arbre: SceneTree, plan: Array, config: Dictionary, moi: int, hote: bool) -> void:
	arbre.paused = false
	arbre.change_scene_to_node(monter_reseau(plan, config, moi, hote))


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

	var session := course.get_node("Session") as RaceSession
	session.lap_count = maxi(reglage.tours, 1)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	session.case_du_joueur = reglage.case_effective(session.kart_paths.size(), rng)
	session.id_piste = reglage.piste.id if reglage.piste != null else ""
	return course


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
	var humains: Array[bool] = []
	for gid in ordre:
		var place: Dictionary = plan[gid]
		chemins.append(NodePath("../" + noeuds[gid]))
		cases.append(gid)
		noms.append("Vous" if gid == local_gid else place.nom)
		humains.append(place.peer != 0)
		var kart := course.get_node(noeuds[gid]) as Kart
		# Simulé ici : le joueur local, et l'IA quand on est l'hôte.
		kart.simule = gid == local_gid or (hote and place.niveau_ia > 0)
	session.kart_paths = chemins
	session.cases_imposees = cases
	session.noms = noms
	session.humains = humains
	session.arbitre = hote
	session.attente_depart = true
	# Pas de record en réseau : les temps dépendent de qui roule devant qui.
	session.id_piste = ""

	var objets := course.get_node_or_null("Objets") as ItemManager
	if objets != null:
		objets.autorite = hote

	var sync := RaceSync.new()
	sync.name = "RaceSync"
	sync.configurer(plan, moi, hote)
	course.add_child(sync)
	return course
