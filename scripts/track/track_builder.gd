class_name TrackBuilder

## Extrude un ruban de route le long d'un TrackCurve. Le maillage produit sert
## à la fois à l'affichage et, converti en trimesh, à la collision.


## Découpe la courbe en segments d'environ `segment_length` mètres et relie
## chaque section à la suivante par deux triangles.
##
## `trous` liste les portions sans route, en couples (début, fin) de distances
## le long du tracé, déjà ramenées dans [0, longueur]. La route s'y arrête net
## et reprend au bout : c'est ce qui fait un vrai saut, par-dessus le vide.
static func build(track: TrackCurve, segment_length: float = 2.0,
		trous: Array[Vector2] = []) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)

	var morceaux := troncons(track.length, trous)
	# Sans trou, le découpage reste exactement celui d'avant : même nombre de
	# sections, au même endroit.
	var sections_totales := maxi(int(track.length / segment_length), 8)
	for morceau in morceaux:
		var etendue := morceau.y - morceau.x
		var sections := maxi(int(round(sections_totales * etendue / track.length)), 1)
		var pas := etendue / float(sections)
		for i in sections:
			_section(outil, track, morceau.x + pas * float(i), morceau.x + pas * float(i + 1))

	outil.generate_normals()
	return outil.commit()


## Les portions de tracé qui portent de la route : le tour entier, moins les
## trous. Rendues en couples (début, fin), dans l'ordre.
static func troncons(longueur: float, trous: Array[Vector2]) -> Array[Vector2]:
	var tries := trous.duplicate()
	tries.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var morceaux: Array[Vector2] = []
	var curseur := 0.0
	for trou in tries:
		var debut := clampf(trou.x, 0.0, longueur)
		var fin := clampf(trou.y, 0.0, longueur)
		if debut > curseur + 0.01:
			morceaux.append(Vector2(curseur, debut))
		curseur = maxf(curseur, fin)
	if curseur < longueur - 0.01:
		morceaux.append(Vector2(curseur, longueur))
	return morceaux


static func _section(outil: SurfaceTool, track: TrackCurve, d0: float, d1: float) -> void:
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
