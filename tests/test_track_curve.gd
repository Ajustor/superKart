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


func test_le_cap_est_juste_la_ou_les_deux_axes_comptent() -> void:
	# Au huitième du tour la tangente a ses composantes x et z toutes deux
	# non nulles : c'est le seul endroit où une inversion de signe sur z se
	# voit. Au point zéro, t.z vaut zéro et les deux signes donnent le même
	# résultat.
	assert_almost_eq(track.yaw_at(track.length / 8.0), PI * 0.75, 0.05,
		"à un huitième de l'anneau, le cap boussole vaut 135°")


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


func test_un_point_sur_l_axe_se_projette_sur_lui_meme() -> void:
	for d in [0.0, 60.0, 180.0]:
		var p := track.position_at(d)
		assert_almost_eq(track.distance_of(p), d, 1.0,
			"la projection doit retrouver la distance d'origine")


func test_l_ecart_lateral_est_signe() -> void:
	var d := 90.0
	var axe := track.position_at(d)
	var droite := track.right_at(d)
	assert_almost_eq(track.lateral_offset(axe + droite * 5.0), 5.0, 0.3,
		"à droite de l'axe, l'écart est positif")
	assert_almost_eq(track.lateral_offset(axe - droite * 5.0), -5.0, 0.3,
		"à gauche, il est négatif")


func test_l_ecart_lateral_est_nul_sur_l_axe() -> void:
	assert_almost_eq(track.lateral_offset(track.position_at(140.0)), 0.0, 0.3)


func test_le_hors_piste_se_declenche_au_dela_de_la_demi_largeur() -> void:
	var d := 40.0
	var axe := track.position_at(d)
	var droite := track.right_at(d)
	assert_false(track.is_off_track(axe), "l'axe est sur la piste")
	assert_false(track.is_off_track(axe + droite * (track.half_width - 1.0)),
		"juste à l'intérieur du bord, on est encore sur la piste")
	assert_true(track.is_off_track(axe + droite * (track.half_width + 1.0)),
		"au-delà du bord, on est hors-piste")
	assert_true(track.is_off_track(axe - droite * (track.half_width + 1.0)),
		"des deux côtés")


func test_la_hauteur_n_influence_pas_le_hors_piste() -> void:
	var haut := track.position_at(20.0) + Vector3.UP * 30.0
	assert_false(track.is_off_track(haut),
		"sauter ne doit pas compter comme une sortie de piste")


func test_la_ligne_de_course_mord_l_interieur_d_un_virage() -> void:
	# L'anneau tourne à droite en permanence, donc l'intérieur est à droite
	# partout, et la ligne doit s'y décaler sur tout le tour.
	for d in [0.0, 80.0, 160.0, 240.0]:
		var ecart := track.lateral_offset(track.racing_line_at(d))
		assert_gt(ecart, 1.0, "la ligne se décale vers l'intérieur à %f" % d)


func test_la_ligne_de_course_reste_sur_la_piste() -> void:
	for i in 40:
		var d := track.length * float(i) / 40.0
		assert_false(track.is_off_track(track.racing_line_at(d)),
			"la ligne de course ne doit jamais sortir de la piste")


func test_la_ligne_de_course_suit_une_ligne_droite() -> void:
	var droite := Curve3D.new()
	droite.add_point(Vector3(0, 0, 0))
	droite.add_point(Vector3(0, 0, -100))
	droite.add_point(Vector3(0, 0, -200))
	var plate := TrackCurve.new(droite, 8.0)
	assert_almost_eq(plate.lateral_offset(plate.racing_line_at(100.0)), 0.0, 0.5,
		"sans courbure, la ligne de course reste sur l'axe")


func test_un_virage_plus_serre_mord_davantage() -> void:
	var serre := TrackCurve.new(_anneau(10.0), 8.0)
	var large := TrackCurve.new(_anneau(50.0), 8.0)
	var mordant_serre := serre.lateral_offset(serre.racing_line_at(serre.length * 0.25))
	var mordant_large := large.lateral_offset(large.racing_line_at(large.length * 0.25))
	assert_gt(mordant_serre, mordant_large,
		"plus le virage est serré, plus la ligne de course mord vers l'intérieur")
