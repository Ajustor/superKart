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
## franchissable. Le kart tourne au mieux à 8,5 m en dérapage et 12,2 m en
## adhérence : plus serré que ça, il ne passe pas, il s'encastre.
@export var min_drivable_radius: float = 9.0

@export var road_color: Color = Color(0.36, 0.38, 0.42):
	set(valeur):
		road_color = valeur
		_reconstruire_si_montee()

var track_curve: TrackCurve


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

	var maillage := TrackBuilder.build(track_curve, segment_length)

	var materiau := StandardMaterial3D.new()
	materiau.albedo_color = road_color
	maillage.surface_set_material(0, materiau)

	var affichage := MeshInstance3D.new()
	affichage.name = NOM_MAILLAGE
	affichage.mesh = maillage
	add_child(affichage)

	var corps := StaticBody3D.new()
	corps.name = NOM_CORPS
	var forme := CollisionShape3D.new()
	forme.shape = maillage.create_trimesh_shape()
	corps.add_child(forme)
	add_child(corps)

	if Engine.is_editor_hint():
		update_configuration_warnings()


## Les setters tirent avant `_ready` pendant le chargement de la scène, quand
## rien n'est encore en place : on ne reconstruit qu'une fois le nœud monté.
func _reconstruire_si_montee() -> void:
	if is_node_ready():
		_reconstruire()


func _vider() -> void:
	for nom in [NOM_MAILLAGE, NOM_CORPS]:
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
	texte += "godot --headless --script tools/smooth_track_curve.gd"
	avertissements.append(texte)
	return avertissements


## Transformée de départ, sur la ligne de course, orientée dans le sens de la
## marche. Sert au placement initial comme aux remises en piste.
##
## Le décalage latéral est en mètres vers la droite de la marche, et sert à la
## grille de départ. Il vaut zéro par défaut pour que les remises en piste
## continuent de ramener le kart sur la ligne de course, où il doit être.
func spawn_at(distance: float, lateral: float = 0.0) -> Transform3D:
	# Dix centimètres de garde : assez pour ne pas naître encastré dans la
	# route, trop peu pour que la chute se voie. Un mètre donnait un quart de
	# seconde de vol plané à chaque départ et à chaque remise en piste.
	var position := track_curve.racing_line_at(distance) \
		+ track_curve.right_at(distance) * lateral \
		+ Vector3.UP * 0.1
	var lacet := track_curve.yaw_at(distance)
	# Le circuit compte ses caps à la boussole, Godot à l'envers.
	return Transform3D(Basis(Vector3.UP, -lacet), position)
