extends GutTest

var stats: KartStats
var cmd: KartCommand


func before_each() -> void:
	stats = KartStats.new()
	cmd = KartCommand.new()


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
	cmd.drift = true
	cmd.clear()
	assert_eq(cmd.steer, 0.0)
	assert_eq(cmd.throttle, 0.0)
	assert_false(cmd.drift)
