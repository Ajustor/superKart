extends GutTest

## Ce que l'interface montre pendant et après la course : la flèche de place,
## les temps de chaque tour, les commandes telles qu'elles sont réglées.


func test_le_chrono_garde_le_temps_de_chaque_tour() -> void:
	var t := RaceTimer.new()
	for duree in [31.2, 30.1, 30.8]:
		t.advance(duree)
		t.complete_lap()
	assert_eq(t.tours.size(), 3)
	assert_almost_eq(t.tours[1], 30.1, 0.001)
	assert_almost_eq(t.best, 30.1, 0.001)


func test_le_meilleur_tour_est_etoile() -> void:
	var texte := ResultsScreen.texte_des_tours(PackedFloat32Array([31.2, 30.1, 30.8]))
	assert_eq(texte, "Tours : 0:31.200 · ★ 0:30.100 · 0:30.800")
	assert_eq(ResultsScreen.texte_des_tours(PackedFloat32Array()), "")
	assert_false(ResultsScreen.texte_des_tours(PackedFloat32Array([40.0])).contains("★"),
		"un seul tour : rien à comparer")


func test_chaque_commande_a_au_moins_une_touche() -> void:
	for action in AstucesPanel.ACTIONS:
		var texte := AstucesPanel.texte_des_touches(action)
		assert_ne(texte, "—", str(action))
		assert_ne(texte, "", str(action))
	assert_string_contains(AstucesPanel.texte_des_touches(&"drift"), "Espace")


func test_la_fleche_dit_si_l_on_gagne_ou_perd_une_place() -> void:
	var course := RaceLauncher.monter(RaceSetup.new())
	var session := course.get_node("Session") as RaceSession
	session.duree_decompte = 0.0
	add_child_autofree(course)
	await wait_until(func() -> bool: return session.en_course, 3.0)
	var hud := course.find_children("*", "RaceHUD", true, false)[0] as RaceHUD
	hud._place_vue = 5
	hud._suivre_la_place(4, 0.016)
	assert_true(hud._fleche.visible)
	assert_eq(hud._fleche.text, "▲", "une place gagnée")
	hud._suivre_la_place(6, 0.016)
	assert_eq(hud._fleche.text, "▼", "une place perdue")
	hud._suivre_la_place(6, RaceHUD.DUREE_FLECHE + 0.1)
	assert_false(hud._fleche.visible, "et elle s'efface")


func test_la_camera_d_arrivee_passe_devant_le_kart() -> void:
	assert_eq(ChaseCamera.angle_d_orbite(0.0), 0.0, "au départ, derrière le kart")
	assert_almost_eq(ChaseCamera.angle_d_orbite(ChaseCamera.ORBITE_DEMI_TOUR), PI, 0.001, "puis devant")
	assert_gt(ChaseCamera.angle_d_orbite(ChaseCamera.ORBITE_DEMI_TOUR + 4.0), PI, "et elle continue de tourner")
	assert_gt(ResultsScreen.DELAI, ChaseCamera.ORBITE_DEMI_TOUR, "les résultats attendent la fin du demi-tour")


func test_la_camera_tourne_a_l_arrivee_du_joueur() -> void:
	var course := RaceLauncher.monter(RaceSetup.new())
	var session := course.get_node("Session") as RaceSession
	session.duree_decompte = 0.0
	add_child_autofree(course)
	await wait_until(func() -> bool: return session.en_course, 3.0)
	var camera := course.get_node("ChaseCamera") as ChaseCamera
	assert_lt(camera.orbite, 0.0)
	session.appliquer_arrivee(session.entries[1], 1, 30.0)
	assert_lt(camera.orbite, 0.0, "l'arrivée d'un autre ne change rien")
	session.appliquer_arrivee(session.entries[0], 2, 31.0)
	await wait_physics_frames(5)
	assert_gt(camera.orbite, 0.0)
