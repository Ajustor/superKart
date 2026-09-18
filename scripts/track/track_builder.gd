class_name TrackBuilder

## Extrude un ruban de route le long d'un TrackCurve. Le maillage produit sert
## à la fois à l'affichage et, converti en trimesh, à la collision.


## Découpe la courbe en segments d'environ `segment_length` mètres et relie
## chaque section à la suivante par deux triangles.
static func build(track: TrackCurve, segment_length: float = 2.0) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sections := maxi(int(track.length / segment_length), 8)
	var pas := track.length / float(sections)

	for i in sections:
		var d0 := pas * float(i)
		var d1 := pas * float(i + 1)
		var gauche0 := track.position_at(d0) - track.right_at(d0) * track.half_width
		var droite0 := track.position_at(d0) + track.right_at(d0) * track.half_width
		var gauche1 := track.position_at(d1) - track.right_at(d1) * track.half_width
		var droite1 := track.position_at(d1) + track.right_at(d1) * track.half_width

		outil.add_vertex(gauche0)
		outil.add_vertex(gauche1)
		outil.add_vertex(droite0)

		outil.add_vertex(droite0)
		outil.add_vertex(gauche1)
		outil.add_vertex(droite1)

	outil.generate_normals()
	return outil.commit()
