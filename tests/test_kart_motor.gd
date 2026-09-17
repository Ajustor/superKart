extends GutTest

var stats: KartStats
var cmd: KartCommand
var motor: KartMotor


func before_each() -> void:
	stats = KartStats.new()
	cmd = KartCommand.new()
	motor = KartMotor.new(stats)


func test_les_paliers_et_les_durees_de_turbo_vont_par_paires() -> void:
	assert_eq(stats.drift_tiers.size(), stats.boost_durations.size(),
		"chaque palier de charge doit avoir une durée de turbo correspondante")


func test_les_paliers_sont_strictement_croissants() -> void:
	for i in range(1, stats.drift_tiers.size()):
		assert_gt(stats.drift_tiers[i], stats.drift_tiers[i - 1],
			"le palier %d doit demander plus de charge que le précédent" % i)


func test_une_commande_effacee_est_neutre() -> void:
	cmd.steer = 1.0
	cmd.throttle = 1.0
	cmd.brake = 1.0
	cmd.drift = true
	cmd.use_item = true
	cmd.clear()
	assert_eq(cmd.steer, 0.0)
	assert_eq(cmd.throttle, 0.0)
	assert_eq(cmd.brake, 0.0)
	assert_false(cmd.drift)
	assert_false(cmd.use_item)


## Fait tourner le moteur pendant `seconds` à 60 Hz avec la commande courante.
func _run(seconds: float) -> void:
	var step := 1.0 / 60.0
	var elapsed := 0.0
	while elapsed < seconds:
		motor.step(cmd, step)
		elapsed += step


func test_les_gaz_accelerent_jusqu_a_la_vitesse_max() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	assert_almost_eq(motor.speed, stats.max_speed, 0.1,
		"dix secondes plein gaz doivent atteindre la vitesse maximale")


func test_la_vitesse_ne_depasse_jamais_le_maximum() -> void:
	cmd.throttle = 1.0
	_run(60.0)
	assert_lte(motor.speed, stats.max_speed + 0.001)


func test_relacher_les_gaz_fait_ralentir() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	var lancee := motor.speed
	cmd.throttle = 0.0
	_run(1.0)
	assert_lt(motor.speed, lancee, "sans gaz, la friction doit réduire la vitesse")


func test_le_frein_arrete_le_kart() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	cmd.throttle = 0.0
	cmd.brake = 1.0
	_run(3.0)
	assert_almost_eq(motor.speed, 0.0, 0.01, "trois secondes de frein doivent immobiliser le kart")
