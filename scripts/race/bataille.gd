class_name Bataille
extends Node

## Le mode bataille : chaque kart porte trois ballons, chaque objet qui le
## touche en crève un, et sans ballon on est éliminé. Le dernier en lice
## gagne ; au bout du temps, on classe au nombre de ballons.
##
## Pas de tours : la session ne compte rien (RaceSession.sans_tours), c'est
## ici que se décident les places, qu'on donne à la session comme des
## arrivées. Tout ce qui suit une course — l'écran des résultats, la
## musique, la fin — suit donc la bataille sans la connaître.

signal ballon_perdu(entree: RaceEntry, restants: int)
signal elimine(entree: RaceEntry)

const BALLONS := 3
const DUREE := 180.0
## Au-dessus de la caisse : on voit d'un coup d'œil où en est chacun.
const HAUTEUR_BALLONS := 1.45
## La table de tirage de la bataille, une seule ligne : ni carapace bleue,
## ni éclair, ni pièces — pas de premier à rattraper ni de pointe à gagner.
## Dans l'ordre de ItemKind.TIRABLES.
const TIRAGE := [14.0, 6.0, 18.0, 26.0, 20.0, 0.0, 0.0, 8.0, 8.0, 0.0]

@export var session_path: NodePath
@export var objets_path: NodePath

## RaceEntry -> ballons restants.
var ballons: Dictionary = {}
var temps_restant: float = DUREE
var finie := false

var _session: RaceSession
var _visuels: Dictionary = {}


static func table() -> ItemTable:
	var t := ItemTable.new()
	var ligne: Array[PackedFloat32Array] = [PackedFloat32Array(TIRAGE)]
	t.lignes = ligne
	return t


func _ready() -> void:
	var session := get_node(session_path) as RaceSession
	if session.entries.is_empty():
		await session.grille_prete
	preparer(session, get_node_or_null(objets_path) as ItemManager)


## Donne les ballons, disperse les karts dans l'arène et écoute les objets.
## Appelé par _ready ; les tests l'appellent directement.
func preparer(session: RaceSession, objets: ItemManager) -> void:
	_session = session
	for entree in session.entries:
		ballons[entree] = BALLONS
		_poser_ballons(entree)
	if objets != null:
		objets.kart_touche.connect(perdre_ballon)
		objets.kart_foudroye.connect(perdre_ballon)
	_disperser()


## Pas de grille : les karts partent répartis tout autour de l'anneau, en
## quinconce d'un bord à l'autre. Ils se croiseront bien assez tôt.
func _disperser() -> void:
	var circuit := _session.circuit()
	if circuit == null or circuit.track_curve == null:
		return
	var longueur := circuit.track_curve.length
	var n := _session.entries.size()
	for i in n:
		var d := longueur * float(i) / float(n)
		var lateral := circuit.half_width * 0.4 * (1.0 if i % 2 == 0 else -1.0)
		var kart := _session.entries[i].kart
		if not kart.is_inside_tree():
			continue
		kart.respawn_at(circuit.spawn_at(d, lateral))
		_session.entries[i].derniere_en_piste = d


func _physics_process(delta: float) -> void:
	if finie or _session == null or not _session.en_course:
		return
	temps_restant = maxf(temps_restant - delta, 0.0)
	classer()
	if vivants().size() <= 1 or temps_restant <= 0.0:
		terminer()


## Ceux qui ont encore des ballons.
func vivants() -> Array[RaceEntry]:
	var liste: Array[RaceEntry] = []
	for entree in _session.entries:
		if not entree.finished and int(ballons.get(entree, 0)) > 0:
			liste.append(entree)
	return liste


func perdre_ballon(entree: RaceEntry) -> void:
	if finie or entree.finished or int(ballons.get(entree, 0)) <= 0:
		return
	ballons[entree] = int(ballons[entree]) - 1
	_poser_ballons(entree)
	ballon_perdu.emit(entree, int(ballons[entree]))
	if int(ballons[entree]) == 0:
		_eliminer(entree)


