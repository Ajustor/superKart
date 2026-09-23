class_name TrackBuilder

## Extrude un ruban de route le long d'un TrackCurve. Le maillage produit sert
## à la fois à l'affichage et, converti en trimesh, à la collision.


## Découpe la courbe en segments d'environ `segment_length` mètres et relie
## chaque section à la suivante par deux triangles.
##
## `trous` liste les portions sans route, en couples (début, fin) de distances
## le long du tracé, déjà ramenées dans [0, longueur]. La route s'y arrête net
## et reprend au bout : c'est ce qui fait un vrai saut, par-dessus le vide.
##
## `couleurs`, si on en donne, découpe la chaussée en autant de bandes dans le
## sens de la longueur, chacune de sa couleur (portée par les sommets) : c'est
## ce qui fait une route arc-en-ciel. Sans couleurs, un seul ruban uni.
static func build(track: TrackCurve, segment_length: float = 2.0,
		trous: Array[Vector2] = [], couleurs: PackedColorArray = PackedColorArray()) -> ArrayMesh:
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
			_section(outil, track, morceau.x + pas * float(i), morceau.x + pas * float(i + 1), couleurs)

	outil.generate_normals()
	return outil.commit()


## Des bordures rouges et blanches sur chaque rive, comme sur un vrai circuit :
## des bandes de `largeur` mètres posées sur le bord de la chaussée, qui
## changent de couleur tous les `pas` mètres. Juste au-dessus du bitume, sans
## collision : elles se voient, elles ne se sentent pas.
static func bordures(track: TrackCurve, trous: Array[Vector2], largeur: float, pas: float,
		couleur: Color, couleur_bis: Color) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var demi := track.half_width
	for morceau in troncons(track.length, trous):
		var etendue := morceau.y - morceau.x
		var n := maxi(int(round(etendue / pas)), 1)
		var longueur := etendue / float(n)
		for i in n:
			var d0 := morceau.x + longueur * float(i)
			var d1 := d0 + longueur
			outil.set_color(couleur if i % 2 == 0 else couleur_bis)
			for cote: float in [-1.0, 1.0]:
				var dedans := (demi - largeur) * cote
				var dehors := demi * cote
				var a0 := _sur_la_route(track, d0, dedans)
				var b0 := _sur_la_route(track, d0, dehors)
				var a1 := _sur_la_route(track, d1, dedans)
				var b1 := _sur_la_route(track, d1, dehors)
				# Toujours dans le même sens de rotation, quel que soit le côté :
				# vues d'en haut, les deux rives doivent faire face au ciel.
				if cote < 0.0:
					_quad(outil, b0, b1, a0, a1)
				else:
					_quad(outil, a0, a1, b0, b1)
	outil.generate_normals()
	return outil.commit()


static func _sur_la_route(track: TrackCurve, d: float, lateral: float) -> Vector3:
	return track.position_at(d) + track.right_at(d) * lateral + track.up_at(d) * 0.02


## Deux triangles, dans l'ordre de la chaussée : gauche puis droite, de la
## section d0 à la section d1.
static func _quad(outil: SurfaceTool, g0: Vector3, g1: Vector3, d0: Vector3, d1: Vector3) -> void:
	outil.add_vertex(g0)
	outil.add_vertex(g1)
	outil.add_vertex(d0)
	outil.add_vertex(d0)
	outil.add_vertex(g1)
	outil.add_vertex(d1)


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


static func _section(outil: SurfaceTool, track: TrackCurve, d0: float, d1: float,
		couleurs: PackedColorArray = PackedColorArray()) -> void:
	if couleurs.is_empty():
		var gauche0 := track.position_at(d0) - track.right_at(d0) * track.half_width
		var droite0 := track.position_at(d0) + track.right_at(d0) * track.half_width
		var gauche1 := track.position_at(d1) - track.right_at(d1) * track.half_width
		var droite1 := track.position_at(d1) + track.right_at(d1) * track.half_width
		_quad(outil, gauche0, gauche1, droite0, droite1)
		return
	var n := couleurs.size()
	var largeur := track.half_width * 2.0
	for j in n:
		var g := -track.half_width + largeur * float(j) / float(n)
		var d := -track.half_width + largeur * float(j + 1) / float(n)
		outil.set_color(couleurs[j])
		_quad(outil,
			track.position_at(d0) + track.right_at(d0) * g,
			track.position_at(d1) + track.right_at(d1) * g,
			track.position_at(d0) + track.right_at(d0) * d,
			track.position_at(d1) + track.right_at(d1) * d)
