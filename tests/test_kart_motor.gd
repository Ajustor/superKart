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


func test_braquer_a_droite_fait_tourner_le_cap_a_droite() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	var depart := motor.velocity_dir
	cmd.steer = 1.0
	_run(1.0)
	assert_gt(motor.velocity_dir, depart, "braquer à droite doit augmenter le yaw")


func test_a_l_arret_le_kart_ne_tourne_pas() -> void:
	cmd.steer = 1.0
	_run(1.0)
	assert_almost_eq(motor.velocity_dir, 0.0, 0.001,
		"un kart immobile ne doit pas pouvoir pivoter sur place")


func test_en_adherence_la_caisse_suit_le_vecteur_vitesse() -> void:
	cmd.throttle = 1.0
	cmd.steer = 1.0
	_run(3.0)
	assert_almost_eq(motor.heading, motor.velocity_dir, 0.001,
		"hors dérapage, caisse et trajectoire sont alignées")


func test_le_frein_est_prioritaire_sur_les_gaz() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	var lancee := motor.speed
	cmd.brake = 1.0          # les deux enfoncés en même temps
	_run(0.5)
	assert_lt(motor.speed, lancee,
		"frein et gaz ensemble : le frein doit gagner, pas se mélanger aux gaz")


func test_le_bouton_de_derapage_declenche_un_saut() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = 1.0
	cmd.drift = true
	motor.step(cmd, 1.0 / 60.0)
	assert_eq(motor.state, KartMotor.State.HOP, "le dérapage commence par un saut")


func test_le_saut_debouche_sur_le_derapage() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = 1.0
	cmd.drift = true
	_run(stats.hop_duration + 0.1)
	assert_eq(motor.state, KartMotor.State.DRIFT, "après le saut, le kart glisse")


func test_le_sens_de_glisse_est_verrouille_a_l_entree() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = -1.0
	cmd.drift = true
	_run(stats.hop_duration + 0.1)
	assert_eq(motor.drift_dir, -1, "braquer à gauche verrouille une glisse à gauche")
	cmd.steer = 1.0
	_run(0.5)
	assert_eq(motor.drift_dir, -1, "le sens ne change pas en cours de glisse")


func test_pas_de_derapage_sans_braquage() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.drift = true
	_run(0.5)
	assert_eq(motor.state, KartMotor.State.GRIP, "le dérapage exige un braquage")


func test_pas_de_derapage_sous_la_vitesse_minimale() -> void:
	cmd.steer = 1.0
	cmd.drift = true
	_run(0.5)
	assert_eq(motor.state, KartMotor.State.GRIP, "trop lent pour déraper")


func test_relacher_le_bouton_pendant_le_saut_annule_le_derapage() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = 1.0
	cmd.drift = true
	_run(stats.hop_duration * 0.5)
	cmd.drift = false
	_run(stats.hop_duration)
	assert_eq(motor.state, KartMotor.State.GRIP)


## Amène le moteur en dérapage établi, dans le sens donné.
func _enter_drift(direction: int) -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = float(direction)
	cmd.drift = true
	_run(stats.hop_duration + 0.5)


func test_en_derapage_la_caisse_se_decale_du_vecteur_vitesse() -> void:
	_enter_drift(1)
	var ecart := absf(motor.heading - motor.velocity_dir)
	assert_gt(ecart, deg_to_rad(stats.drift_angle_min_deg) * 0.5,
		"la caisse doit pointer nettement à côté de la trajectoire")


func test_l_angle_de_glisse_reste_dans_la_fourchette() -> void:
	_enter_drift(1)
	# On reste au-dessus de -0.8 : au-delà, le contre-braquage annule la glisse
	# et l'angle retombe à zéro (cf. Task 8).
	for braquage in [-0.7, -0.3, 0.0, 0.5, 1.0]:
		cmd.steer = braquage
		_run(0.5)
		var degres := rad_to_deg(motor.drift_angle)
		assert_between(degres, stats.drift_angle_min_deg - 0.5, stats.drift_angle_max_deg + 0.5,
			"angle hors fourchette pour un braquage de %f" % braquage)


func test_braquer_vers_l_interieur_resserre_la_glisse() -> void:
	_enter_drift(1)
	cmd.steer = 1.0
	_run(1.0)
	var serre := motor.drift_angle
	cmd.steer = 0.0
	_run(1.0)
	assert_gt(motor.drift_angle, serre,
		"relâcher le braquage vers l'intérieur ouvre l'angle de glisse")


func test_le_derapage_fait_tourner_la_trajectoire() -> void:
	_enter_drift(1)
	var depart := motor.velocity_dir
	_run(0.5)
	assert_gt(motor.velocity_dir, depart, "une glisse à droite courbe la trajectoire à droite")


func test_deraper_ne_coute_presque_pas_de_vitesse() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	var lancee := motor.speed
	cmd.steer = 1.0
	cmd.drift = true
	_run(2.0)
	assert_gt(motor.speed, lancee * 0.9,
		"le dérapage doit rester rentable, sinon le joueur l'évite")


func test_la_charge_demarre_a_zero_a_l_atterrissage() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = 1.0
	cmd.drift = true
	_run(stats.hop_duration + 1.0 / 60.0)
	assert_lt(motor.drift_charge, 0.05,
		"la charge part de zéro : le temps passé en saut ne compte pas")
