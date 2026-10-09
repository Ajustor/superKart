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
const NOM_RIVES := "Rives"
const NOM_TALUS := "Talus"
## Les bordures rouges et blanches : un mètre de large sur chaque rive.
const LARGEUR_BORDURE := 1.0
## Le jaune des lignes de rive, celui des routes de Kenney.
const COULEUR_RIVE := Color("ffcf60")

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

## Par défaut, le rouge des bordures du Racing Kit de Kenney.
@export var couleur_bordure: Color = Color("d4564e"):
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

	var corps := StaticBody3D.new()
	corps.name = NOM_CORPS
	var forme := CollisionShape3D.new()
	# La collision n'a que faire des couleurs : les sept bandes de
	# l'arc-en-ciel y feraient sept fois plus de triangles à tester, à chaque
	# roue et chaque image. Elle est d'un seul tenant, tous mondes confondus.
	forme.shape = TrackBuilder.build(track_curve, segment_length, trous()).create_trimesh_shape()
	corps.add_child(forme)
	add_child(corps)

	# Ce qui se voit de la route, monde par monde : chacun sur son calque.
	# Sans portail, une seule portion, la route entière, sur le calque commun.
	for portion in portions_visibles():
		_dessiner_la_route(portion.trous, portion.calque, portion.suffixe, arc_en_ciel)

	# Les éléments posés sur le tracé le suivent : retoucher la courbe
	# déplace les murs, les tremplins et les zones avec elle.
	for element in elements():
		element.reconstruire()
	# Après les éléments : les sols doivent exister pour dire où ils bordent.
	_poser_les_talus(arc_en_ciel)

	if Engine.is_editor_hint():
		update_configuration_warnings()


## Les talus le long des deux bords de la route, partout où un sol réel la
## borde (TrackTalus) : sans eux, le bord était une marche qu'on ne
## remontait pas, ou sous laquelle on passait. Jamais au-dessus du vide :
## ce serait un sol invisible. Coupés comme la collision de la route, pour
## que leur arête suive exactement celle du bitume.
func _poser_les_talus(arc_en_ciel: bool) -> void:
	var c := track_curve
	var demi := c.half_width
	var par_calque := {}
	var sections_totales := maxi(int(c.length / segment_length), 8)
	for morceau in TrackBuilder.troncons(c.length, trous()):
		var etendue := morceau.y - morceau.x
		var n := maxi(int(round(sections_totales * etendue / c.length)), 1)
		var sections := PackedFloat32Array()
		for i in n + 1:
			sections.append(morceau.x + etendue * float(i) / float(n))
		for cote: float in [-1.0, 1.0]:
			var triangles := TrackTalus.le_long(c, sections, demi * cote, cote,
				_borde_par_un_sol.bind(cote))
			# Rangés par monde : chacun ne se voit que du sien.
			for t in range(0, triangles.size(), 6):
				var milieu := c.distance_of((triangles[t] + triangles[t + 1]) * 0.5)
				var calque := calque_a(milieu)
				if calque == 0:
					calque = CALQUE_COMMUN
				if not par_calque.has(calque):
					par_calque[calque] = PackedVector3Array()
				par_calque[calque].append_array(triangles.slice(t, t + 6))
	if par_calque.is_empty():
		return
	var racine := Node3D.new()
	racine.name = NOM_TALUS
	add_child(racine)
	var beton := StandardMaterial3D.new()
	beton.albedo_color = road_color.lerp(Color(0.5, 0.48, 0.46), 0.5) if not arc_en_ciel else Color(0.3, 0.3, 0.42)
	beton.roughness = 0.9
	beton.cull_mode = BaseMaterial3D.CULL_DISABLED
	for calque in par_calque:
		TrackTalus.poser(racine, par_calque[calque], beton, calque)


## Un sol réel borde-t-il la route à cette distance, de ce côté, et assez
## haut pour que le talus plonge dessous ? Ni dans un trou, ni hors course.
func _borde_par_un_sol(distance: float, cote: float) -> bool:
	if hors_course(distance) or trou_en(distance) != null:
		return false
	var c := track_curve
	var bord := TrackFeature.point(c, distance, cote * c.half_width, 0.0)
	var sol := hauteur_du_sol_reel(TrackFeature.point(c, distance, cote * (c.half_width + 2.0), 0.0), distance)
	return sol >= bord.y - TrackTalus.CHUTE


