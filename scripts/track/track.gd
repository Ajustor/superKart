@tool
class_name Track
extends Node3D

## Assemble un circuit : la courbe qui le définit, le maillage extrudé et la
## collision. Tout est construit au chargement, donc modifier la courbe suffit
## à redéfinir la piste, sa collision et la trajectoire de l'IA d'un seul geste.
##
## `@tool` pour que ce « d'un seul geste » soit vrai dans l'éditeur aussi :
## sans lui le nœud y reste vide et la route n'apparaît qu'une fois le jeu
## lancé, ce qui rend le tracé impossible à dessiner à la souris. Les nœuds
## construits ici n'ont volontairement pas d'`owner` : Godot ne sauvegarde que
## ce qui en a un, donc le maillage ne se fige jamais dans le `.tscn` et reste
## toujours le produit de la courbe.

const NOM_MAILLAGE := "RoadMesh"
const NOM_CORPS := "RoadBody"
const NOM_BORDURES := "Bordures"
const NOM_TABLIER := "Tablier"
const NOM_MARQUAGE := "Marquage"

## L'allure de la chaussée.
enum Motif {
	## Un ruban uni, de la couleur `road_color`.
	UNI,
	## Sept bandes de couleur dans le sens de la longueur, qui brillent un peu
	## dans le noir.
	ARC_EN_CIEL,
}

const ARC_EN_CIEL: PackedColorArray = [
	Color(0.95, 0.2, 0.25), Color(1.0, 0.55, 0.15), Color(1.0, 0.9, 0.2),
	Color(0.3, 0.85, 0.35), Color(0.2, 0.7, 1.0), Color(0.35, 0.35, 0.95),
	Color(0.75, 0.35, 0.95),
]

@export var curve: Curve3D:
	set(valeur):
		if curve == valeur:
			return
		_suivre_courbe(false)
		curve = valeur
		_suivre_courbe(true)
		_reconstruire_si_montee()

@export var half_width: float = 9.0:
	set(valeur):
		half_width = valeur
		_reconstruire_si_montee()

@export var segment_length: float = 2.0:
	set(valeur):
		segment_length = valeur
		_reconstruire_si_montee()

## Rayon minimal, en mètres, en deçà duquel on prévient que le virage n'est pas
## franchissable.
##
## Calé sur le rayon de braquage du kart EN ADHÉRENCE : max_speed / turn_rate,
## soit 22 / 1,8 = 12,2 m. Le dérapage descend à 8,5 m, mais compter dessus
## reviendrait à exiger du joueur qu'il dérape à cet endroit précis, et l'IA,
## elle, ne dérape que dans les virages qu'elle a vus venir.
##
## Vérifié par la mesure : à 12,5 m de rayon minimal l'IA boucle ses trois tours
## sans se bloquer une seule image ; à 9,5 m elle restait coincée 446 images
## dans la même courbe.
@export var min_drivable_radius: float = 12.5

## Où poser les rangées de boîtes à objets, en fraction de la longueur du
## tour. Propre à chaque circuit : une rangée se pose sur une ligne droite, là
## où l'on a le temps de viser une boîte, jamais au milieu d'une épingle.
@export var rangees_objets: PackedFloat32Array = PackedFloat32Array([0.2, 0.5, 0.78])

@export var road_color: Color = Color(0.36, 0.38, 0.42):
	set(valeur):
		road_color = valeur
		_reconstruire_si_montee()

@export var motif: Motif = Motif.UNI:
	set(valeur):
		motif = valeur
		_reconstruire_si_montee()

## Bordures rouges et blanches sur les deux rives.
@export var bordures: bool = false:
	set(valeur):
		bordures = valeur
		_reconstruire_si_montee()

## Une ligne blanche discontinue au milieu de la chaussée.
@export var marquage: bool = true:
	set(valeur):
		marquage = valeur
		_reconstruire_si_montee()

@export var couleur_bordure: Color = Color(0.85, 0.12, 0.12):
	set(valeur):
		couleur_bordure = valeur
		_reconstruire_si_montee()

@export var couleur_bordure_bis: Color = Color(0.95, 0.95, 0.95):
	set(valeur):
		couleur_bordure_bis = valeur
		_reconstruire_si_montee()

