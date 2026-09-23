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


func test_le_frein_arrete_le_kart_puis_engage_la_marche_arriere() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	cmd.throttle = 0.0
	cmd.brake = 1.0
	_run(0.85)
	assert_almost_eq(motor.speed, 0.0, 0.5, "le frein doit d'abord immobiliser le kart")
	_run(3.0)
	assert_almost_eq(motor.speed, -stats.max_reverse_speed, 0.1,
		"maintenu, il engage la marche arrière jusqu'à sa vitesse maximale")


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
	cmd.steer = 0.5          # contre-braquage partiel, sous le seuil d'annulation
	_run(0.5)
	assert_eq(motor.drift_dir, -1, "le sens ne change pas en cours de glisse")


func test_sans_braquage_ce_n_est_qu_un_saut() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.drift = true
	motor.step(cmd, 1.0 / 60.0)
	assert_eq(motor.state, KartMotor.State.HOP, "un appui fait toujours sauter, comme dans Mario Kart")
	_run(0.5)
	assert_eq(motor.state, KartMotor.State.GRIP, "sans direction à l'atterrissage, pas de glisse")


func test_le_cote_se_choisit_pendant_le_saut() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.drift = true
	motor.step(cmd, 1.0 / 60.0)
	cmd.steer = -1.0          # on braque une fois en l'air
	_run(stats.hop_duration + 0.1)
	assert_eq(motor.state, KartMotor.State.DRIFT)
	assert_eq(motor.drift_dir, -1, "le braquage pendant le saut décide du côté")


func test_bouton_tenu_sans_braquer_le_kart_ne_sautille_pas() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.drift = true
	var sauts := 0
	var avant := motor.state
	for i in 120:
		motor.step(cmd, 1.0 / 60.0)
		if motor.state == KartMotor.State.HOP and avant != KartMotor.State.HOP:
			sauts += 1
		avant = motor.state
	assert_eq(sauts, 1, "un seul saut par appui")


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
	# Le contre-braquage ne casse plus la glisse : toute la plage compte.
	for braquage in [-1.0, -0.7, -0.3, 0.0, 0.5, 1.0]:
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


func test_le_palier_se_deduit_du_temps_de_glisse() -> void:
	assert_eq(motor.tier_for_charge(0.0), 0)
	assert_eq(motor.tier_for_charge(0.5), 0, "sous le premier seuil, aucune charge")
	assert_eq(motor.tier_for_charge(0.7), 1)
	assert_eq(motor.tier_for_charge(1.6), 2)
	assert_eq(motor.tier_for_charge(3.0), 3)


func test_relacher_au_palier_2_declenche_un_turbo_de_palier_2() -> void:
	_enter_drift(1)
	motor.drift_charge = stats.drift_tiers[1] + 0.1
	cmd.drift = false
	motor.step(cmd, 1.0 / 60.0)
	assert_almost_eq(motor.boost_timer, stats.boost_durations[1], 0.05)
	assert_eq(motor.state, KartMotor.State.GRIP, "relâcher rend l'adhérence")


func test_relacher_trop_tot_ne_donne_aucun_turbo() -> void:
	_enter_drift(1)
	motor.drift_charge = 0.0
	cmd.drift = false
	motor.step(cmd, 1.0 / 60.0)
	assert_eq(motor.boost_timer, 0.0, "sous le premier seuil, pas de récompense")


func test_le_turbo_pousse_au_dela_de_la_vitesse_max() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	motor.boost_timer = 1.0
	motor.step(cmd, 1.0 / 60.0)
	assert_gt(motor.speed, stats.max_speed,
		"le turbo doit franchir le plafond normal, sinon il ne se sent pas")


func test_le_turbo_s_epuise_et_la_vitesse_redescend() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	motor.boost_timer = 0.3
	_run(3.0)
	assert_eq(motor.boost_timer, 0.0)
	assert_almost_eq(motor.speed, stats.max_speed, 0.2,
		"une fois le turbo fini, la vitesse revient au plafond normal")


func test_on_peut_encore_deraper_pendant_un_turbo() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	motor.boost_timer = 2.0
	cmd.steer = 1.0
	cmd.drift = true
	_run(stats.hop_duration + 0.2)
	assert_eq(motor.state, KartMotor.State.DRIFT,
		"le turbo est un modificateur, il ne doit pas bloquer le dérapage")


func test_le_derapage_a_gauche_est_le_miroir_du_droit() -> void:
	_enter_drift(-1)
	var depart := motor.velocity_dir
	_run(0.5)
	assert_lt(motor.velocity_dir, depart,
		"une glisse à gauche courbe la trajectoire à gauche")
	assert_almost_eq(motor.heading, motor.velocity_dir - motor.drift_angle, 0.001,
		"à gauche, la caisse se décale du côté opposé")


