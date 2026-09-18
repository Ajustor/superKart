extends GutTest

var chrono: RaceTimer


func before_each() -> void:
	chrono = RaceTimer.new()


func test_au_depart_tout_est_a_zero() -> void:
	assert_eq(chrono.current, 0.0)
	assert_eq(chrono.best, 0.0)
	assert_false(chrono.has_best, "aucun tour bouclé, aucun record")


func test_le_temps_courant_avance() -> void:
	chrono.advance(1.5)
	chrono.advance(0.5)
	assert_almost_eq(chrono.current, 2.0, 0.001)


func test_boucler_un_tour_fige_le_record_et_repart_a_zero() -> void:
	chrono.advance(42.0)
	chrono.complete_lap()
	assert_true(chrono.has_best)
	assert_almost_eq(chrono.best, 42.0, 0.001)
	assert_eq(chrono.current, 0.0, "le tour suivant repart de zéro")


func test_seul_un_meilleur_temps_remplace_le_record() -> void:
	chrono.advance(42.0)
	chrono.complete_lap()
	chrono.advance(50.0)
	chrono.complete_lap()
	assert_almost_eq(chrono.best, 42.0, 0.001, "un tour plus lent ne bat pas le record")
	chrono.advance(38.0)
	chrono.complete_lap()
	assert_almost_eq(chrono.best, 38.0, 0.001, "un tour plus rapide le bat")


func test_le_formatage_est_lisible() -> void:
	assert_eq(RaceTimer.format(0.0), "0:00.000")
	assert_eq(RaceTimer.format(42.5), "0:42.500")
	assert_eq(RaceTimer.format(83.25), "1:23.250")