## Altitude d'une étendue d'eau ou de lave sous le circuit. Un kart qui passe
## en dessous est remis en piste tout de suite, sans attendre d'être tombé de
## douze mètres : on ne nage pas dans la lave. Très bas par défaut : pas de
## liquide, on tombe dans le vide.
@export var altitude_du_liquide: float = -1000.0

## L'air qui accompagne la course (voir Musique).
@export var musique: Musique.Style = Musique.Style.COLLINES

## Zéro : une course en tours, la ligne de départ sert d'arrivée. Sinon, une
## course linéaire, d'un seul tenant, qui finit à cette distance du départ :
## on traverse le circuit d'un bout à l'autre sans repasser au même endroit.
## Le tracé reste une boucle — la suite de l'arrivée ramène au départ — mais
## on ne la court pas : elle n'est que le tour d'honneur de ceux qui ont fini.
@export var arrivee: float = 0.0

## Course linéaire : les distances du départ où commencent la deuxième
## section, la troisième… Le compteur affiche « SECTION 2/3 » à la place du
## numéro de tour.
@export var sections: PackedFloat32Array = PackedFloat32Array()

var track_curve: TrackCurve

## Secondes depuis le départ de la course : les obstacles mobiles s'y règlent.
## La session la remet à zéro au feu vert, sur chaque machine en réseau à la
## fois : les marteaux battent partout au même rythme.
var horloge: float = 0.0

## La course vue du circuit, tenue à jour par la session : la distance
## parcourue depuis le départ par le premier et par le dernier encore en
## course, et le nombre de tours. Les portails s'ouvrent et se ferment
## d'après elles ; la lune d'un spectacle descend avec l'avancement.
var tete_total: float = 0.0
var queue_total: float = 0.0
var tours_course: int = 3

var _elements: Array[TrackFeature] = []
var _elements_a_jour := false

## En deçà de cette distance avant un trou, un kart remis en piste l'est de
## l'autre côté : il faut plus d'élan que ça pour sauter.
const ELAN_AVANT_UN_TROU := 60.0
## Une IA reprend sa ligne tant de mètres avant une rampe ou un trou, et ne
## la quitte qu'autant après.
const ELAN_PRUDENT := 40.0
const RETOMBEE_PRUDENTE := 12.0

var _zones_prudentes := PackedVector2Array()
var _zones_a_jour := false
var _plaques := PackedVector4Array()
var _plaques_a_jour := false


func _ready() -> void:
	child_order_changed.connect(func() -> void:
		_elements_a_jour = false
		_zones_a_jour = false
		_plaques_a_jour = false)
	# En jeu, un circuit sans courbe est une erreur de montage. Dans l'éditeur
	# c'est l'état normal d'un nœud qu'on vient d'ajouter : on ne crie pas.
	assert(curve != null or Engine.is_editor_hint(), "un Track doit avoir une courbe")
	_suivre_courbe(true)
	_reconstruire()


