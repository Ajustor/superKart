extends GutTest

## Les sols (TrackSol, TrackTerrain) portent le kart près de la route : on y
## roule, hors piste, sans être remis en piste — mais pas au loin, pas en
## contrebas, et pas en coupant à travers champs.

var track: Track
var karts: Array[Kart] = []
var session: RaceSession


func _anneau(rayon: float = 80.0, points: int = 16) -> Curve3D:
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
	if session != null:
		session.free()
		session = null
	for k in karts:
		k.free()
	karts.clear()
	track.free()
	track = null


func _poser(element: TrackFeature, nom: String = "") -> TrackFeature:
	if nom != "":
		element.name = nom
	track.add_child(element)
	element.reconstruire()
	return element


func _sol() -> TrackSol:
	var sol := TrackSol.new()
	sol.marge = 60.0
	return _poser(sol, "Sol") as TrackSol


func _session() -> void:
	session = RaceSession.new()
	session.duree_decompte = 0.0
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	karts.append(k)
	session.demarrer(track, karts)


func _point(distance: float, lateral: float = 0.0) -> Vector3:
	return TrackFeature.point(track.track_curve, distance, lateral, 0.4)


func _rouler(distance: float, lateral: float) -> void:
	karts[0].velocity = Vector3(20.0, 0.0, 0.0)
	karts[0].motor.speed = 20.0
	session.avancer(session.entries[0], _point(distance, lateral), 1.0 / 60.0)


# --- Le sol porte près de la route, et seulement là ------------------------------

func test_le_sol_porte_sur_les_bas_cotes() -> void:
	var sol := _sol()
	assert_true(sol.porte(_point(100.0, 14.0), 100.0), "à cinq mètres du bord")
	assert_false(sol.porte(_point(100.0, 9.0 + Track.PORTEE_HORS_PISTE + 20.0), 100.0), "au loin, c'est du décor")
	assert_false(sol.porte(_point(100.0, 14.0) - Vector3.UP * 5.0, 100.0), "dessous, il ne porte pas")


