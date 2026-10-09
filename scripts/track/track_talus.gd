class_name TrackTalus
extends RefCounted

## Le talus : une pente douce qui descend d'un bord (la route, une bande
## hors-piste) jusque sous le sol d'à côté. Sans lui, le bord était une
## marche de 13 à 45 cm, un mur qu'on ne voyait pas : on ne remontait pas du
## sol sur la route, ou l'on passait dessous.
##
## Une seule source de géométrie, des triangles, dont la route et les bandes
## font un maillage (on le voit : le kart qui le remonte ne flotte pas
## au-dessus de rien) et une collision.

## Ce qu'il descend, et sur quelle largeur (15°) : il passe sous un sol
## bordé jusqu'à TrackSol.MARCHE plus bas. Au-delà, le sol ne borde plus.
const CHUTE := 1.2
const LARGEUR := 4.5
const NOM := "Talus"


## Les triangles d'un talus le long d'un bord : de `lateral` (le bord, à la
## hauteur du sol du circuit), sur LARGEUR mètres vers `cote` (+1 à droite,
## -1 à gauche), en descendant de CHUTE. Entre chaque paire de sections
## consécutives où `porte(milieu)` est vrai.
static func le_long(c: TrackCurve, sections: PackedFloat32Array, lateral: float, cote: float,
		porte: Callable) -> PackedVector3Array:
	var triangles := PackedVector3Array()
	for i in sections.size() - 1:
		var d0 := sections[i]
		var d1 := sections[i + 1]
		if not porte.call((d0 + d1) * 0.5):
			continue
		var h0 := TrackFeature.point(c, d0, lateral, 0.0)
		var h1 := TrackFeature.point(c, d1, lateral, 0.0)
		var b0 := TrackFeature.point(c, d0, lateral + cote * LARGEUR, -CHUTE)
		var b1 := TrackFeature.point(c, d1, lateral + cote * LARGEUR, -CHUTE)
		# Tournés vers le ciel, quel que soit le côté.
		if cote > 0.0:
			triangles.append_array([h0, h1, b0, b0, h1, b1])
		else:
			triangles.append_array([b0, b1, h0, h0, b1, h1])
	return triangles


## Le talus en travers d'un bout de bande, à `d` : de `de_lateral` à
## `a_lateral`, en descendant sur LARGEUR mètres le long du tracé, vers
## `sens` (-1 avant le bout, vers le départ ; +1 après). Par tranches d'un
## mètre en travers, là où `porte(lateral)` est vrai.
static func en_travers(c: TrackCurve, d: float, de_lateral: float, a_lateral: float, sens: float,
		porte: Callable) -> PackedVector3Array:
	var triangles := PackedVector3Array()
	var n := maxi(ceili(absf(a_lateral - de_lateral)), 1)
	var loin := d + sens * LARGEUR
	for i in n:
		var l0 := lerpf(de_lateral, a_lateral, float(i) / float(n))
		var l1 := lerpf(de_lateral, a_lateral, float(i + 1) / float(n))
		if not porte.call((l0 + l1) * 0.5):
			continue
		var h0 := TrackFeature.point(c, d, l0, 0.0)
		var h1 := TrackFeature.point(c, d, l1, 0.0)
		var b0 := TrackFeature.point(c, loin, l0, 0.0) + Vector3.DOWN * CHUTE
		var b1 := TrackFeature.point(c, loin, l1, 0.0) + Vector3.DOWN * CHUTE
		triangles.append_array([h0, b0, h1, h1, b0, b1])
	return triangles


## Le talus posé : visible avec `materiau`, et solide (les deux faces), sur la
## couche du décor. Sans triangle, rien.
static func poser(racine: Node3D, triangles: PackedVector3Array, materiau: Material,
		calque: int = 1) -> Node3D:
	if triangles.is_empty():
		return null
	var talus := Node3D.new()
	talus.name = NOM
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in triangles:
		outil.add_vertex(p)
	outil.generate_normals()
	var affichage := MeshInstance3D.new()
	affichage.mesh = outil.commit()
	affichage.material_override = materiau
	affichage.layers = calque
	talus.add_child(affichage)
	var forme := ConcavePolygonShape3D.new()
	forme.backface_collision = true
	forme.set_faces(triangles)
	var corps := StaticBody3D.new()
	corps.collision_layer = Kart.COUCHE_DECOR
	var collision := CollisionShape3D.new()
	collision.shape = forme
	corps.add_child(collision)
	talus.add_child(corps)
	racine.add_child(talus)
	return talus
