extends GutTest

## RaceSession n'a besoin de l'arbre que pour lire global_position. En passant
## le point en paramètre, toute sa logique se teste comme KartMotor : sans
## nœud, sans rendu, en quelques microsecondes. Les deux défauts que ce fichier
## attrape avaient traversé 90 tests verts faute de cette couture.
##
## La remise en piste se constate sur le moteur et non sur la position : lire
## global_position hors de l'arbre est justement ce qui ne marche pas, et
## respawn_at remet le moteur à neuf.

var track: Track
var kart: Kart
var session: RaceSession


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

	kart = Kart.new()
	kart.stats = KartStats.new()
	kart.motor = KartMotor.new(kart.stats)

	session = RaceSession.new()
	session.demarrer(track, kart)


func after_each() -> void:
	session.free()
	kart.free()
	track.free()


## Avance le long de l'axe par pas de 50 cm, en appelant la session comme le
## ferait le moteur, à 60 Hz.
func _rouler(de: float, vers: float) -> void:
	var d := de
	var pas := 0.5 * signf(vers - de)
	while absf(vers - d) > 0.5:
		d += pas
		session.avancer(track.track_curve.position_at(d), 1.0 / 60.0)
	session.avancer(track.track_curve.position_at(vers), 1.0 / 60.0)


func test_un_tour_honnete_enregistre_un_tour() -> void:
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_eq(session.progress.lap, 1)
	assert_true(session.timer.has_best, "le tour bouclé donne un meilleur temps")
	assert_gt(session.timer.best, 1.0, "et ce temps n'est pas dérisoire")


func test_reculer_sur_la_ligne_ne_refabrique_pas_de_tour() -> void:
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	var reference := session.timer.best

	# À cheval sur la ligne, et non au-delà : c'est le passage sous une
	# longueur entière qui fait redescendre progress.lap, et rien d'autre.
	for i in 20:
		session.avancer(track.track_curve.position_at(L - 0.4), 1.0 / 60.0)
		assert_eq(session.progress.lap, 0,
			"reculer sous la ligne ramène bien le compteur à zéro")
		session.avancer(track.track_curve.position_at(L + 0.3), 1.0 / 60.0)

	assert_almost_eq(session.timer.best, reference, 0.0001,
		"repasser la ligne à l'envers ne doit pas offrir un tour de deux images")


func test_le_hors_piste_ne_se_fige_pas_apres_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_true(session.finished, "un tour suffit à finir cette course")

	# Entre le bord de piste et la marge de remise en piste : assez dehors pour
	# que le drapeau lève, pas assez pour être ramené. Sinon la remise en piste
	# remettrait le moteur à neuf dans la même image et effacerait le drapeau.
	var large := track.track_curve.position_at(100.0) \
		+ track.track_curve.right_at(100.0) * 10.5
	session.avancer(large, 1.0 / 60.0)

	assert_true(kart.motor.on_offroad,
		"le hors-piste ne se fige pas parce que la course est finie")


func test_la_remise_en_piste_continue_apres_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_true(session.finished)

	kart.motor.speed = 20.0
	var dehors := track.track_curve.position_at(100.0) \
		+ track.track_curve.right_at(100.0) * 40.0
	session.avancer(dehors, 1.0 / 60.0)

	assert_eq(kart.motor.speed, 0.0,
		"respawn_at remet le moteur à neuf : sans lui le kart tombe sans fin")


func test_le_chrono_s_arrete_a_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	var fige := session.timer.current
	for i in 30:
		session.avancer(track.track_curve.position_at(10.0), 1.0 / 60.0)
	assert_almost_eq(session.timer.current, fige, 0.0001,
		"le chrono ne tourne plus une fois la course finie")
