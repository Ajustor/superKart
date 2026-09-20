extends GutTest

## RaceSession n'a besoin de l'arbre que pour lire global_position. En passant
## le point en paramètre, toute sa logique se teste comme KartMotor : sans
## nœud, sans rendu, en quelques microsecondes. Deux défauts — un meilleur tour
## fabriqué en reculant sur la ligne, un kart qui tombait sans fin après
## l'arrivée — avaient traversé une campagne verte faute de cette couture.
##
## La remise en piste se constate sur le moteur et non sur la position : lire
## global_position hors de l'arbre est justement ce qui ne marche pas, et
## respawn_at remet le moteur à neuf.

var track: Track
var karts: Array[Kart] = []
var cerveaux: Array[KartInput] = []
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


func _kart() -> Kart:
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	return k


## Monte une session de `combien` karts, sans jamais entrer dans l'arbre.
## Démonte d'abord ce qui existe : `before_each` a déjà monté une session à un
## kart, et un test qui en remonte une à huit laisserait sinon des nœuds
## orphelins derrière lui — que GUT compte et signale.
func _monter(combien: int) -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	session = RaceSession.new()
	for i in combien:
		karts.append(_kart())
	session.demarrer(track, karts)


func _demonter() -> void:
	if session != null:
		session.free()
		session = null
	for c in cerveaux:
		c.free()
	cerveaux.clear()
	for k in karts:
		k.free()
	karts.clear()
	if track != null:
		track.free()
		track = null


func before_each() -> void:
	_monter(1)


func after_each() -> void:
	_demonter()


## Le concurrent du joueur, celui qu'on suit dans la plupart des tests.
func _joueur() -> RaceEntry:
	return session.entries[0]


## Avance le long de l'axe par pas de 50 cm, en appelant la session comme le
## ferait le moteur, à 60 Hz.
func _rouler(de: float, vers: float) -> void:
	var d := de
	var pas := 0.5 * signf(vers - de)
	while absf(vers - d) > 0.5:
		d += pas
		session.avancer(_joueur(), track.track_curve.position_at(d), 1.0 / 60.0)
	session.avancer(_joueur(), track.track_curve.position_at(vers), 1.0 / 60.0)


func test_un_tour_honnete_enregistre_un_tour() -> void:
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_eq(_joueur().progress.lap, 1)
	assert_true(_joueur().timer.has_best, "le tour bouclé donne un meilleur temps")
	assert_gt(_joueur().timer.best, 1.0, "et ce temps n'est pas dérisoire")


func test_reculer_sur_la_ligne_ne_refabrique_pas_de_tour() -> void:
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	var reference := _joueur().timer.best

	# À cheval sur la ligne, et non au-delà : c'est le passage sous une
	# longueur entière qui fait redescendre progress.lap, et rien d'autre.
	for i in 20:
		session.avancer(_joueur(), track.track_curve.position_at(L - 0.4), 1.0 / 60.0)
		assert_eq(_joueur().progress.lap, 0,
			"reculer sous la ligne ramène bien le compteur à zéro")
		session.avancer(_joueur(), track.track_curve.position_at(L + 0.3), 1.0 / 60.0)

	assert_almost_eq(_joueur().timer.best, reference, 0.0001,
		"repasser la ligne à l'envers ne doit pas offrir un tour de deux images")


func test_le_hors_piste_ne_se_fige_pas_apres_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_true(_joueur().finished, "un tour suffit à finir cette course")

	# Entre le bord de piste et la marge de remise en piste : assez dehors pour
	# que le drapeau lève, pas assez pour être ramené. Sinon la remise en piste
	# remettrait le moteur à neuf dans la même image et effacerait le drapeau.
	var large := track.track_curve.position_at(100.0) \
		+ track.track_curve.right_at(100.0) * 10.5
	session.avancer(_joueur(), large, 1.0 / 60.0)

	assert_true(karts[0].motor.on_offroad,
		"le hors-piste ne se fige pas parce que la course est finie")


func test_la_remise_en_piste_continue_apres_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_true(_joueur().finished)

	karts[0].motor.speed = 20.0
	var dehors := track.track_curve.position_at(100.0) \
		+ track.track_curve.right_at(100.0) * 40.0
	session.avancer(_joueur(), dehors, 1.0 / 60.0)

	assert_eq(karts[0].motor.speed, 0.0,
		"respawn_at remet le moteur à neuf : sans lui le kart tombe sans fin")


func test_le_chrono_s_arrete_a_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	var fige := _joueur().timer.current
	for i in 30:
		session.avancer(_joueur(), track.track_curve.position_at(10.0), 1.0 / 60.0)
	assert_almost_eq(_joueur().timer.current, fige, 0.0001,
		"le chrono ne tourne plus une fois la course finie")


func test_chaque_concurrent_a_son_propre_etat() -> void:
	_monter(3)
	var L := track.track_curve.length

	# Seul le deuxième roule.
	for i in 40:
		session.avancer(session.entries[1], track.track_curve.position_at(float(i) * 0.5), 1.0 / 60.0)

	assert_gt(session.entries[1].progress.total, 5.0, "celui qui roule avance")
	assert_almost_eq(session.entries[0].progress.total, 0.0, 0.001,
		"et les autres restent où ils sont")
	assert_almost_eq(session.entries[2].timer.current, 0.0, 0.001,
		"un chrono par concurrent, pas un pour tous")


func test_la_course_finit_pour_chacun_separement() -> void:
	_monter(2)
	session.lap_count = 1
	var L := track.track_curve.length
	var d := 0.0
	while d < L + 0.3:
		d = minf(d + 0.5, L + 0.3)
		session.avancer(session.entries[0], track.track_curve.position_at(d), 1.0 / 60.0)

	assert_true(session.entries[0].finished, "celui qui a bouclé a fini")
	assert_false(session.entries[1].finished, "celui qui n'a pas bouclé court toujours")