## Sans ballon : classé derrière tous ceux qui en ont encore, et hors jeu.
func _eliminer(entree: RaceEntry) -> void:
	var joueur := entree.kart.est_pilote_par_le_joueur()
	_session.appliquer_arrivee(entree, vivants().size() + 1, entree.temps_course)
	entree.inventaire.vider()
	entree.kart.controle_actif = false
	if not joueur and entree.kart.is_inside_tree():
		# Un kart d'IA éliminé quitte l'arène : arrêté au milieu de l'anneau,
		# il ne serait qu'un obstacle.
		entree.kart.visible = false
		entree.kart.simule = false
		entree.kart.global_position += Vector3.DOWN * 200.0
	elimine.emit(entree)


## Le temps est écoulé, ou il n'en reste qu'un : les survivants sont classés
## au nombre de ballons, puis dans l'ordre de la grille.
func terminer() -> void:
	if finie:
		return
	finie = true
	var restants := _par_ballons(vivants())
	# Du dernier au premier : chaque arrivée garde sa place, mais l'écran
	# des résultats du joueur s'ouvre sur un classement déjà complet.
	for i in range(restants.size() - 1, -1, -1):
		_session.appliquer_arrivee(restants[i], i + 1, restants[i].temps_course)


## Les places : les vivants au nombre de ballons, puis les éliminés dans
## l'ordre de leur élimination.
func classer() -> void:
	var ordre := _par_ballons(vivants())
	for i in ordre.size():
		ordre[i].position = i + 1
	for entree in _session.entries:
		if entree.finished:
			entree.position = entree.place_finale


func _par_ballons(liste: Array[RaceEntry]) -> Array[RaceEntry]:
	var tries := liste.duplicate()
	tries.sort_custom(func(a: RaceEntry, b: RaceEntry) -> bool:
		var ba := int(ballons.get(a, 0))
		var bb := int(ballons.get(b, 0))
		if ba != bb:
			return ba > bb
		return _session.entries.find(a) < _session.entries.find(b))
	return tries


## Les ballons au-dessus du kart, de la couleur de sa caisse.
func _poser_ballons(entree: RaceEntry) -> void:
	var kart := entree.kart
	var grappe: Node3D = _visuels.get(entree)
	if grappe == null:
		grappe = Node3D.new()
		grappe.name = "Ballons"
		# Derrière le pilote : devant, ils cacheraient la route à la caméra.
		grappe.position = Vector3(0, HAUTEUR_BALLONS, 0.75)
		kart.add_child(grappe)
		_visuels[entree] = grappe
		var materiau := StandardMaterial3D.new()
		materiau.albedo_color = _couleur(kart).lightened(0.15)
		materiau.roughness = 0.25
		materiau.emission_enabled = true
		materiau.emission = materiau.albedo_color
		materiau.emission_energy_multiplier = 0.25
		for i in BALLONS:
			var ballon := MeshInstance3D.new()
			var forme := SphereMesh.new()
			forme.radius = 0.26
			forme.height = 0.62
			ballon.mesh = forme
			ballon.material_override = materiau
			ballon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ballon.position = Vector3((i - 1) * 0.42, 0.12 if i == 1 else 0.0, 0.0)
			grappe.add_child(ballon)
	var restants := int(ballons.get(entree, 0))
	for i in grappe.get_child_count():
		(grappe.get_child(i) as Node3D).visible = i < restants


static func _couleur(kart: Node) -> Color:
	var plancher := kart.get_node_or_null("Body/Floor") as MeshInstance3D
	if plancher != null and plancher.get_surface_override_material(0) is StandardMaterial3D:
		return (plancher.get_surface_override_material(0) as StandardMaterial3D).albedo_color
	return Color(0.9, 0.2, 0.2)
