extends GutTest

## Les bruitages : les chocs qu'on entend (mur, retombée, autre kart) et les
## couches du moteur (pneus en glisse, herbe, turbo).

var a_liberer: Array[Object] = []


func after_each() -> void:
	for o in a_liberer:
		o.free()
	a_liberer.clear()


func _kart(ou: Vector3, vitesse: float) -> Kart:
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	k.motor.speed = vitesse
	k.position = ou
	a_liberer.append(k)
	return k


func test_un_choc_est_un_son_bref_et_audible() -> void:
	var son := Synth.choc(0.2, 100.0, 0.5)
	assert_eq(son.data.size(), int(0.2 * Synth.FREQUENCE) * 2, "16 bits mono")
	var plus_fort := 0
	for i in range(0, son.data.size(), 2):
		plus_fort = maxi(plus_fort, absi(son.data.decode_s16(i)))
	assert_gt(plus_fort, 3000, "on l'entend")
	var fin := absi(son.data.decode_s16(son.data.size() - 2))
	assert_lt(fin, 1000, "et il s'éteint")


func test_les_notes_sonnent_comme_avant() -> void:
	var son := Synth.notes([[440.0, 0.1], [0.0, 0.05]])
	assert_eq(son.data.size(), (int(0.1 * Synth.FREQUENCE) + int(0.05 * Synth.FREQUENCE)) * 2)


func test_heurter_un_mur_de_face_se_signale_avec_sa_force() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = 20.0
	watch_signals(m)
	# Cap nord (-Z), mur face à nous : sa normale regarde vers +Z.
	m.heurter_mur(Vector3(0, 0, 1))
	assert_signal_emitted(m, "choc_mur")
	var force: float = get_signal_parameters(m, "choc_mur")[0]
	assert_almost_eq(force, 20.0, 0.01)


func test_s_eloigner_d_un_mur_ne_fait_aucun_bruit() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = 20.0
	watch_signals(m)
	m.heurter_mur(Vector3(0, 0, -1))
	assert_signal_not_emitted(m, "choc_mur")


func test_deux_karts_qui_se_rentrent_dedans_le_disent_tous_les_deux() -> void:
	var devant := _kart(Vector3(0, 0, -1.0), 10.0)
	var derriere := _kart(Vector3.ZERO, 20.0)
	watch_signals(devant)
	watch_signals(derriere)
	KartCollisions.resoudre([devant, derriere] as Array[Kart])
	assert_signal_emitted(devant, "bouscule")
	assert_signal_emitted(derriere, "bouscule")
	assert_almost_eq(float(get_signal_parameters(derriere, "bouscule")[0]), 10.0, 0.01)


func test_deux_karts_qui_s_ecartent_se_taisent() -> void:
	var devant := _kart(Vector3(0, 0, -1.0), 20.0)
	var derriere := _kart(Vector3.ZERO, 10.0)
	watch_signals(devant)
	KartCollisions.resoudre([devant, derriere] as Array[Kart])
	assert_signal_not_emitted(devant, "bouscule")


func test_le_volume_du_choc_suit_sa_force() -> void:
	assert_almost_eq(RaceSounds.volume_du_choc(2.0, 2.0, 12.0), RaceSounds.CHOC_MIN, 0.001)
	assert_almost_eq(RaceSounds.volume_du_choc(30.0, 2.0, 12.0), 1.0, 0.001)
	var milieu := RaceSounds.volume_du_choc(7.0, 2.0, 12.0)
	assert_between(milieu, RaceSounds.CHOC_MIN, 1.0)


func test_les_couches_du_moteur() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = m.stats.max_speed
	assert_eq(EngineSound.couches(m, true, m.stats.max_speed), Vector3.ZERO, "sur le bitume, rien")
	m.state = KartMotor.State.DRIFT
	assert_gt(EngineSound.couches(m, true, m.stats.max_speed).x, 0.0, "les pneus crissent")
	assert_eq(EngineSound.couches(m, false, m.stats.max_speed).x, 0.0, "pas en l'air")
	m.state = KartMotor.State.GRIP
	m.on_offroad = true
	assert_gt(EngineSound.couches(m, true, m.stats.max_speed).y, 0.0, "l'herbe gronde")
	m.boost_timer = 1.0
	assert_gt(EngineSound.couches(m, false, m.stats.max_speed).z, 0.0, "le turbo souffle, même en l'air")


func test_une_retombee_de_tremplin_s_entend() -> void:
	var course := RaceLauncher.monter(RaceSetup.new())
	var session := course.get_node("Session") as RaceSession
	session.duree_decompte = 0.0
	add_child_autofree(course)
	await wait_until(func() -> bool: return session.en_course, 3.0)
	var kart := session.entries[0].kart
	# Posé sur la grille un peu au-dessus de la route : il y retombe d'abord.
	await wait_until(func() -> bool: return kart.au_sol, 2.0)
	await wait_physics_frames(2)
	watch_signals(kart)
	assert_true(kart.sauter(7.0))
	await wait_for_signal(kart.atterri, 3.0)
	assert_signal_emitted(kart, "atterri")
	assert_gt(float(get_signal_parameters(kart, "atterri")[0]), Kart.ATTERRISSAGE_AUDIBLE)
