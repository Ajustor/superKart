extends GutTest

## L'aspiration : derrière un autre kart, dans son axe, la jauge monte et
## lance un turbo. Et les tremplins lancent toujours un peu.

var track: Track
var karts: Array[Kart] = []
var session: RaceSession

const AVANT := Vector3(0.0, 0.0, -1.0)


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


func _session(combien: int = 2) -> void:
	session = RaceSession.new()
	session.duree_decompte = 0.0
	for i in combien:
		var k := Kart.new()
		k.stats = KartStats.new()
		k.motor = KartMotor.new(k.stats)
		karts.append(k)
	session.demarrer(track, karts)
	# La grille a placé et arrêté les karts : on les relance, tous vers -z.
	for k in karts:
		k.motor.speed = k.stats.max_speed
		k.motor.velocity_dir = 0.0


## Le kart 0 suit le kart 1 à `derriere` mètres, décalé de `cote`, pendant
## `secondes`. Tous deux vont vers -z (lacet nul).
func _suivre(derriere: float, cote: float, secondes: float) -> void:
	var positions: Array[Vector3] = [Vector3(cote, 0.0, derriere), Vector3.ZERO]
	var images := int(round(secondes * 60.0))
	for i in images:
		session.aspirer(positions, 1.0 / 60.0)


# --- La géométrie du sillage ----------------------------------------------------

func test_juste_derriere_on_est_dans_le_sillage() -> void:
	assert_true(Aspiration.dans_le_sillage(Vector3(0, 0, 6), AVANT, Vector3.ZERO, AVANT))
	assert_true(Aspiration.dans_le_sillage(Vector3(1.5, 0, 12), AVANT, Vector3.ZERO, AVANT))


func test_hors_de_l_axe_ou_trop_loin_non() -> void:
	assert_false(Aspiration.dans_le_sillage(Vector3(3.5, 0, 6), AVANT, Vector3.ZERO, AVANT), "à côté")
	assert_false(Aspiration.dans_le_sillage(Vector3(0, 0, 25), AVANT, Vector3.ZERO, AVANT), "trop loin")
	assert_false(Aspiration.dans_le_sillage(Vector3(0, 0, -6), AVANT, Vector3.ZERO, AVANT), "devant lui")
	assert_false(Aspiration.dans_le_sillage(Vector3(0, 6, 6), AVANT, Vector3.ZERO, AVANT), "sur un autre étage")


func test_un_kart_en_sens_inverse_n_aspire_pas() -> void:
	assert_false(Aspiration.dans_le_sillage(Vector3(0, 0, 6), AVANT, Vector3.ZERO, -AVANT))
	assert_false(Aspiration.dans_le_sillage(Vector3(0, 0, 6), AVANT, Vector3.ZERO, Vector3.RIGHT))


func test_le_cap_suit_le_lacet_du_moteur() -> void:
	assert_almost_eq(Aspiration.cap(0.0), AVANT, Vector3.ONE * 0.001)
	assert_almost_eq(Aspiration.cap(PI / 2.0), Vector3.RIGHT, Vector3.ONE * 0.001)


# --- La jauge et le turbo -------------------------------------------------------

func test_dans_le_sillage_assez_longtemps_le_turbo_part() -> void:
	_session()
	watch_signals(karts[0])
	_suivre(6.0, 0.0, Aspiration.CHARGE * 0.5)
	assert_eq(karts[0].motor.boost_timer, 0.0, "la jauge n'est qu'à moitié")
	assert_almost_eq(karts[0].aspiration, 0.5, 0.05, "et le kart le sait, pour le vent")
	_suivre(6.0, 0.0, Aspiration.CHARGE * 0.6)
	assert_gt(karts[0].motor.boost_timer, 0.0, "la jauge pleine lance le turbo")
	assert_almost_eq(karts[0].motor.boost_multiplier, Aspiration.FORCE_TURBO, 0.001)
	assert_signal_emitted(karts[0], "aspire")
	assert_eq(karts[1].motor.boost_timer, 0.0, "le meneur, lui, n'aspire rien")


func test_hors_du_sillage_la_jauge_se_vide() -> void:
	_session()
	_suivre(6.0, 0.0, Aspiration.CHARGE * 0.8)
	_suivre(6.0, 5.0, 1.0)
	assert_eq(session.entries[0].aspiration, 0.0)
	_suivre(6.0, 0.0, Aspiration.CHARGE * 0.3)
	assert_eq(karts[0].motor.boost_timer, 0.0, "une jauge vidée repart de zéro")


func test_trop_lent_on_n_aspire_pas() -> void:
	_session()
	karts[0].motor.speed = karts[0].stats.max_speed * 0.3
	_suivre(6.0, 0.0, Aspiration.CHARGE * 1.5)
	assert_eq(karts[0].motor.boost_timer, 0.0)


func test_derriere_un_kart_arrete_rien() -> void:
	_session()
	karts[1].motor.speed = 0.0
	_suivre(6.0, 0.0, Aspiration.CHARGE * 1.5)
	assert_eq(karts[0].motor.boost_timer, 0.0)


func test_en_l_air_on_n_aspire_pas() -> void:
	_session()
	karts[0].au_sol = false
	_suivre(6.0, 0.0, Aspiration.CHARGE * 1.5)
	assert_eq(karts[0].motor.boost_timer, 0.0)


func test_pas_d_aspiration_avant_le_depart() -> void:
	_session()
	session.en_course = false
	_suivre(6.0, 0.0, Aspiration.CHARGE * 1.5)
	assert_eq(karts[0].motor.boost_timer, 0.0)


# --- Les tremplins lancent ------------------------------------------------------

func test_un_tremplin_sans_reglage_donne_un_turbo() -> void:
	var saut := TrackJump.new()
	saut.debut = 40.0
	track.add_child(saut)
	saut.reconstruire()
	_session(1)
	karts[0].motor.speed = 20.0
	session.avancer(session.entries[0], TrackFeature.point(track.track_curve, 42.0, 0.0, 0.4), 1.0 / 60.0)
	assert_false(karts[0].au_sol)
	assert_gt(karts[0].motor.boost_timer, 0.0, "un tremplin lance toujours un peu")