## Reconstruit le maillage, sa collision et la courbe dérivée. Idempotent :
## les nœuds de la construction précédente sont retirés d'abord, sans quoi
## déplacer un point de contrôle empilerait une route de plus à chaque geste.
func _reconstruire() -> void:
	_vider()
	if curve == null or curve.point_count < 2:
		track_curve = null
		return

	track_curve = TrackCurve.new(curve, half_width)

	var arc_en_ciel := motif == Motif.ARC_EN_CIEL
	var maillage := TrackBuilder.build(track_curve, segment_length, trous(),
		ARC_EN_CIEL if arc_en_ciel else PackedColorArray())

	var materiau := StandardMaterial3D.new()
	materiau.albedo_color = road_color
	if arc_en_ciel:
		materiau.albedo_color = Color.WHITE
		materiau.vertex_color_use_as_albedo = true
		materiau.roughness = 0.35
		# Une lueur blanche discrète : dans le noir, la route se voit de loin
		# sans que ses couleurs se délavent.
		materiau.emission_enabled = true
		materiau.emission = Color(0.22, 0.22, 0.3)
	else:
		_asphalte = materiau
		detailler_l_asphalte(_detail_asphalte)
	maillage.surface_set_material(0, materiau)

	var affichage := MeshInstance3D.new()
	affichage.name = NOM_MAILLAGE
	affichage.mesh = maillage
	add_child(affichage)

	var corps := StaticBody3D.new()
	corps.name = NOM_CORPS
	var forme := CollisionShape3D.new()
	# La collision n'a que faire des couleurs : les sept bandes de
	# l'arc-en-ciel y feraient sept fois plus de triangles à tester, à chaque
	# roue et chaque image.
	var pour_la_collision := maillage
	if arc_en_ciel:
		pour_la_collision = TrackBuilder.build(track_curve, segment_length, trous())
	forme.shape = pour_la_collision.create_trimesh_shape()
	corps.add_child(forme)
	add_child(corps)

	# Le dessous de la route, pour qu'un pont se voie d'en bas.
	var tablier := MeshInstance3D.new()
	tablier.name = NOM_TABLIER
	tablier.mesh = TrackBuilder.tablier(track_curve, trous(), 0.9, segment_length)
	var beton := StandardMaterial3D.new()
	beton.vertex_color_use_as_albedo = true
	beton.albedo_color = road_color.lerp(Color(0.5, 0.48, 0.46), 0.5) if not arc_en_ciel else Color(0.3, 0.3, 0.42)
	beton.roughness = 0.9
	# Les deux faces : vue de côté ou d'en dessous, la dalle doit rester
	# pleine, et Godot retourne la normale des faces arrière.
	beton.cull_mode = BaseMaterial3D.CULL_DISABLED
	tablier.material_override = beton
	add_child(tablier)

	if marquage and not arc_en_ciel:
		var ligne_centrale := MeshInstance3D.new()
		ligne_centrale.name = NOM_MARQUAGE
		ligne_centrale.mesh = TrackBuilder.marquage(track_curve, trous())
		var peinture_blanche := StandardMaterial3D.new()
		peinture_blanche.albedo_color = Color(0.92, 0.92, 0.88)
		peinture_blanche.roughness = 0.6
		ligne_centrale.material_override = peinture_blanche
		ligne_centrale.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ligne_centrale)

	if bordures:
		var bandes := MeshInstance3D.new()
		bandes.name = NOM_BORDURES
		bandes.mesh = TrackBuilder.bordures(track_curve, trous(), 1.0, 3.0,
			couleur_bordure, couleur_bordure_bis)
		var peinture := StandardMaterial3D.new()
		peinture.vertex_color_use_as_albedo = true
		bandes.material_override = peinture
		add_child(bandes)

	# Les éléments posés sur le tracé le suivent : retoucher la courbe
	# déplace les murs, les tremplins et les zones avec elle.
	for element in elements():
		element.reconstruire()

	if Engine.is_editor_hint():
		update_configuration_warnings()


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		horloge += delta


## Où en est la course, de 0 (départ) à 1 (le premier franchit l'arrivée).
func avancement() -> float:
	var total := longueur_de_course()
	return clampf(tete_total / total, 0.0, 1.0) if total > 0.0 else 0.0


## Une course d'un bout à l'autre, sans tours (`arrivee`).
func lineaire() -> bool:
	return arrivee > 0.0


## Ce qu'il faut parcourir du départ à l'arrivée.
func longueur_de_course() -> float:
	if lineaire():
		return arrivee
	return track_curve.length * float(maxi(tours_course, 1)) if track_curve != null else 0.0


## La section où l'on est, à `total` mètres du départ (1 pour la première).
func section_en(total: float) -> int:
	var n := 1
	for debut_section in sections:
		if total >= debut_section:
			n += 1
	return n


func nombre_de_sections() -> int:
	return sections.size() + 1


## Au-delà de l'arrivée d'une course linéaire : la portion qu'on ne court pas.
func hors_course(distance: float) -> bool:
	return lineaire() and distance > arrivee and distance < track_curve.length - LONGUEUR_DE_GRILLE


## La grille, juste avant la ligne de départ : elle reste sur la carte même
## quand la boucle qui y ramène n'est pas courue.
const LONGUEUR_DE_GRILLE := 60.0


## Les portails du circuit, dans l'ordre du tracé.
func portails() -> Array[TrackPortail]:
	var liste: Array[TrackPortail] = []
	for element in elements():
		if element is TrackPortail:
			liste.append(element)
	liste.sort_custom(func(a: TrackPortail, b: TrackPortail) -> bool: return a.debut < b.debut)
	return liste


## Le ciel et la lumière à cette distance : ceux du dernier portail franchi,
## en faisant le tour (avant le premier portail, c'est le dernier qui vaut).
## Null : ceux du circuit.
func ambiance_en(distance: float) -> Environment:
	var portail := portail_en(distance)
	return portail.ambiance if portail != null else null


