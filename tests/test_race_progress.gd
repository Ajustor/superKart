extends GutTest

var track: TrackCurve
var progress: RaceProgress


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
	track = TrackCurve.new(_anneau(), 8.0)
	progress = RaceProgress.new(track, 0.0)


## Déplace le kart le long de l'axe par petits pas, comme le ferait un vrai
## tour : la détection de passage de ligne repose sur la continuité.
func _parcourir(de: float, vers: float, pas: float = 5.0) -> void:
	var d := de
	while absf(vers - d) > pas:
		d += pas * signf(vers - d)
		progress.update(track.position_at(d))
	progress.update(track.position_at(vers))


func test_au_depart_on_est_au_tour_zero() -> void:
	progress.update(track.position_at(0.0))
	assert_eq(progress.lap, 0)
	assert_almost_eq(progress.total, 0.0, 1.0)


func test_avancer_augmente_la_distance_cumulee() -> void:
	_parcourir(0.0, 120.0)
	assert_almost_eq(progress.total, 120.0, 2.0)
	assert_eq(progress.lap, 0, "on n'a pas encore bouclé")


func test_boucler_incremente_le_tour() -> void:
	_parcourir(0.0, track.length - 5.0)
	assert_eq(progress.lap, 0)
	_parcourir(track.length - 5.0, track.length + 10.0)
	assert_eq(progress.lap, 1, "franchir la ligne compte un tour")
	assert_almost_eq(progress.total, track.length + 10.0, 3.0)


func test_reculer_decremente_la_distance() -> void:
	_parcourir(0.0, 100.0)
	var avant := progress.total
	_parcourir(100.0, 60.0)
	assert_lt(progress.total, avant, "reculer réduit la progression")


func test_repasser_la_ligne_a_l_envers_annule_le_tour() -> void:
	_parcourir(0.0, track.length - 5.0)
	_parcourir(track.length - 5.0, track.length + 10.0)
	assert_eq(progress.lap, 1)
	_parcourir(10.0, -10.0)
	assert_eq(progress.lap, 0,
		"revenir en arrière par la ligne doit reprendre le tour")


func test_deux_tours_complets() -> void:
	_parcourir(0.0, track.length - 5.0)
	_parcourir(track.length - 5.0, track.length + 10.0)
	_parcourir(track.length + 10.0, 2.0 * track.length - 5.0)
	_parcourir(2.0 * track.length - 5.0, 2.0 * track.length + 10.0)
	assert_eq(progress.lap, 2)


func test_trembler_sur_la_ligne_ne_compte_aucun_tour() -> void:
	progress.update(track.position_at(0.0))
	for i in 50:
		var tremblement := 0.03 if i % 2 == 0 else -0.03
		progress.update(track.position_at(tremblement))
		assert_eq(progress.lap, 0,
			"un kart immobile sur la ligne ne boucle rien")


func test_reculer_avant_le_depart_ne_donne_pas_de_tour_negatif() -> void:
	progress.update(track.position_at(0.0))
	_parcourir(0.0, -30.0)
	assert_eq(progress.lap, 0, "on ne descend pas sous le tour zéro")
	assert_lt(progress.total, 0.0,
		"la distance cumulée, elle, a le droit d'être négative")


func test_naitre_juste_avant_la_ligne_ne_donne_pas_un_tour() -> void:
	# Le kart est posé un millimètre avant la ligne — ce que fait spawn_at dès
	# que la ligne de course est décalée par rapport à l'axe. Avancer de cinq
	# centimètres ne boucle pas un tour de 314 m.
	var p := RaceProgress.new(track, 0.0)
	p.update(track.position_at(track.length - 0.001))
	assert_eq(p.lap, 0, "naître derrière la ligne ne compte pas un tour")
	p.update(track.position_at(0.05))
	assert_eq(p.lap, 0, "franchir la ligne au premier centimètre non plus")


func test_le_vrai_circuit_ne_boucle_pas_au_depart() -> void:
	# Le cas réel, sur la géométrie livrée : l'anneau des autres tests projette
	# trop proprement pour reproduire la couture.
	var courbe: Curve3D = load("res://resources/tracks/track_01_curve.tres")
	var piste := TrackCurve.new(courbe, 9.0)
	var p := RaceProgress.new(piste, 0.0)
	p.update(piste.racing_line_at(0.0) + Vector3.UP * 0.1)
	p.update(piste.racing_line_at(0.5) + Vector3.UP * 0.1)
	assert_eq(p.lap, 0, "un demi-mètre depuis la grille ne boucle pas 768 m")
	assert_almost_eq(p.total, 0.5, 0.2, "et la distance parcourue vaut ce qu'on a roulé")
