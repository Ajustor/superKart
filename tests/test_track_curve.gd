extends GutTest

var track: TrackCurve


## Un anneau circulaire de rayon 50, parcouru dans le sens horaire vu de
## dessus. Une forme dont on connaît analytiquement toutes les propriétés,
## ce qui permet de tester les formules et non leurs approximations.
func _anneau(rayon: float = 50.0, points: int = 16) -> Curve3D:
	var c := Curve3D.new()
	var pas := TAU / float(points)
	# Longueur de poignée d'une approximation de Bézier d'un arc de cercle.
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


func test_la_longueur_approche_le_perimetre() -> void:
	assert_almost_eq(track.length, TAU * 50.0, 1.0,
		"la longueur bakée doit approcher le périmètre du cercle")


func test_le_point_a_zero_est_le_premier_point_de_la_courbe() -> void:
	var p := track.position_at(0.0)
	assert_almost_eq(p.x, 0.0, 0.1)
	assert_almost_eq(p.z, -50.0, 0.1)


func test_la_tangente_est_horizontale_et_unitaire() -> void:
	for d in [0.0, 50.0, 120.0, 250.0]:
		var t := track.tangent_at(d)
		assert_almost_eq(t.y, 0.0, 0.001, "la tangente reste horizontale")
		assert_almost_eq(t.length(), 1.0, 0.001, "la tangente est normalisée")


func test_le_cap_suit_la_convention_boussole() -> void:
	# Au point de départ, la courbe part vers +X : cap de +90° à la boussole.
	assert_almost_eq(track.yaw_at(0.0), PI * 0.5, 0.1,
		"partir vers +X correspond à un cap de +90°")


func test_la_droite_est_perpendiculaire_a_la_tangente() -> void:
	for d in [0.0, 70.0, 200.0]:
		var t := track.tangent_at(d)
		var r := track.right_at(d)
		assert_almost_eq(t.dot(r), 0.0, 0.001, "droite et tangente sont perpendiculaires")
		assert_almost_eq(r.length(), 1.0, 0.001)


func test_la_droite_pointe_vers_l_interieur_de_l_anneau() -> void:
	# L'anneau tourne à droite en permanence, donc son centre est à droite de
	# la marche : c'est le côté intérieur du virage.
	var d := 80.0
	var vers_droite := track.position_at(d) + track.right_at(d) * 10.0
	assert_lt(vers_droite.length(), track.position_at(d).length(),
		"la droite de la marche se rapproche du centre sur un anneau horaire")


func test_la_distance_s_enroule_sur_la_longueur() -> void:
	assert_almost_eq(track.wrap(track.length + 10.0), 10.0, 0.001)
	assert_almost_eq(track.wrap(-10.0), track.length - 10.0, 0.001)
