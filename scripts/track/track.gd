class_name Track
extends Node3D

## Assemble un circuit : la courbe qui le définit, le maillage extrudé et la
## collision. Tout est construit au chargement, donc modifier la courbe suffit
## à redéfinir la piste, sa collision et la trajectoire de l'IA d'un seul geste.

@export var curve: Curve3D
@export var half_width: float = 9.0
@export var segment_length: float = 2.0
@export var road_color: Color = Color(0.36, 0.38, 0.42)

var track_curve: TrackCurve


func _ready() -> void:
	assert(curve != null, "un Track doit avoir une courbe")
	track_curve = TrackCurve.new(curve, half_width)

	var maillage := TrackBuilder.build(track_curve, segment_length)

	var materiau := StandardMaterial3D.new()
	materiau.albedo_color = road_color
	maillage.surface_set_material(0, materiau)

	var affichage := MeshInstance3D.new()
	affichage.name = "RoadMesh"
	affichage.mesh = maillage
	add_child(affichage)

	var corps := StaticBody3D.new()
	corps.name = "RoadBody"
	var forme := CollisionShape3D.new()
	forme.shape = maillage.create_trimesh_shape()
	corps.add_child(forme)
	add_child(corps)


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