## Le dernier portail franchi à cette distance, en faisant le tour : l'époque,
## le monde où l'on est. Null s'il n'y a pas de portail.
func portail_en(distance: float) -> TrackPortail:
	var liste := portails()
	if liste.is_empty():
		return null
	var choisi := liste[liste.size() - 1]
	for portail in liste:
		if portail.debut <= distance:
			choisi = portail
	return choisi


## Le monde où l'on est à cette distance : le dernier portail franchi qui
## mène à un autre monde (TrackPortail.nouveau_monde), en faisant le tour.
func monde_en(distance: float) -> TrackPortail:
	var mondes: Array[TrackPortail] = []
	for portail in portails():
		if portail.nouveau_monde:
			mondes.append(portail)
	if mondes.is_empty():
		return null
	var choisi := mondes[mondes.size() - 1]
	for portail in mondes:
		if portail.debut <= distance:
			choisi = portail
	return choisi


## Chaque monde a son calque de rendu (VisualInstance3D.layers) : ses décors
## (TrackPortail.decors) n'y sont dessinés que pour une caméra qui le regarde.
## La caméra du joueur ne voit que le monde où elle est ; celle d'un portail,
## que le monde de l'autre côté. Tout le reste — la route, les karts, ce
## qu'aucun portail ne réclame — est commun à tous les mondes.
const CALQUE_COMMUN := 1
## Les surfaces des portails : la caméra du joueur les voit, celle d'un
## portail jamais (elle filmerait sa propre image).
const CALQUE_FENETRES := 1 << 19
## Au-delà, les mondes partagent le dernier calque.
const MONDES_MAX := 18


## Les portails qui mènent à un autre monde, dans l'ordre du tracé.
func mondes() -> Array[TrackPortail]:
	var liste: Array[TrackPortail] = []
	for portail in portails():
		if portail.nouveau_monde:
			liste.append(portail)
	return liste


## Le calque de ce monde ; 0 sans monde.
func calque_du_monde(monde: TrackPortail) -> int:
	var i := mondes().find(monde)
	if i < 0:
		return 0
	return 1 << (1 + mini(i, MONDES_MAX - 1))


## Ce que voit une caméra plantée dans ce monde.
func masque_pour(monde: TrackPortail) -> int:
	return CALQUE_COMMUN | calque_du_monde(monde) | CALQUE_FENETRES


## Range les décors de chaque monde sur son calque. À refaire quand un décor
## se reconstruit : ses maillages tout neufs naissent sur le calque commun.
func ranger_les_mondes() -> void:
	_mondes_ranges = true
	for monde in mondes():
		var calque := calque_du_monde(monde)
		for noeud in monde.decors_du_monde():
			poser_calque(noeud, calque)


static func poser_calque(noeud: Node, calque: int) -> void:
	if noeud is VisualInstance3D:
		(noeud as VisualInstance3D).layers = calque
	for enfant in noeud.get_children():
		poser_calque(enfant, calque)


## Ne montre à cette caméra que le décor du monde `ici` : de la grand-place
## des années cinquante, on ne voit pas les tours du futur qui pourtant se
## dressent de l'autre côté du circuit.
func montrer_le_monde_de(ici: TrackPortail, camera: Camera3D) -> void:
	if not _mondes_ranges:
		ranger_les_mondes()
	camera.cull_mask = masque_pour(ici)


var _mondes_ranges := false


## La caméra qui suit un kart, s'il y en a une, voit le monde de l'autre
## côté du portail, et le couloir déformer sa perspective (ChaseCamera.vortex).
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or track_curve == null:
		return
	var liste := portails()
	if liste.is_empty():
		return
	var camera := get_viewport().get_camera_3d() as ChaseCamera
	if camera == null or camera.cible() == null:
		return
	var d := track_curve.distance_of(camera.cible().global_position)
	var effet := 0.0
	for portail in liste:
		effet = maxf(effet, portail.effet_a(d, track_curve.length))
	camera.vortex = effet
	# Le monde est celui de la caméra, pas du kart : tant qu'elle n'a pas
	# franchi le portail, elle voit l'autre monde à travers, et le sien autour.
	var ici := track_curve.distance_of(camera.global_position)
	camera.environment = portail_en(ici).ambiance
	montrer_le_monde_de(monde_en(ici), camera)


