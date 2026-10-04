extends GutTest

## Une course d'un bout à l'autre, sans tours (Track.arrivee) : on la découpe
## en sections, et l'arrivée est au bout du tracé, pas sur la ligne de départ.
## Et les portails à plat, où l'on tombe pour ressortir de l'autre côté.

var track: Track
var karts: Array[Kart] = []
var session: RaceSession


func _anneau(rayon: float = 120.0, points: int = 16) -> Curve3D:
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


func _session() -> void:
	session = RaceSession.new()
	session.duree_decompte = 0.0
	session.lap_count = 1
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	karts.append(k)
	session.demarrer(track, karts)
	session.avancer_decompte(0.0)


func _rouler_jusqu_a(total: float) -> void:
	var e := session.entries[0]
	e.progress.total = total
	e.progress.distance = track.track_curve.wrap(total)
	session.avancer(e, track.track_curve.position_at(e.progress.distance), 1.0 / 60.0)


func test_une_course_lineaire_finit_a_l_arrivee_sans_boucler_le_tour() -> void:
	track.arrivee = 500.0
	_session()
	_rouler_jusqu_a(450.0)
	assert_false(session.entries[0].finished)
	_rouler_jusqu_a(501.0)
	assert_true(session.entries[0].finished, "arrivé bien avant la fin de la boucle")


func test_une_course_lineaire_compte_ses_sections() -> void:
	track.arrivee = 600.0
	track.sections = PackedFloat32Array([200.0, 400.0])
	_session()
	var e := session.entries[0]
	assert_eq(session.etapes(), 3)
	_rouler_jusqu_a(100.0)
	assert_eq(session.texte_etape(e), "SECTION 1/3")
	_rouler_jusqu_a(250.0)
	assert_eq(session.texte_etape(e), "SECTION 2/3")
	assert_eq(e.tours_comptes, 1)
	_rouler_jusqu_a(450.0)
	assert_eq(session.texte_etape(e), "SECTION 3/3")


func test_une_course_en_tours_garde_ses_tours() -> void:
	_session()
	assert_false(session.lineaire())
	assert_eq(session.texte_etape(session.entries[0]), "TOUR 1/1")


func test_l_avancement_d_une_course_lineaire_va_jusqu_a_l_arrivee() -> void:
	track.arrivee = 400.0
	track.tete_total = 200.0
	assert_almost_eq(track.avancement(), 0.5, 0.001)


func test_ce_qui_suit_l_arrivee_est_hors_course() -> void:
	track.arrivee = 400.0
	assert_false(track.hors_course(300.0))
	assert_true(track.hors_course(500.0))
	assert_false(track.hors_course(track.track_curve.length - 10.0), "la grille, elle, est courue")


func test_tomber_dans_un_portail_a_plat_ressort_de_l_autre_cote_sans_ralentir() -> void:
	var trou := TrackGap.new()
	trou.debut = 100.0
	trou.longueur = 30.0
	trou.chute_voulue = true
	track.add_child(trou)
	_session()
	var e := session.entries[0]
	e.kart.motor.speed = 20.0
	e.kart.motor.pieces = 5
	e.kart.au_sol = false
	e.progress.total = 110.0
	e.progress.distance = 110.0
	var dedans := track.track_curve.position_at(110.0) - Vector3.UP * 5.0
	session.avancer(e, dedans, 1.0 / 60.0)
	assert_almost_eq(e.derniere_en_piste, 136.0, 0.01, "ressorti juste après le trou")
	assert_eq(e.kart.motor.speed, 20.0, "sans perdre sa vitesse")
	assert_eq(e.kart.motor.pieces, 5, "ni ses pièces")