func test_seules_les_cases_du_bord_ont_une_collision() -> void:
	_sol()
	var corps := track.get_node("Sol").find_child("SolPorteur", true, false) as StaticBody3D
	assert_not_null(corps, "le sol a un corps")
	var forme := (corps.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D
	var faces := forme.get_faces()
	assert_gt(faces.size(), 0)
	var portee := 9.0 + Track.PORTEE_HORS_PISTE + 6.0 * 2.5
	for sommet in faces:
		var rayon := Vector2(sommet.x, sommet.z).length()
		assert_lt(absf(rayon - 80.0), portee, "un triangle porteur loin de la route")
		if absf(rayon - 80.0) >= portee:
			return


func test_un_trou_de_la_route_perce_le_sol() -> void:
	var trou := TrackGap.new()
	trou.debut = 100.0
	trou.longueur = 20.0
	_poser(trou)
	var sol := _sol()
	assert_false(sol.porte(_point(110.0, 0.0), 110.0), "on tombe dans le trou, pas sur le sol")
	assert_true(sol.porte(_point(200.0, 14.0), 200.0))


func test_un_sol_ne_porte_que_dans_son_monde() -> void:
	var a := TrackPortail.new()
	a.debut = 10.0
	a.decors = [NodePath("../Sol")]
	_poser(a)
	var b := TrackPortail.new()
	b.debut = 250.0
	_poser(b)
	var sol := _sol()
	assert_true(sol.porte(_point(100.0, 14.0), 100.0), "au bord de la route de son monde")
	assert_false(sol.porte(_point(380.0, 14.0), 380.0), "invisible dans l'autre monde : il n'y porte pas")


func test_au_portail_chaque_sol_ne_porte_que_de_son_cote() -> void:
	# Deux mondes, deux sols plats à des hauteurs différentes : celui d'après
	# le portail, plus haut, ne doit pas faire plafond juste avant.
	var a := TrackPortail.new()
	a.debut = 10.0
	a.decors = [NodePath("../Avant")]
	_poser(a)
	var b := TrackPortail.new()
	b.debut = 250.0
	b.decors = [NodePath("../Apres")]
	_poser(b)
	var avant := TrackSol.new()
	avant.marge = 60.0
	avant.altitude = -0.9
	_poser(avant, "Avant")
	var apres := TrackSol.new()
	apres.marge = 60.0
	_poser(apres, "Apres")
	var juste_avant := _point(240.0, 14.0) - Vector3.UP * 0.5
	assert_false(apres.porte(juste_avant, 240.0), "le sol d'après ne porte pas avant le portail")
	assert_true(avant.porte(juste_avant, 240.0))
	assert_true(apres.porte(_point(262.0, 14.0), 262.0))


func test_le_sol_s_abaisse_sous_le_bord_bas_d_un_virage_releve() -> void:
	var c := track.track_curve.curve
	for i in c.point_count:
		c.set_point_tilt(i, deg_to_rad(10.0))
	track.track_curve = TrackCurve.new(c, 9.0)
	var sol := _sol()
	var cc := track.track_curve
	for lateral: float in [-12.0, -8.0, -4.0, 4.0, 8.0, 12.0]:
		var ici := cc.position_at(100.0) + cc.right_at(100.0) * lateral
		var route := cc.position_at(100.0).y + cc.right_at(100.0).y * clampf(lateral, -9.0, 9.0)
		assert_lt(sol.hauteur_en(ici.x, ici.z), route, "à %.0f m de l'axe, le sol reste sous la route" % lateral)


func test_le_relief_porte_sur_les_bas_cotes() -> void:
	var relief := TrackTerrain.new()
	relief.marge = 80.0
	_poser(relief, "Relief")
	assert_true(relief.porte(_point(100.0, 14.0), 100.0))
	assert_false(relief.porte(_point(100.0, 9.0 + Track.PORTEE_HORS_PISTE + 20.0), 100.0))
	assert_not_null(relief.find_child("SolPorteur", true, false))


# --- La course : on roule dans l'herbe, on n'en abuse pas ---------------------------

func test_on_roule_dans_l_herbe_sans_etre_remis_en_piste() -> void:
	_sol()
	_session()
	_rouler(100.0, 14.0)
	_rouler(100.3, 14.0)
	assert_eq(karts[0].motor.speed, 20.0, "un vrai sol : on y reste")
	assert_true(karts[0].motor.on_offroad, "mais c'est du hors-piste")


func test_sans_sol_sortir_remet_toujours_en_piste() -> void:
	_session()
	_rouler(100.0, 14.0)
	assert_eq(karts[0].motor.speed, 0.0)


func test_trop_loin_de_la_route_on_est_remis_en_piste() -> void:
	_sol()
	_session()
	_rouler(100.0, 9.0 + Track.PORTEE_HORS_PISTE + 3.0)
	assert_eq(karts[0].motor.speed, 0.0, "sorti du circuit")


func test_tombe_en_contrebas_on_est_remis_en_piste() -> void:
	_sol()
	_session()
	karts[0].velocity = Vector3(20.0, 0.0, 0.0)
	karts[0].motor.speed = 20.0
	session.avancer(session.entries[0], _point(100.0, 14.0) - Vector3.UP * 5.0, 1.0 / 60.0)
	assert_eq(karts[0].motor.speed, 0.0)


func test_couper_a_travers_champs_remet_en_piste() -> void:
	_sol()
	_session()
	_rouler(100.0, 14.0)
	_rouler(100.3, 14.0)
	# Soixante mètres de tracé gagnés en une image de vingt mètres-seconde :
	# l'herbe a servi de raccourci.
	_rouler(160.0, 14.0)
	assert_eq(karts[0].motor.speed, 0.0)


func test_la_corde_d_un_virage_n_est_pas_un_raccourci() -> void:
	_sol()
	_session()
	var d := 100.0
	_rouler(d, 12.0)
	for i in 60:
		d += 0.4
		_rouler(d, 12.0)
	assert_eq(karts[0].motor.speed, 20.0, "un peu plus de tracé que de route roulée, c'est permis")


# --- Les mondes sur la grille d'une course linéaire ---------------------------------

func test_sur_la_grille_on_est_dans_le_monde_du_depart() -> void:
	var depart := TrackPortail.new()
	depart.debut = 1.0
	_poser(depart)
	var arrivee := TrackPortail.new()
	arrivee.debut = 300.0
	_poser(arrivee)
	var grille := track.track_curve.length - 10.0
	assert_eq(track.monde_en(grille), arrivee, "sur une boucle, on vient de faire le tour")
	track.arrivee = 400.0
	assert_eq(track.monde_en(grille), depart, "en ligne, la grille est au départ")
	assert_eq(track.portail_en(grille), depart)
	assert_eq(track.monde_en(0.5), depart, "avant le premier portail aussi")
	assert_eq(track.monde_en(350.0), arrivee)


func test_un_sol_loin_sous_la_route_ne_la_borde_pas() -> void:
	var sol := TrackSol.new()
	sol.marge = 60.0
	sol.altitude = -3.0
	_poser(sol, "Sol")
	assert_false(sol.porte(_point(100.0, 14.0) - Vector3.UP * 3.0, 100.0),
		"une route sur un talus : on ne remonterait pas, pas de bas-côté")


func test_le_bas_cote_d_un_virage_releve_n_est_pas_un_fosse() -> void:
	# Une route relevée de dix degrés : à quatorze mètres de l'axe, le sol
	# plat du côté bas est loin sous la normale, pas sous le bord.
	var c := track.track_curve.curve
	for i in c.point_count:
		c.set_point_tilt(i, deg_to_rad(10.0))
	track.track_curve = TrackCurve.new(c, 9.0)
	_sol()
	_session()
	var cc := track.track_curve
	var bas := -14.0 if cc.right_at(100.0).y > 0.0 else 14.0
	var ici := cc.position_at(100.0) + cc.right_at(100.0) * bas
	ici.y = cc.position_at(100.0).y + cc.right_at(100.0).y * signf(bas) * 9.0 + 0.4
	karts[0].velocity = Vector3(20.0, 0.0, 0.0)
	karts[0].motor.speed = 20.0
	session.avancer(session.entries[0], ici, 1.0 / 60.0)
	assert_eq(karts[0].motor.speed, 20.0)