var _asphalte: StandardMaterial3D
## Le grain du bitume coûte trois lectures de texture par pixel de route,
## deux fois : QualiteGraphique ne le laisse qu'en qualité haute.
var _detail_asphalte := true


## Met ou retire le grain du bitume (voir habiller_l_asphalte).
func detailler_l_asphalte(actif: bool) -> void:
	_detail_asphalte = actif
	if _asphalte == null:
		return
	if actif:
		Track.habiller_l_asphalte(_asphalte)
	else:
		_asphalte.albedo_texture = null
		_asphalte.normal_enabled = false
		_asphalte.uv1_triplanar = false
		_asphalte.roughness = 0.85


static var _grain: NoiseTexture2D
static var _relief: NoiseTexture2D


## Donne du grain à un bitume uni : une texture de bruit qui le tachète, un
## relief fin qui accroche la lumière rasante, un peu de reflet. Projetée en
## coordonnées du monde (la route n'a pas d'UV), et partagée par tous les
## circuits : deux petites textures, faites une fois.
static func habiller_l_asphalte(materiau: StandardMaterial3D) -> void:
	if _grain == null:
		var bruit := FastNoiseLite.new()
		bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX
		bruit.frequency = 0.09
		bruit.fractal_octaves = 3
		var rampe := Gradient.new()
		rampe.set_color(0, Color(0.8, 0.8, 0.8))
		rampe.set_color(1, Color(1.05, 1.05, 1.05))
		_grain = NoiseTexture2D.new()
		_grain.width = 256
		_grain.height = 256
		_grain.seamless = true
		_grain.noise = bruit
		_grain.color_ramp = rampe
		_relief = NoiseTexture2D.new()
		_relief.width = 256
		_relief.height = 256
		_relief.seamless = true
		_relief.as_normal_map = true
		_relief.bump_strength = 3.0
		_relief.noise = bruit
	materiau.albedo_texture = _grain
	materiau.normal_enabled = true
	materiau.normal_texture = _relief
	materiau.normal_scale = 0.6
	materiau.uv1_triplanar = true
	materiau.uv1_world_triplanar = true
	materiau.uv1_scale = Vector3.ONE * 0.18
	materiau.roughness = 0.78
	materiau.metallic_specular = 0.35


## Les murs, tremplins et zones hors-piste posés sur ce circuit. Gardés en
## mémoire : la session les parcourt plusieurs fois par kart et par image.
func elements() -> Array[TrackFeature]:
	if _elements_a_jour and is_node_ready():
		return _elements
	var trouves: Array[TrackFeature] = []
	for enfant in get_children():
		if enfant is TrackFeature:
			trouves.append(enfant)
	_elements = trouves
	_elements_a_jour = is_node_ready()
	return trouves


## La plaque de verglas sous ce point, ou null.
func verglas_en(distance: float, lateral: float) -> TrackVerglas:
	for element in elements():
		if element is TrackVerglas and element.contient(distance, lateral, track_curve.length):
			return element
	return null


## Ce que le vent, le courant ou les tapis roulants poussent en ce point, en
## m/s dans le repère du monde. Plusieurs zones s'additionnent.
func poussee_en(distance: float, lateral: float) -> Vector3:
	var total := Vector3.ZERO
	for element in elements():
		if element is TrackCourant and element.contient(distance, lateral, track_curve.length):
			total += (element as TrackCourant).poussee(track_curve, distance, horloge)
	return total


## Le facteur de gravité en ce point : moins de 1 dans une zone d'apesanteur.
func gravite_en(distance: float, lateral: float) -> float:
	for element in elements():
		if element is TrackApesanteur and element.contient(distance, lateral, track_curve.length):
			return (element as TrackApesanteur).gravite
	return 1.0


## L'anneau que traverse un kart en ce point, `hauteur` mètres au-dessus de
## la route, ou null.
func anneau_en(distance: float, lateral: float, hauteur: float) -> TrackAnneau:
	for element in elements():
		if element is TrackAnneau and (element as TrackAnneau).traverse(distance, lateral, hauteur, track_curve.length):
			return element
	return null


## Refait la route et tout ce qui est posé dessus. Les trous l'appellent quand
## on les règle : c'est la route elle-même qui change.
func reconstruire() -> void:
	_mondes_ranges = false
	if is_node_ready():
		_reconstruire()


