extends GutTest

## La course derrière le menu : huit IA, sans écran de course ni son, et
## jamais quand il ne faut pas.


func test_elle_se_monte_sans_interface_ni_son() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var course := CourseDeFond.monter(rng)
	add_child_autofree(course)
	assert_null(course.get_node_or_null("HUD"), "pas d'écran de course")
	assert_null(course.get_node_or_null("RaceSounds"))
	assert_eq(course.find_children("*", "AudioStreamPlayer", true, false).size(), 0, "pas de moteurs")
	var session := course.get_node("Session") as RaceSession
	assert_eq(session.duree_decompte, 0.0, "pas de décompte")
	assert_eq(session.lap_count, CourseDeFond.TOURS)


func test_tous_les_karts_sont_pilotes_par_l_ia() -> void:
	var fond := CourseDeFond.new()
	add_child_autofree(fond)
	await wait_physics_frames(4)
	assert_not_null(fond.session)
	for entree in fond.session.entries:
		assert_true(entree.kart.pilote() is AIInput)


func test_la_camera_passe_d_un_kart_a_l_autre() -> void:
	var fond := CourseDeFond.new()
	add_child_autofree(fond)
	await wait_physics_frames(4)
	var autre := fond.session.entries[3].kart
	fond._couper_sur(autre)
	assert_eq(fond.camera._kart, autre)


func test_pas_sans_ecran_ni_en_qualite_basse() -> void:
	assert_false(CourseDeFond.possible(), "les tests tournent sans écran")
	var avant := GameSettings.qualite
	GameSettings.qualite = QualiteGraphique.Niveau.BASSE
	assert_false(CourseDeFond.possible())
	GameSettings.qualite = avant
