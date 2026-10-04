extends GutTest

## Les portails, les spectacles et le gardien : ce qui se passe autour de la
## route sans qu'on y touche, et qui suit la course plutôt que l'horloge.

var track: Track


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
	track.free()
	track = null


func _portail(debut: float) -> TrackPortail:
	var p := TrackPortail.new()
	p.debut = debut
	track.add_child(p)
	return p


# --- S'ouvrir devant le premier, se fermer derrière le dernier ------------------

func test_le_portail_est_ferme_tant_que_le_premier_est_loin() -> void:
	var p := _portail(300.0)
	assert_false(p.ouvert(100.0, 50.0, 500.0))


func test_le_portail_s_ouvre_quand_le_premier_approche() -> void:
	var p := _portail(300.0)
	assert_true(p.ouvert(300.0 - TrackPortail.AVANCE + 1.0, 50.0, 500.0))


func test_le_portail_reste_ouvert_tant_que_le_dernier_n_est_pas_passe() -> void:
	var p := _portail(300.0)
	# Le premier est loin devant, le dernier pas encore arrivé au portail.
	assert_true(p.ouvert(450.0, 250.0, 500.0))


func test_le_portail_se_ferme_une_fois_le_dernier_passe() -> void:
	var p := _portail(300.0)
	var sortie := 300.0 + p.longueur + TrackPortail.APRES
	assert_false(p.ouvert(480.0, sortie + 1.0, 500.0))


func test_le_portail_se_rouvre_au_tour_suivant() -> void:
	var p := _portail(300.0)
	# Deuxième tour : le premier revient vers le portail, le dernier l'a
	# passé au tour d'avant.
	assert_true(p.ouvert(500.0 + 300.0 - 20.0, 400.0, 500.0))


func test_le_couloir_est_plus_grand_dedans_que_dehors() -> void:
	var p := _portail(100.0)
	assert_almost_eq(p.rayon_du_couloir(0.0), p.rayon, 0.01)
	assert_gt(p.rayon_du_couloir(0.5), p.rayon * 1.5)
	assert_almost_eq(p.rayon_du_couloir(1.0), p.rayon, 0.01)


func test_l_effet_sur_la_camera_ne_joue_qu_au_portail() -> void:
	var p := _portail(100.0)
	p._ouverture = 1.0
	var tour := track.track_curve.length
	assert_eq(p.effet_a(10.0, tour), 0.0, "loin avant")
	assert_eq(p.effet_a(300.0, tour), 0.0, "loin après")
	assert_gt(p.effet_a(100.0 + p.longueur * 0.5, tour), 0.8, "en plein couloir")


func test_un_portail_ferme_ne_deforme_rien() -> void:
	var p := _portail(100.0)
	p._ouverture = 0.0
	assert_eq(p.effet_a(100.0 + p.longueur * 0.5, track.track_curve.length), 0.0)


# --- Les mondes de part et d'autre --------------------------------------------

func test_le_monde_est_celui_du_dernier_portail_franchi() -> void:
	var a := _portail(100.0)
	var b := _portail(300.0)
	assert_eq(track.portail_en(150.0), a)
	assert_eq(track.portail_en(350.0), b)
	# Avant le premier portail, on vient du dernier : le circuit boucle.
	assert_eq(track.portail_en(50.0), b)


func test_chaque_monde_a_son_ciel() -> void:
	var a := _portail(100.0)
	a.ambiance = Environment.new()
	_portail(300.0)
	assert_eq(track.ambiance_en(150.0), a.ambiance)
	assert_null(track.ambiance_en(350.0), "sans ambiance : le ciel du circuit")


func test_on_ne_voit_que_le_decor_du_monde_ou_l_on_est() -> void:
	var a := _portail(100.0)
	var b := _portail(300.0)
	var tours := Node3D.new()
	tours.name = "Tours"
	track.add_child(tours)
	var saloons := Node3D.new()
	saloons.name = "Saloons"
	track.add_child(saloons)
	a.decors = [NodePath("../Tours")]
	b.decors = [NodePath("../Saloons")]
	track.montrer_le_monde_de(a)
	assert_true(tours.visible)
	assert_false(saloons.visible)
	track.montrer_le_monde_de(b)
	assert_false(tours.visible)
	assert_true(saloons.visible)


func test_un_decor_introuvable_est_ignore() -> void:
	var a := _portail(100.0)
	a.decors = [NodePath("../Personne")]
	assert_eq(a.decors_du_monde().size(), 0)


# --- La course raconte où elle en est -------------------------------------------

func test_la_course_dit_au_circuit_ou_sont_le_premier_et_le_dernier() -> void:
	var karts: Array[Kart] = []
	for i in 2:
		var k := Kart.new()
		k.stats = KartStats.new()
		k.motor = KartMotor.new(k.stats)
		karts.append(k)
	var session := RaceSession.new()
	session.duree_decompte = 0.0
	session.demarrer(track, karts)
	session.entries[0].progress.total = 420.0
	session.entries[1].progress.total = 130.0
	session._raconter_au_circuit()
	assert_eq(track.tete_total, 420.0)
	assert_eq(track.queue_total, 130.0)
	session.free()
	for k in karts:
		k.free()


func test_l_avancement_va_du_depart_a_l_arrivee() -> void:
	track.tours_course = 2
	track.tete_total = 0.0
	assert_eq(track.avancement(), 0.0)
	track.tete_total = track.track_curve.length
	assert_almost_eq(track.avancement(), 0.5, 0.001)
	track.tete_total = track.track_curve.length * 5.0
	assert_eq(track.avancement(), 1.0)


# --- Les spectacles ---------------------------------------------------------------

func test_l_eclair_frappe_un_instant_a_chaque_periode() -> void:
	var s := TrackSpectacle.new()
	s.periode = 10.0
	assert_true(s.eclair_visible(0.1))
	assert_false(s.eclair_visible(5.0))
	assert_true(s.eclair_visible(10.1))
	s.free()


func test_la_lune_descend_au_fil_de_la_course() -> void:
	var s := TrackSpectacle.new()
	s.type = TrackSpectacle.Type.LUNE
	s.hauteur = 100.0
	s.rayon = 60.0
	assert_eq(s.hauteur_de_lune(0.0), 100.0)
	assert_eq(s.hauteur_de_lune(1.0), 60.0)
	assert_lt(s.hauteur_de_lune(0.6), s.hauteur_de_lune(0.3))
	s.free()


func test_chaque_spectacle_se_construit() -> void:
	for type in TrackSpectacle.Type.values():
		var s := TrackSpectacle.new()
		s.type = type
		s.longueur = 120.0
		track.add_child(s)
		s.reconstruire()
		assert_gt(s.get_child_count(), 0, "spectacle %d" % type)
		s._placer(3.0, 0.5)


func test_le_gardien_arpente_la_route() -> void:
	var g := TrackObstacle.new()
	g.type = TrackObstacle.Type.GARDIEN
	g.debut = 100.0
	g.amplitude = 5.5
	track.add_child(g)
	g.reconstruire()
	for i in 20:
		var pose := g.pose_de_la_tete(float(i) * 0.37)
		assert_lt(absf(pose.x), track.half_width, "il reste sur la route")