## Les portions sans route, pour TrackBuilder.
func trous() -> Array[Vector2]:
	var portions: Array[Vector2] = []
	for element in elements():
		if element is TrackGap and not element.is_queued_for_deletion():
			portions.append_array(element.portions(track_curve.length))
	return portions


## Les portions où une IA cesse de flâner, de doubler et de se tromper pour
## reprendre sa ligne : l'élan d'une rampe et d'un trou jusqu'à la retombée,
## le verglas et le vent, qui ne pardonnent pas un écart.
## Chaque portion est (début, fin), en distance le long du tracé.
func zones_prudentes() -> PackedVector2Array:
	if not (_zones_a_jour and is_node_ready()):
		_zones_a_jour = is_node_ready()
		_zones_prudentes.clear()
		for element in elements():
			if (element is TrackGap or element is TrackRamp or element is TrackVerglas or element is TrackCourant) \
					and not element.is_queued_for_deletion():
				var debut: float = element.debut
				var fin: float = debut + element.longueur
				_zones_prudentes.append(Vector2(debut - ELAN_PRUDENT, fin + RETOMBEE_PRUDENTE))
	return _zones_prudentes


## Les plaques d'accélération, pour l'IA : (début, longueur, décalage,
## largeur).
func plaques_d_acceleration() -> PackedVector4Array:
	if not (_plaques_a_jour and is_node_ready()):
		_plaques_a_jour = is_node_ready()
		_plaques.clear()
		for element in elements():
			if element is TrackBoost and not element.is_queued_for_deletion():
				var plaque := element as TrackBoost
				_plaques.append(Vector4(plaque.debut, plaque.longueur, plaque.decalage, plaque.largeur))
	return _plaques


## Le trou qui couvre cette distance, ou null.
func trou_en(distance: float) -> TrackGap:
	for element in elements():
		if element is TrackGap and element.couvre(distance, track_curve.length):
			return element
	return null


## Où remettre en piste un kart dont la dernière position sûre est `distance`.
## Si c'est juste avant un trou — ou dedans —, de l'autre côté : reposé avant,
## à l'arrêt, il n'aurait aucun élan pour sauter et retomberait sans fin.
func point_de_reprise(distance: float) -> float:
	for element in elements():
		if not element is TrackGap:
			continue
		var trou := element as TrackGap
		var avant := wrapf(trou.debut - distance, -track_curve.length * 0.5, track_curve.length * 0.5)
		if avant >= -trou.longueur and avant <= ELAN_AVANT_UN_TROU:
			return wrapf(trou.fin() + 4.0, 0.0, track_curve.length)
	return distance


## Le tremplin sous ce point du circuit, ou null.
## La plaque d'accélération sous ce point, ou null.
func accelerateur_en(distance: float, lateral: float) -> TrackBoost:
	for element in elements():
		if element is TrackBoost and element.contient(distance, lateral, track_curve.length):
			return element
	return null


func tremplin_en(distance: float, lateral: float) -> TrackJump:
	for element in elements():
		if element is TrackJump and element.contient(distance, lateral, track_curve.length):
			return element
	return null


## La rampe sous ce point, ou null. Comptée deux mètres au-delà de son
## sommet : c'est au moment de le franchir que le kart doit encore la savoir
## sous ses roues.
func rampe_en(distance: float, lateral: float) -> TrackRamp:
	for element in elements():
		if element is TrackRamp:
			var rampe := element as TrackRamp
			var dans := wrapf(distance - rampe.debut, 0.0, track_curve.length)
			if dans <= rampe.longueur + 2.0 and absf(lateral - rampe.decalage) <= rampe.largeur * 0.5:
				return rampe
	return null


## Ce point est-il dans une zone hors-piste posée sur le tracé ?
func en_zone_hors_piste(distance: float, lateral: float) -> bool:
	for element in elements():
		if element is TrackOffroad and element.contient(distance, lateral, track_curve.length):
			return true
	return false


## Y a-t-il du sol sous ce point : la route, ou une zone hors-piste ?
func sol_praticable(distance: float, lateral: float) -> bool:
	if en_zone_hors_piste(distance, lateral):
		return true
	return absf(lateral) <= track_curve.half_width and trou_en(distance) == null