func test_le_contre_braquage_elargit_la_glisse_sans_la_casser() -> void:
	_enter_drift(1)
	cmd.steer = -1.0
	var depart := motor.velocity_dir
	_run(0.5)
	assert_eq(motor.state, KartMotor.State.DRIFT, "contre-braquer élargit, comme dans Mario Kart")
	assert_gt(motor.velocity_dir, depart, "la glisse tourne toujours du même côté, plus large")


func test_serrer_le_virage_charge_plus_vite() -> void:
	_enter_drift(1)
	cmd.steer = 1.0
	motor.drift_charge = 0.0
	_run(0.5)
	var serre := motor.drift_charge
	cmd.steer = -1.0
	motor.drift_charge = 0.0
	_run(0.5)
	assert_gt(serre, motor.drift_charge * 1.5, "vers l'intérieur, le mini-turbo se charge nettement plus vite")


func test_chaque_palier_franchi_est_annonce() -> void:
	watch_signals(motor)
	_enter_drift(1)
	cmd.steer = 1.0
	_run(stats.drift_tiers[2] + 0.2)
	assert_signal_emit_count(motor, "palier_atteint", 3, "un signal par palier, pas un par image")
	cmd.drift = false
	motor.step(cmd, 1.0 / 60.0)
	assert_signal_emitted_with_parameters(motor, "mini_turbo", [3])


func test_tomber_sous_la_vitesse_minimale_annule_le_derapage() -> void:
	_enter_drift(1)
	cmd.throttle = 0.0
	cmd.brake = 1.0
	_run(3.0)
	assert_eq(motor.state, KartMotor.State.GRIP)
	assert_eq(motor.boost_timer, 0.0, "une glisse cassée par la vitesse ne rapporte rien non plus")


func test_le_hors_piste_plafonne_la_vitesse() -> void:
	motor.on_offroad = true
	cmd.throttle = 1.0
	_run(20.0)
	assert_almost_eq(motor.speed, stats.max_speed * stats.offroad_speed_multiplier, 0.1)


func test_revenir_sur_la_piste_rend_la_vitesse() -> void:
	motor.on_offroad = true
	cmd.throttle = 1.0
	_run(20.0)
	motor.on_offroad = false
	_run(10.0)
	assert_almost_eq(motor.speed, stats.max_speed, 0.1)


func test_le_turbo_efface_la_penalite_hors_piste() -> void:
	motor.on_offroad = true
	cmd.throttle = 1.0
	_run(10.0)
	motor.boost_timer = 1.0
	motor.step(cmd, 1.0 / 60.0)
	assert_gt(motor.speed, stats.max_speed,
		"foncer dans l'herbe sous turbo doit rester payant")


func test_un_palier_sans_duree_de_turbo_n_en_est_pas_un() -> void:
	stats.drift_tiers = PackedFloat32Array([0.6, 1.5, 2.6, 4.0])
	assert_eq(motor.tier_for_charge(5.0), 3,
		"un palier sans durée associée ne doit pas être atteignable")


func test_une_glisse_cassee_exige_de_relacher_avant_d_en_relancer_une() -> void:
	_enter_drift(1)
	# Un mur pris de face casse la glisse.
	var devant := Vector3(sin(motor.velocity_dir), 0.0, -cos(motor.velocity_dir))
	motor.heurter_mur(-devant)
	_run(0.5)
	assert_eq(motor.state, KartMotor.State.GRIP,
		"bouton toujours tenu : la glisse cassée ne se relance pas")
	cmd.drift = false
	_run(0.1)
	cmd.steer = 1.0
	cmd.drift = true
	_run(stats.hop_duration + 0.1)
	assert_eq(motor.state, KartMotor.State.DRIFT,
		"après avoir relâché, on peut en relancer une")


func test_tenir_le_bouton_avant_d_etre_assez_rapide_n_empeche_pas_la_glisse() -> void:
	cmd.drift = true          # tenu dès le départ, avant d'avoir la vitesse
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = 1.0           # on braque une fois lancé, sans jamais relâcher
	_run(stats.hop_duration + 0.2)
	assert_eq(motor.state, KartMotor.State.DRIFT,
		"tenir le bouton en attendant d'être assez rapide doit fonctionner")


func test_deraper_vers_l_interieur_tourne_plus_court_qu_en_adherence() -> void:
	_enter_drift(1)
	cmd.steer = 1.0
	_run(0.5)
	var avant := motor.velocity_dir
	_run(1.0)
	var lacet_glisse := motor.velocity_dir - avant

	# Même vitesse, même durée, mais en adhérence.
	var grip := KartMotor.new(stats)
	var c := KartCommand.new()
	c.throttle = 1.0
	for i in 300:
		grip.step(c, 1.0 / 60.0)
	c.steer = 1.0
	var avant_grip := grip.velocity_dir
	for i in 60:
		grip.step(c, 1.0 / 60.0)
	var lacet_grip := grip.velocity_dir - avant_grip

	assert_gt(lacet_glisse, lacet_grip,
		"déraper vers l'intérieur doit tourner plus court que rester en adhérence")