## La route visible d'une portion : la chaussée, son dessous, le marquage,
## les rives et les bordures, sans ce qui est dans `sans` (les trous, et les
## autres mondes), sur le calque `calque`.
func _dessiner_la_route(sans: Array[Vector2], calque: int, suffixe: String, arc_en_ciel: bool) -> void:
	var maillage := TrackBuilder.build(track_curve, segment_length, sans,
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
		Track.peindre_l_asphalte(materiau)
	maillage.surface_set_material(0, materiau)
	_poser_la_partie(NOM_MAILLAGE + suffixe, maillage, null, calque)

	# Le dessous de la route, pour qu'un pont se voie d'en bas.
	var beton := StandardMaterial3D.new()
	beton.vertex_color_use_as_albedo = true
	beton.albedo_color = road_color.lerp(Color(0.5, 0.48, 0.46), 0.5) if not arc_en_ciel else Color(0.3, 0.3, 0.42)
	beton.roughness = 0.9
	# Les deux faces : vue de côté ou d'en dessous, la dalle doit rester
	# pleine, et Godot retourne la normale des faces arrière.
	beton.cull_mode = BaseMaterial3D.CULL_DISABLED
	_poser_la_partie(NOM_TABLIER + suffixe, TrackBuilder.tablier(track_curve, sans, 0.9, segment_length), beton, calque)

	if marquage and not arc_en_ciel:
		var peinture_blanche := StandardMaterial3D.new()
		peinture_blanche.albedo_color = Color(0.92, 0.92, 0.88)
		peinture_blanche.roughness = 0.6
		_poser_la_partie(NOM_MARQUAGE + suffixe, TrackBuilder.marquage(track_curve, sans),
			peinture_blanche, calque, false)
		# Les lignes de rive jaunes des routes de Kenney, en dedans des
		# bordures quand il y en a.
		var jaune := StandardMaterial3D.new()
		jaune.albedo_color = COULEUR_RIVE
		jaune.roughness = 0.6
		_poser_la_partie(NOM_RIVES + suffixe, TrackBuilder.lignes_de_rive(track_curve, sans,
			LARGEUR_BORDURE + 0.25 if bordures else 0.35), jaune, calque, false)

	if bordures:
		var peinture := StandardMaterial3D.new()
		peinture.vertex_color_use_as_albedo = true
		_poser_la_partie(NOM_BORDURES + suffixe, TrackBuilder.bordures(track_curve, sans, LARGEUR_BORDURE, 1.5,
			couleur_bordure, couleur_bordure_bis), peinture, calque)


func _poser_la_partie(nom: String, maillage: Mesh, materiau: Material, calque: int, ombre := true) -> void:
	var partie := MeshInstance3D.new()
	partie.name = nom
	partie.mesh = maillage
	if materiau != null:
		partie.material_override = materiau
	partie.layers = calque
	if not ombre:
		partie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(partie)


## Les portions de route à dessiner chacune à part : une par monde (voir
## TrackPortail.nouveau_monde), sur le calque de ce monde. La route d'au-delà
## d'un portail n'est dessinée que pour qui est déjà de l'autre côté — ou la
## caméra du portail : vue d'ici, elle s'arrête au portail, et l'on ne voit la
## suite qu'à travers lui. Chaque portion : {trous, calque, suffixe}.
func portions_visibles() -> Array[Dictionary]:
	var liste_mondes := mondes()
	if Engine.is_editor_hint() or liste_mondes.is_empty():
		return [{trous = trous(), calque = CALQUE_COMMUN, suffixe = ""}]
	# Où commence et finit chaque monde, au mètre près : le tracé, parcouru
	# d'un bout à l'autre (une course linéaire range sa grille dans le monde
	# du départ, voir _dernier_franchi).
	var etendues := {}
	var longueur := track_curve.length
	var pas := 1.0
	var d := 0.0
	var courant: TrackPortail = null
	var debut_courant := 0.0
	while d < longueur:
		var ici := monde_en(minf(d + pas * 0.5, longueur - 0.01))
		if ici != courant:
			if courant != null:
				etendues[courant].append(Vector2(debut_courant, d))
			courant = ici
			debut_courant = d
			if not etendues.has(courant):
				etendues[courant] = []
		d += pas
	etendues[courant].append(Vector2(debut_courant, longueur))
	var portions: Array[Dictionary] = []
	var n := 0
	for monde in liste_mondes:
		if not etendues.has(monde):
			continue
		var sans := trous()
		# Tout ce qui n'est pas à ce monde est un « trou » pour lui.
		var curseur := 0.0
		for e: Vector2 in etendues[monde]:
			if e.x > curseur:
				sans.append(Vector2(curseur, e.x))
			curseur = e.y
		if curseur < longueur:
			sans.append(Vector2(curseur, longueur))
		var calque := calque_du_monde(monde)
		portions.append({trous = sans, calque = calque if calque != 0 else CALQUE_COMMUN,
			suffixe = "" if n == 0 else "_%d" % n})
		n += 1
	return portions


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


## Le ciel et la lumière à cette distance : ceux du dernier portail franchi
## (_dernier_franchi).
## Null : ceux du circuit.
func ambiance_en(distance: float) -> Environment:
	var portail := portail_en(distance)
	return portail.ambiance if portail != null else null


## Le dernier portail franchi à cette distance, en faisant le tour : l'époque,
## le monde où l'on est. Null s'il n'y a pas de portail.
func portail_en(distance: float) -> TrackPortail:
	return _dernier_franchi(portails(), distance)


## Le dernier de ces portails franchi à cette distance. Sur une boucle, avant
## le premier, c'est le dernier : on vient d'en faire le tour. Sur une course
## linéaire, on ne fait pas le tour : avant le premier — et sur la grille,
## posée au bout du tracé juste avant la ligne —, on est dans le monde du
## départ, pas dans celui de l'arrivée.
func _dernier_franchi(liste: Array[TrackPortail], distance: float) -> TrackPortail:
	if liste.is_empty():
		return null
	var choisi := liste[liste.size() - 1]
	if lineaire():
		choisi = liste[0]
		if distance >= track_curve.length - LONGUEUR_DE_GRILLE:
			return choisi
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
	return _dernier_franchi(mondes, distance)


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
	var reclames := {}
	for monde in mondes():
		var calque := calque_du_monde(monde)
		for noeud in monde.decors_du_monde():
			poser_calque(noeud, calque)
			reclames[noeud] = true
	if mondes().is_empty():
		return
	# Ce qui est posé sur la route (murs, tremplins, plaques…) appartient au
	# monde où il est : comme la route (portions_visibles), on ne le voit
	# d'un autre monde qu'à travers le portail.
	for element in elements():
		if element is TrackPortail or reclames.has(element):
			continue
		var calque := calque_a(element.debut + minf(element.longueur * 0.5, 1.0))
		if calque != 0:
			poser_calque(element, calque)


## Le calque du monde à cette distance, 0 s'il n'y a pas de mondes : pour
## ranger ce qui y est posé (boîtes à objets, karts).
func calque_a(distance: float) -> int:
	if mondes().is_empty() or track_curve == null:
		return 0
	return calque_du_monde(monde_en(wrapf(distance, 0.0, track_curve.length)))


## Rend ou retire leur ombre portée à toutes les pièces de `noeud`, en
## gardant celles qui n'en faisaient pas (une ombre de contact, des
## particules).
static func poser_ombres(noeud: Node, actives: bool) -> void:
	if noeud is GeometryInstance3D:
		var piece := noeud as GeometryInstance3D
		if not piece.has_meta("ombre_prevue"):
			piece.set_meta("ombre_prevue", piece.cast_shadow)
		piece.cast_shadow = piece.get_meta("ombre_prevue") if actives \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for enfant in noeud.get_children():
		poser_ombres(enfant, actives)


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


## Le bitume, à la manière des routes de Kenney : uni, mat, sans grain. Les
## couleurs franches et les lignes de rive font le reste.
static func peindre_l_asphalte(materiau: StandardMaterial3D) -> void:
	materiau.roughness = 0.9
	materiau.metallic_specular = 0.2


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


## Au-delà du bitume, le sol (TrackSol, TrackTerrain) porte le kart sur
## cette largeur de chaque côté : des bas-côtés où l'on roule, lentement,
## comme dans l'herbe. Plus loin, on est sorti du circuit et remis en piste.
const PORTEE_HORS_PISTE := 14.0


## Un sol réel sous ce point, à cette distance le long du tracé : un sol ou
## un relief qui porte le kart.
func sol_reel(point: Vector3, distance: float) -> bool:
	for element in elements():
		if element is TrackSol and (element as TrackSol).porte(point, distance):
			return true
		if element is TrackTerrain and (element as TrackTerrain).porte(point, distance):
			return true
	return false


## La hauteur du sol réel le plus haut qui porte ce point (TrackSol,
## TrackTerrain), -INF s'il n'y en a pas.
func hauteur_du_sol_reel(point: Vector3, distance: float) -> float:
	var h := -INF
	for element in elements():
		if element is TrackSol and (element as TrackSol).porte(point, distance):
			h = maxf(h, (element as TrackSol).hauteur_en(point.x, point.z))
		elif element is TrackTerrain and (element as TrackTerrain).porte(point, distance):
			h = maxf(h, (element as TrackTerrain).hauteur_en(point.x, point.z))
	return h


## Le monde dont ce nœud est un décor (TrackPortail.decors), ou null s'il est
## de tous les mondes.
func monde_du_decor(noeud: Node) -> TrackPortail:
	for monde in mondes():
		for decor in monde.decors_du_monde():
			if decor == noeud or decor.is_ancestor_of(noeud):
				return monde
	return null


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
	var noms := [NOM_MAILLAGE, NOM_CORPS, NOM_BORDURES, NOM_TABLIER, NOM_MARQUAGE, NOM_RIVES, NOM_TALUS]
	for enfant in get_children():
		var nom := String(enfant.name)
		var ancien: Node = null
		for prefixe in noms:
			if nom == prefixe or nom.begins_with(prefixe + "_"):
				ancien = enfant
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
