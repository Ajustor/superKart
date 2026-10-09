extends GutTest

var track: TrackCurve


func _anneau(rayon: float = 50.0, points: int = 16) -> Curve3D:
	var c := Curve3D.new()
	var pas := TAU / float(points)
	var poignee := rayon * (4.0 / 3.0) * tan(pas / 4.0)
	for i in points:
		var a := pas * float(i)
		var p := Vector3(sin(a) * rayon, 0.0, -cos(a) * rayon)
		var t := Vector3(cos(a), 0.0, sin(a)) * poignee
		c.add_point(p, -t, t)
	c.add_point(c.get_point_position(0), -c.get_point_out(0), c.get_point_out(0))
	return c


func before_each() -> void:
	track = TrackCurve.new(_anneau(), 8.0)


func test_les_normales_pointent_vers_le_haut() -> void:
	var maillage := TrackBuilder.build(track, 5.0)
	var normales: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_gt(normales.size(), 0, "le maillage doit porter des normales")
	for n in normales:
		assert_gt(n.y, 0.9,
			"une normale vers le bas trahit un ordre de sommets inversé")


func test_chaque_section_donne_deux_triangles() -> void:
	var maillage := TrackBuilder.build(track, 10.0)
	var sommets: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sections := maxi(int(track.length / 10.0), 8)
	assert_eq(sommets.size(), sections * 6,
		"deux triangles de trois sommets par section")


func test_le_ruban_couvre_toute_la_largeur() -> void:
	var maillage := TrackBuilder.build(track, 5.0)
	var sommets: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ecart_max := 0.0
	for v in sommets:
		ecart_max = maxf(ecart_max, absf(track.lateral_offset(v)))
	assert_almost_eq(ecart_max, track.half_width, 0.3,
		"les bords du ruban tombent sur la demi-largeur")


## Une ligne droite de 60 m dont le dévers passe de 11° à 6° en 10 m, puis
## revient : les sections du milieu sont des quadrilatères tordus.
func _devers_qui_change() -> TrackCurve:
	var c := Curve3D.new()
	var tilts := [11.0, 6.0, 11.0, 6.0, 11.0, 6.0, 11.0]
	for i in tilts.size():
		c.add_point(Vector3(0.0, 0.0, -10.0 * i))
		c.set_point_tilt(i, deg_to_rad(tilts[i]))
	return TrackCurve.new(c, 9.0)


## La hauteur du maillage sous ce point, par un rayon vertical contre ses
## triangles ; INF s'il n'y en a pas.
static func _hauteur_du_maillage(triangles: PackedVector3Array, ici: Vector3) -> float:
	for t in range(0, triangles.size(), 3):
		var touche: Variant = Geometry3D.ray_intersects_triangle(ici + Vector3.UP * 5.0, Vector3.DOWN,
			triangles[t], triangles[t + 1], triangles[t + 2])
		if touche != null:
			return (touche as Vector3).y
	return INF


func test_le_bitume_suit_la_courbe_quand_le_devers_change() -> void:
	var c := _devers_qui_change()
	var maillage := TrackBuilder.build(c, 2.0)
	var faces := maillage.get_faces()
	var sections := maxi(int(c.length / 2.0), 8)
	var pire := 0.0
	var ou := ""
	for i in sections - 1:
		var milieu := c.length * (float(i) + 0.5) / float(sections)
		# Aux deux bouts, la courbe ouverte prend sa tangente à l'autre bout.
		if milieu < 4.0 or milieu > c.length - 4.0:
			continue
		for lateral in [-9.0, -4.5, 0.0, 4.5, 9.0]:
			# Un rien en dedans des bords : un rayon pile sur l'arête du ruban
			# peut le manquer.
			var l: float = clampf(lateral, -8.95, 8.95)
			var attendu := c.position_at(milieu) + c.right_at(milieu) * l
			var h := _hauteur_du_maillage(faces, attendu)
			var ecart := absf(h - attendu.y)
			if ecart > pire:
				pire = ecart
				ou = "%.1f m, %+.1f" % [milieu, l]
	assert_lt(pire, 0.02, "le bitume s'écarte de %.1f cm de la courbe (%s)" % [pire * 100.0, ou])