func test_un_petit_turbo_ne_raccourcit_pas_un_grand_deja_en_cours() -> void:
	_enter_drift(1)
	motor.boost_timer = stats.boost_durations[2]      # gros turbo en cours
	motor.drift_charge = stats.drift_tiers[0] + 0.01  # glisse chargée au palier 1
	cmd.drift = false
	motor.step(cmd, 1.0 / 60.0)
	assert_gt(motor.boost_timer, stats.boost_durations[0],
		"enchaîner une petite glisse ne doit pas amputer un turbo plus long en cours")
	assert_lte(motor.boost_timer, stats.boost_durations[2],
		"et il ne doit pas non plus s'accumuler au-delà du palier le plus long")


func test_on_ne_derape_pas_en_marche_arriere() -> void:
	cmd.brake = 1.0
	_run(3.0)
	assert_lt(motor.speed, 0.0, "le kart recule")
	cmd.steer = 1.0
	cmd.drift = true
	_run(0.5)
	assert_eq(motor.state, KartMotor.State.GRIP, "pas de glisse en marche arrière")


func test_les_gaz_repassent_de_la_marche_arriere_a_l_avant() -> void:
	cmd.brake = 1.0
	_run(3.0)
	assert_lt(motor.speed, 0.0)
	cmd.brake = 0.0
	cmd.throttle = 1.0
	_run(5.0)
	assert_gt(motor.speed, 0.0, "les gaz doivent reprendre la main sur la marche arrière")


func test_on_dirige_encore_en_marche_arriere() -> void:
	cmd.brake = 1.0
	_run(3.0)
	var depart := motor.velocity_dir
	cmd.steer = 1.0
	_run(1.0)
	assert_gt(motor.velocity_dir, depart, "le braquage garde de l'autorité en marche arrière")


func test_reset_remet_le_moteur_a_neuf() -> void:
	_enter_drift(1)
	motor.boost_timer = 1.0
	motor.on_offroad = true

	motor.reset(1.5)

	assert_eq(motor.state, KartMotor.State.GRIP)
	assert_eq(motor.speed, 0.0)
	assert_eq(motor.boost_timer, 0.0)
	assert_eq(motor.drift_dir, 0)
	assert_eq(motor.drift_charge, 0.0)
	assert_false(motor.on_offroad, "on repart sur la piste")
	assert_almost_eq(motor.velocity_dir, 1.5, 0.001, "le cap demandé est appliqué")
	assert_almost_eq(motor.heading, 1.5, 0.001)


## Rejoue la même séquence de pilotage à trois pas de temps différents et
## renvoie l'état final. Un moteur correctement écrit doit converger vers
## le même résultat, à la précision d'intégration près.
func _simuler(pas: float) -> Dictionary:
	var m := KartMotor.new(KartStats.new())
	var c := KartCommand.new()
	c.throttle = 1.0
	var t := 0.0
	while t < 4.0:
		m.step(c, pas)
		t += pas
	c.steer = 1.0
	c.drift = true
	t = 0.0
	while t < 2.0:
		m.step(c, pas)
		t += pas
	return {"speed": m.speed, "dir": m.velocity_dir, "charge": m.drift_charge}


func test_le_moteur_ne_depend_pas_du_pas_de_temps() -> void:
	var lent := _simuler(1.0 / 30.0)
	var normal := _simuler(1.0 / 60.0)
	var rapide := _simuler(1.0 / 120.0)

	for champ in ["speed", "dir", "charge"]:
		assert_almost_eq(lent[champ], normal[champ], 0.15,
			"%s doit être stable entre 30 et 60 Hz" % champ)
		assert_almost_eq(rapide[champ], normal[champ], 0.15,
			"%s doit être stable entre 120 et 60 Hz" % champ)


## Mesuré : le bond montait à 12,5 cm, invisible derrière le kart — on
## croyait que le bouton ne faisait rien.
func test_le_bond_se_voit_et_retombe_a_temps() -> void:
	var v := stats.hop_impulse
	var g := stats.hop_gravity
	assert_almost_eq(v * v / (2.0 * g), stats.hop_height, 0.001, "il monte à sa hauteur")
	assert_gte(stats.hop_height, 0.3, "assez haut pour se voir")
	assert_almost_eq(2.0 * v / g, stats.hop_duration, 0.001,
		"et retombe au moment où la glisse commence")


func test_on_bondit_meme_a_l_arret() -> void:
	motor.speed = 2.0
	cmd.drift = true
	cmd.steer = 1.0
	motor.step(cmd, 1.0 / 60.0)
	assert_eq(motor.state, KartMotor.State.HOP, "comme dans Mario Kart, le bond ne demande pas de vitesse")
	_run(stats.hop_duration + 0.1)
	assert_ne(motor.state, KartMotor.State.DRIFT, "la glisse, elle, en demande")
