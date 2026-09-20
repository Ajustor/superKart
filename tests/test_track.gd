extends GutTest

## Track a besoin de l'arbre pour construire son maillage, mais spawn_at ne
## touche qu'à la courbe : on renseigne track_curve à la main et on teste la
## géométrie sans jamais entrer dans l'arbre.

var track: Track


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
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)


func after_each() -> void:
	track.free()


func test_sans_decalage_on_reste_sur_la_ligne_de_course() -> void:
	var avant := track.spawn_at(120.0)
	var attendu := track.track_curve.racing_line_at(120.0)
	assert_almost_eq(avant.origin.x, attendu.x, 0.001)
	assert_almost_eq(avant.origin.z, attendu.z, 0.001)


func test_un_decalage_positif_pose_le_kart_a_droite() -> void:
	var centre := track.spawn_at(120.0)
	var droite := track.spawn_at(120.0, 3.0)
	var vers := droite.origin - centre.origin
	vers.y = 0.0
	var a_droite := track.track_curve.right_at(120.0)
	assert_almost_eq(vers.dot(a_droite), 3.0, 0.001,
		"trois mètres vers la droite de la marche, et pas ailleurs")
	assert_almost_eq(vers.length(), 3.0, 0.001)


func test_un_decalage_negatif_pose_le_kart_a_gauche() -> void:
	var centre := track.spawn_at(120.0)
	var gauche := track.spawn_at(120.0, -3.0)
	var vers := gauche.origin - centre.origin
	vers.y = 0.0
	assert_almost_eq(vers.dot(track.track_curve.right_at(120.0)), -3.0, 0.001)


func test_le_decalage_ne_change_pas_l_orientation() -> void:
	var centre := track.spawn_at(120.0)
	var decale := track.spawn_at(120.0, 4.0)
	assert_almost_eq(decale.basis.get_euler().y, centre.basis.get_euler().y, 0.0001,
		"un kart décalé sur la grille regarde toujours dans le sens de la marche")
