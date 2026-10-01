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


# --- Musique -------------------------------------------------------------------------

func test_chaque_style_compose_une_boucle_propre() -> void:
	for style in Musique.Style.values():
		var flux := Musique.composer(style)
		assert_eq(flux.loop_mode, AudioStreamWAV.LOOP_FORWARD, "elle boucle")
		var secondes := flux.data.size() / 2.0 / Musique.FREQUENCE
		assert_between(secondes, 8.0, 25.0, "style %d : huit mesures" % style)
		assert_same(Musique.composer(style), flux, "composée une seule fois")
		var crete := 0
		for i in range(0, flux.data.size(), 64):
			crete = maxi(crete, absi(flux.data.decode_s16(i)))
		assert_between(crete, 5000, 32000, "style %d : audible, sans écrêter" % style)


func test_chaque_circuit_a_son_air() -> void:
	var styles := {}
	for info in TrackCatalog.PISTES:
		var piste: Track = info.scene.instantiate()
		styles[piste.musique] = true
		piste.free()
	assert_eq(styles.size(), TrackCatalog.PISTES.size())


func test_la_course_joue_la_musique_du_circuit() -> void:
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.par_id("forteresse_lave"))
	var course := RaceLauncher.monter(reglage)
	add_child_autofree(course)
	await wait_process_frames(3)
	var musique: RaceMusic = course.find_children("*", "RaceMusic", true, false)[0]
	var session: RaceSession = course.get_node("Session")
	while not session.en_course:
		session.avancer_decompte(0.5)
	await wait_process_frames(2)
	await wait_until(func() -> bool: return musique._lecteur.playing, 5.0)
	assert_true(musique._lecteur.playing, "elle part au vert")
	assert_same(musique._lecteur.stream, Musique.deja_composee(Musique.Style.FORTERESSE))


func test_les_finitions_suivent_la_qualite() -> void:
	var racine := Node.new()
	var piste: Track = load("res://scenes/tracks/canyon_venteux.tscn").instantiate()
	racine.add_child(piste)
	var effets := EffetsEcran.new()
	racine.add_child(effets)
	add_child_autofree(racine)
	var route := piste.get_node(Track.NOM_MAILLAGE) as MeshInstance3D
	var bitume := route.mesh.surface_get_material(0) as StandardMaterial3D
	QualiteGraphique.appliquer_a(racine, QualiteGraphique.Niveau.HAUTE)
	assert_true(bitume.uv1_triplanar, "le grain du bitume en haute")
	assert_true(effets.visible)
	QualiteGraphique.appliquer_a(racine, QualiteGraphique.Niveau.MOYENNE)
	assert_false(bitume.uv1_triplanar, "pas de grain sur téléphone")
	assert_null(bitume.albedo_texture)
	assert_true(effets.visible)
	QualiteGraphique.appliquer_a(racine, QualiteGraphique.Niveau.BASSE)
	assert_false(effets.visible, "en basse, pas d'effets d'écran")


func test_l_etalonnage_suit_la_qualite() -> void:
	var env := Environment.new()
	QualiteGraphique.etalonner(env, QualiteGraphique.Niveau.HAUTE)
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_FILMIC)
	assert_true(env.adjustment_enabled)
	QualiteGraphique.etalonner(env, QualiteGraphique.Niveau.MOYENNE)
	assert_false(env.adjustment_enabled, "une passe de moins sur téléphone")
	QualiteGraphique.etalonner(env, QualiteGraphique.Niveau.BASSE)
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_LINEAR)


func test_chaque_route_a_son_dessous() -> void:
	var piste: Track = load("res://scenes/tracks/grand_huit.tscn").instantiate()
	add_child_autofree(piste)
	var tablier := piste.get_node_or_null(Track.NOM_TABLIER) as MeshInstance3D
	assert_not_null(tablier, "une route vue d'en dessous ne doit pas être invisible")
	assert_eq(tablier.find_children("*", "CollisionObject3D").size(), 0, "sans collision")
