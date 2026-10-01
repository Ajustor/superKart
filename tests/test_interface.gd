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


# --- Version affichée au menu --------------------------------------------------------

func test_le_menu_affiche_la_version_en_bas_a_gauche() -> void:
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child_autofree(menu)
	var etiquette := menu.get_node_or_null("Version") as Label
	assert_not_null(etiquette)
	assert_eq(etiquette.text, menu.texte_version())
	assert_eq(etiquette.anchor_left, 0.0, "à gauche")
	assert_eq(etiquette.anchor_top, 1.0, "en bas")
	assert_eq(etiquette.mouse_filter, Control.MOUSE_FILTER_IGNORE, "elle ne vole aucun clic")


func test_la_version_vient_du_projet() -> void:
	var avant = ProjectSettings.get_setting("application/config/version", "")
	ProjectSettings.set_setting("application/config/version", "1.2")
	var texte: String = load("res://scripts/ui/main_menu.gd").texte_version()
	ProjectSettings.set_setting("application/config/version", "dev")
	var hors_ci: String = load("res://scripts/ui/main_menu.gd").texte_version()
	ProjectSettings.set_setting("application/config/version", avant)
	assert_eq(texte, "v1.2", "la version inscrite par la CI")
	assert_eq(hors_ci, "dev", "hors de la CI")


# --- Mise à jour --------------------------------------------------------------------------

func test_le_menu_annonce_une_nouvelle_version() -> void:
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child_autofree(menu)
	var bandeau := menu.find_child("MiseAJour", true, false) as Control
	assert_not_null(bandeau)
	assert_false(bandeau.visible, "rien à dire quand on est à jour, ou en version de développement")
	ProjectSettings.set_setting("application/config/version", "1.2")
	MiseAJour.lire_manifeste({version = "1.3"})
	assert_true(bandeau.visible, "une version plus récente s'annonce sur l'accueil")
	var texte := (bandeau.find_children("*", "Label", true, false)[0] as Label).text
	assert_string_contains(texte, "1.3")
	MiseAJour.lire_manifeste({version = "1.2"})
	assert_false(bandeau.visible)
	ProjectSettings.set_setting("application/config/version", "dev")
	MiseAJour.lire_manifeste({})
