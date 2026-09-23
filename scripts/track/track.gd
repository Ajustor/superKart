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

var track_curve: TrackCurve

## En deçà de cette distance avant un trou, un kart remis en piste l'est de
## l'autre côté : il faut plus d'élan que ça pour sauter.
const ELAN_AVANT_UN_TROU := 60.0


func _ready() -> void:
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


## Les murs, tremplins et zones hors-piste posés sur ce circuit.
func elements() -> Array[TrackFeature]:
	var trouves: Array[TrackFeature] = []
	for enfant in get_children():
		if enfant is TrackFeature:
			trouves.append(enfant)
	return trouves


## Refait la route et tout ce qui est posé dessus. Les trous l'appellent quand
## on les règle : c'est la route elle-même qui change.
func reconstruire() -> void:
	if is_node_ready():
		_reconstruire()


## Les portions sans route, pour TrackBuilder.
func trous() -> Array[Vector2]:
	var portions: Array[Vector2] = []
	for element in elements():
		if element is TrackGap and not element.is_queued_for_deletion():
			portions.append_array(element.portions(track_curve.length))
	return portions


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
	for nom in [NOM_MAILLAGE, NOM_CORPS, NOM_BORDURES]:
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
