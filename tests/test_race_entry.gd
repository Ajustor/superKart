extends GutTest

## RaceEntry n'est qu'un sac d'état, mais un sac dont les valeurs initiales
## comptent : une place à zéro ou une dernière position en piste à zéro pour un
## kart parti du fond de grille enverrait ce kart à la ligne de départ à sa
## première sortie de route.


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


func test_une_entree_demarre_a_sa_place_de_grille() -> void:
	var piste := TrackCurve.new(_anneau(), 9.0)
	var kart := Kart.new()
	kart.stats = KartStats.new()
	kart.motor = KartMotor.new(kart.stats)

	var entree := RaceEntry.new(kart, piste, 300.0)

	assert_eq(entree.kart, kart)
	assert_almost_eq(entree.progress.distance, 300.0, 0.001,
		"la progression part de la case de grille, pas de la ligne")
	assert_almost_eq(entree.progress.total, 0.0, 0.001,
		"mais la distance parcourue part de zéro pour tout le monde")
	assert_almost_eq(entree.derniere_en_piste, 300.0, 0.001,
		"une sortie de route au premier virage ne doit pas renvoyer à la ligne")
	assert_eq(entree.tours_comptes, 0)
	assert_eq(entree.position, 0, "la place n'a pas de sens avant le premier classement")
	assert_false(entree.finished)
	assert_false(entree.timer.has_best)

	kart.free()


func test_deux_entrees_ne_partagent_pas_leur_chrono() -> void:
	var piste := TrackCurve.new(_anneau(), 9.0)
	var un := Kart.new()
	un.stats = KartStats.new()
	un.motor = KartMotor.new(un.stats)
	var deux := Kart.new()
	deux.stats = KartStats.new()
	deux.motor = KartMotor.new(deux.stats)

	var a := RaceEntry.new(un, piste, 0.0)
	var b := RaceEntry.new(deux, piste, 10.0)
	a.timer.advance(3.0)

	assert_almost_eq(a.timer.current, 3.0, 0.001)
	assert_almost_eq(b.timer.current, 0.0, 0.001,
		"un chrono partagé entre concurrents donnerait huit fois le même temps")

	un.free()
	deux.free()
