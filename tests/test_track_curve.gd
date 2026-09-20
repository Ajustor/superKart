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


func test_la_ligne_de_course_reste_sur_le_bitume_du_vrai_circuit() -> void:
	# L'anneau des autres tests a une courbure constante et douce : il ne
	# sature jamais le mordant, donc il ne prouve rien du plafond. L'épingle
	# de track_01, si — la marge n'y est que de douze centimètres.
	var courbe: Curve3D = load("res://resources/tracks/track_01_curve.tres")
	var piste := TrackCurve.new(courbe, 9.0)
	var pire := 0.0
	var d := 0.0
	while d < piste.length:
		var ecart := absf(piste.lateral_offset(piste.racing_line_at(d)))
		pire = maxf(pire, ecart)
		d += 0.5
	assert_lt(pire, 9.0,
		"la ligne de course doit rester sur la chaussée, épingle comprise")


func test_le_virage_est_positif_vers_la_droite() -> void:
	# L'anneau des autres tests tourne à droite vu de dessus.
	assert_gt(track.turn_at(100.0), 0.0,
		"un circuit qui tourne à droite doit rendre une variation de cap positive")


func test_le_rayon_de_courbure_retrouve_celui_de_l_anneau() -> void:
	# Un anneau de rayon 50 doit se mesurer à 50, à l'approximation de la
	# fenêtre près : c'est la seule forme dont on connaisse la réponse.
	assert_almost_eq(track.radius_at(120.0), 50.0, 2.0,
		"le rayon mesuré doit retrouver celui de la forme connue")


func test_un_anneau_plus_serre_donne_un_rayon_plus_petit() -> void:
	var serre := TrackCurve.new(_anneau(15.0, 24), 8.0)
	assert_almost_eq(serre.radius_at(20.0), 15.0, 1.5,
		"un anneau de rayon 15 doit se mesurer à 15")
	assert_lt(serre.radius_at(20.0), track.radius_at(20.0),
		"et rester nettement en deçà de l'anneau de 50")


func test_une_ligne_droite_a_un_rayon_infini() -> void:
	var droite := Curve3D.new()
	for i in 6:
		droite.add_point(Vector3(0.0, 0.0, -40.0 * float(i)))
	var plate := TrackCurve.new(droite, 8.0)
	assert_gt(plate.radius_at(60.0), 1000.0,
		"sans virage, le rayon ne doit pas être une petite valeur bruitée")


func test_le_rayon_est_positif_des_deux_cotes() -> void:
	# Un virage à gauche a une variation de cap négative, mais un rayon reste
	# un rayon : le signe n'a rien à faire là.
	var gauche := Curve3D.new()
	var pas := TAU / 16.0
	var poignee := 30.0 * (4.0 / 3.0) * tan(pas / 4.0)
	for i in 16:
		var a := pas * float(i)
		# Sens inverse de _anneau : le circuit tourne à gauche.
		var p := Vector3(-sin(a) * 30.0, 0.0, -cos(a) * 30.0)
		var t := Vector3(-cos(a), 0.0, sin(a)) * poignee
		gauche.add_point(p, -t, t)
	gauche.add_point(gauche.get_point_position(0), -gauche.get_point_out(0), gauche.get_point_out(0))
	var c := TrackCurve.new(gauche, 8.0)
	assert_lt(c.turn_at(30.0), 0.0, "un virage à gauche a une variation négative")
	assert_almost_eq(c.radius_at(30.0), 30.0, 2.0, "mais son rayon reste positif")