## L'écart à l'axe de chaque mur présent à cette distance.
func murs_en(distance: float) -> PackedFloat32Array:
	var lignes := PackedFloat32Array()
	for element in elements():
		if element is TrackWall and element.couvre(distance, track_curve.length):
			lignes.append_array(element.lignes(track_curve.half_width))
	return lignes


## Les setters tirent avant `_ready` pendant le chargement de la scène, quand
## rien n'est encore en place : on ne reconstruit qu'une fois le nœud monté.
func _reconstruire_si_montee() -> void:
	if is_node_ready():
		_reconstruire()


func _vider() -> void:
	for nom in [NOM_MAILLAGE, NOM_CORPS, NOM_BORDURES, NOM_TABLIER, NOM_MARQUAGE]:
		var ancien := get_node_or_null(NodePath(nom))
		if ancien != null:
			# Retiré tout de suite plutôt que seulement mis en file : sinon le
			# nom reste pris et Godot rebaptise le nouveau « RoadMesh2 ».
			remove_child(ancien)
			ancien.queue_free()


## Suit les déplacements de points de contrôle, pour que la route se redessine
## sous la souris. Seulement dans l'éditeur : en jeu la courbe ne bouge pas, et
## un signal branché pour rien reste un signal branché pour rien.
func _suivre_courbe(brancher: bool) -> void:
	if not Engine.is_editor_hint() or curve == null:
		return
	if brancher:
		if not curve.changed.is_connected(_reconstruire_si_montee):
			curve.changed.connect(_reconstruire_si_montee)
	elif curve.changed.is_connected(_reconstruire_si_montee):
		curve.changed.disconnect(_reconstruire_si_montee)


## Prévient dans l'éditeur quand le tracé contient un virage qu'aucun kart ne
## peut prendre. Un point de contrôle posé sans poignée fait un angle vif,
## invisible tant que la courbe reste une jolie ligne à l'écran : mesuré sur le
## circuit 1, trois points sans poignée donnaient un pli de 2,7 m de rayon où
## le kart se bloquait net, vitesse réelle nulle, moteur à fond.
##
## L'avertissement s'affiche dans l'arbre de scènes, à côté du nœud, et se met
## à jour dès qu'on lâche la poignée.
func _get_configuration_warnings() -> PackedStringArray:
	var avertissements := PackedStringArray()
	if curve == null:
		avertissements.append("Aucune courbe : ce circuit n'a pas de tracé.")
		return avertissements
	if track_curve == null:
		return avertissements

	var serres := track_curve.tight_spots(min_drivable_radius, segment_length)
	if serres.is_empty():
		return avertissements

	var pire: Array = serres[0]
	var texte := "%d endroit(s) tournent plus court que %.1f m, " 		% [serres.size(), min_drivable_radius]
	texte += "le kart n'y passera pas.
Le pire : %.1f m de rayon à %.0f m du départ." 		% [pire[1], pire[0]]
	texte += "
Un point de contrôle sans poignée fait un angle vif : tire ses "
	texte += "poignées dans l'éditeur, ou lance
  "
	texte += "godot --headless --script tools/shape_track_curve.gd"
	avertissements.append(texte)
	return avertissements


## Transformée de départ, sur la ligne de course, orientée dans le sens de la
## marche. Sert au placement initial comme aux remises en piste.
##
## Le décalage latéral est en mètres vers la droite de la marche, et sert à la
## grille de départ. Il vaut zéro par défaut pour que les remises en piste
## continuent de ramener le kart sur la ligne de course, où il doit être.
func spawn_at(distance: float, lateral: float = 0.0) -> Transform3D:
	# Décalé et surélevé dans le repère de la CHAUSSÉE : sur une route en dévers,
	# lever le kart à la verticale du monde le décolle du bitume d'un côté et
	# l'y enfonce de l'autre. Dix centimètres de garde : assez pour ne pas naître
	# encastré dans la route, trop peu pour que la chute se voie.
	var position := track_curve.racing_line_at(distance) \
		+ track_curve.right_at(distance) * lateral \
		+ track_curve.up_at(distance) * 0.1
	# Le repère complet plutôt qu'un simple lacet : le kart naît couché sur la
	# pente, nez en bas dans une descente, plutôt qu'à plat en train de basculer.
	return Transform3D(track_curve.basis_at(distance), position)
