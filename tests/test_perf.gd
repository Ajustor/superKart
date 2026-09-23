extends GutTest

## Le compteur de performances : ce qu'il tire de la durée des images.


func test_soixante_images_de_16_ms_font_60_fps() -> void:
	var m := MesureImages.new()
	for i in 120:
		m.ajouter(1000.0 / 60.0)
	assert_almost_eq(m.images_par_seconde(), 60.0, 0.5)
	assert_almost_eq(m.duree_moyenne(), 16.67, 0.01)
	assert_eq(m.a_coups, 0)


func test_un_gel_se_voit_meme_quand_la_moyenne_est_bonne() -> void:
	var m := MesureImages.new()
	for i in 59:
		m.ajouter(16.0)
	m.ajouter(200.0)
	assert_gt(m.images_par_seconde(), 45.0, "la moyenne reste correcte")
	assert_almost_eq(m.pire(), 200.0, 0.001, "mais la pire image le montre")
	assert_eq(m.a_coups, 1)


func test_la_fenetre_oublie_ce_qui_date_de_plus_d_une_seconde() -> void:
	var m := MesureImages.new()
	m.ajouter(300.0)
	for i in 80:
		m.ajouter(16.0)
	assert_almost_eq(m.pire(), 16.0, 0.001, "le gel d'il y a plus d'une seconde est sorti de la fenêtre")
	assert_eq(m.a_coups, 1, "mais il reste compté")


func test_le_compteur_suit_le_reglage() -> void:
	var avant: bool = GameSettings.afficher_fps
	GameSettings.afficher_fps = true
	GameSettings.changed.emit()
	assert_true(PerfOverlay.visible)
	GameSettings.afficher_fps = false
	GameSettings.changed.emit()
	assert_false(PerfOverlay.visible)
	GameSettings.afficher_fps = avant
	GameSettings.changed.emit()


# --- Qualité graphique -----------------------------------------------------------

func _course(id: String) -> Node:
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.par_id(id))
	var course := RaceLauncher.monter(reglage)
	autofree(course)
	return course


func _lumiere(course: Node) -> DirectionalLight3D:
	return course.find_children("*", "DirectionalLight3D", true, false)[0]


func _env(course: Node) -> Environment:
	return (course.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment


func test_la_qualite_basse_retire_ombres_lueur_et_brouillard() -> void:
	var course := _course("forteresse_lave")
	QualiteGraphique.appliquer_a(course, QualiteGraphique.Niveau.BASSE)
	assert_false(_lumiere(course).shadow_enabled)
	assert_false(_env(course).glow_enabled)
	assert_false(_env(course).fog_enabled)
	assert_almost_eq(QualiteGraphique.echelle_3d(QualiteGraphique.Niveau.BASSE), 0.6, 0.001)


func test_la_qualite_moyenne_garde_la_lueur_mais_pas_les_ombres() -> void:
	var course := _course("ruban_celeste")
	QualiteGraphique.appliquer_a(course, QualiteGraphique.Niveau.MOYENNE)
	assert_false(_lumiere(course).shadow_enabled, "les ombres coûtent une seconde vue de toute la scène")
	assert_true(_env(course).glow_enabled)


func test_revenir_en_haute_rend_ce_que_le_circuit_avait_prevu() -> void:
	var course := _course("ruban_celeste")
	QualiteGraphique.appliquer_a(course, QualiteGraphique.Niveau.BASSE)
	QualiteGraphique.appliquer_a(course, QualiteGraphique.Niveau.HAUTE)
	assert_true(_lumiere(course).shadow_enabled)
	assert_true(_env(course).glow_enabled, "le ruban retrouve sa lueur")
	assert_false(_env(course).fog_enabled, "sans gagner un brouillard qu'il n'avait pas")


func test_en_automatique_un_pc_est_en_haute() -> void:
	assert_eq(QualiteGraphique.effectif(QualiteGraphique.Niveau.AUTO), QualiteGraphique.Niveau.HAUTE,
		"les tests tournent sur un PC ; un téléphone passerait en MOYENNE")
