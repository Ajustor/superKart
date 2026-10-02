class_name CourseDeFond
extends Node

## La course qui se joue derrière le menu : huit IA sur un circuit tiré au
## sort, filmées comme à la télévision — la caméra passe d'un kart à l'autre
## toutes les quelques secondes. Ni écran de course, ni son : le menu garde sa
## musique, et rien n'attend le joueur.
##
## Coupée en qualité basse (un petit téléphone a mieux à faire), sans écran, et
## quand le joueur la désactive dans les options.

## Secondes passées derrière un kart avant de couper sur un autre.
const PLAN := 8.0
## Un tour de trop pour finir avant que le joueur ne lance la sienne.
const TOURS := 99

signal prete

var course: Node
var session: RaceSession
var camera: ChaseCamera
var _depuis_plan := 0.0
var _rng := RandomNumberGenerator.new()
var _ia_branchee := false


## Faut-il la montrer ici et maintenant ?
static func possible() -> bool:
	if DisplayServer.get_name() == "headless" or ServeurDedie.actif:
		return false
	if not GameSettings.course_de_fond:
		return false
	return QualiteGraphique.effectif(GameSettings.qualite) != QualiteGraphique.Niveau.BASSE


func _ready() -> void:
	_rng.randomize()
	course = monter(_rng)
	session = course.get_node("Session") as RaceSession
	camera = course.get_node_or_null("ChaseCamera") as ChaseCamera
	if camera != null:
		# Plus haut et plus loin qu'en course : le kart suivi passe derrière
		# la colonne de boutons, on veut voir la course autour.
		camera.distance = 10.0
		camera.height = 4.5
	add_child(course)


## La course, prête à entrer dans l'arbre : sans interface ni son, sans
## décompte, et le kart du joueur confié lui aussi à l'IA.
static func monter(rng: RandomNumberGenerator) -> Node:
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.PISTES[rng.randi_range(0, TrackCatalog.PISTES.size() - 1)])
	reglage.mode = RaceSetup.Mode.COURSE
	reglage.tours = TOURS
	reglage.couleur = rng.randi_range(0, ModeleKart.COULEURS.size() - 1)
	reglage.personnage = rng.randi_range(0, Personnage.nombre() - 1)
	reglage.modele = rng.randi_range(0, ModeleKart.nombre() - 1)
	var course := RaceLauncher.monter(reglage, rng)
	var session := course.get_node("Session") as RaceSession
	session.duree_decompte = 0.0
	session.id_piste = ""
	for nom in ["HUD", "RaceSounds"]:
		var noeud := course.get_node_or_null(nom)
		if noeud != null:
			course.remove_child(noeud)
			noeud.free()
	# Le bruit des moteurs aussi : huit karts derrière un menu, c'est un
	# bourdonnement, pas une ambiance.
	for son in course.find_children("*", "AudioStreamPlayer", true, false) \
			+ course.find_children("*", "AudioStreamPlayer3D", true, false):
		son.get_parent().remove_child(son)
		son.free()
	return course


func _physics_process(delta: float) -> void:
	if session == null or session.entries.is_empty():
		return
	if not _ia_branchee:
		_ia_branchee = true
		_confier_le_joueur_a_l_ia()
		prete.emit()
	_depuis_plan += delta
	if camera != null and _depuis_plan >= PLAN:
		_depuis_plan = 0.0
		_couper_sur(session.entries[_rng.randi_range(0, session.entries.size() - 1)].kart)


func _confier_le_joueur_a_l_ia() -> void:
	var joueur := session.entries[0]
	if joueur.kart.pilote() is AIInput:
		return
	var ia := AIInput.new()
	joueur.kart.add_child(ia)
	joueur.kart.changer_pilote(ia)
	session.brancher_ia(ia)
	ia.track = joueur.progress.track


## Un cut, comme en régie : la caméra se replace d'un coup derrière l'autre kart.
func _couper_sur(kart: Kart) -> void:
	camera.suivre(kart)
