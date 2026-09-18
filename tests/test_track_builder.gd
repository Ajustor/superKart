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
