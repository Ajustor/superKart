extends GutTest

## L'écran de chargement, et ce qui le rend utile : les circuits chargés à la
## demande plutôt qu'avec le catalogue.


func test_chaque_fiche_mene_a_sa_scene() -> void:
	for piste in TrackCatalog.PISTES:
		assert_true(ResourceLoader.exists(piste.chemin_scene), "%s : %s" % [piste.id, piste.chemin_scene])
		assert_not_null(piste.scene, piste.id)


## La fiche ne porte plus la scène : lire le catalogue ne charge plus les huit
## circuits dès le menu.
func test_la_fiche_ne_charge_pas_son_circuit() -> void:
	var fiche := load("res://resources/tracks/ruban_celeste_info.tres") as TrackInfo
	var texte := FileAccess.get_file_as_string("res://resources/tracks/ruban_celeste_info.tres")
	assert_false(texte.contains("PackedScene"), "aucune scène en dépendance")
	assert_eq(fiche.chemin_scene, "res://scenes/tracks/ruban_celeste.tscn")


func test_l_ecran_monte_la_course_puis_s_efface_au_depart() -> void:
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.par_id("jardin_champignon"))
	var ecran := EcranChargement.pour_reglage(reglage)
	ecran.changer_de_scene = false
	var attente := Node.new()
	add_child_autofree(attente)
	attente.add_child(ecran)
	assert_eq(ecran.titre, "Clairière Enchantée")
	assert_eq(ecran.layer, 100, "au-dessus du HUD et des commandes")

	await wait_until(func() -> bool: return ecran.course != null, 10.0)
	var course := ecran.course
	assert_not_null(course, "la course est montée")
	var session := course.get_node("Session") as RaceSession
	assert_eq(ecran.get_parent(), course, "l'écran est passé dans la course")
	assert_true(session.attente_depart, "pas de décompte derrière l'écran")

	await wait_until(func() -> bool: return not session.attente_depart, 10.0)
	assert_false(session.attente_depart, "l'écran levé, le décompte peut partir")
	assert_null(course.get_node_or_null("TourDeChauffe"), "le tour de chauffe est fini")
	assert_eq(course.get_viewport().get_camera_3d(), course.get_node("ChaseCamera"),
		"et la caméra de poursuite a repris la main")
	var piste := session.circuit()
	assert_not_null(Musique.deja_composee(piste.musique), "la musique est prête au départ")
	var reste: WeakRef = weakref(ecran)
	await wait_until(func() -> bool: return reste.get_ref() == null, 2.0)
	assert_null(reste.get_ref(), "et l'écran s'en va")
	course.queue_free()


func test_le_sous_titre_dit_ce_qu_on_va_courir() -> void:
	var reglage := RaceSetup.new()
	reglage.classe = Cylindree.Classe.CC100
	assert_eq(_sous_titre(reglage), "100cc · 3 tours")
	reglage.mode = RaceSetup.Mode.CONTRE_LA_MONTRE
	assert_eq(_sous_titre(reglage), "Contre-la-montre")
	reglage.commencer_grand_prix(0)
	assert_string_contains(_sous_titre(reglage), "course 1/4")


func _sous_titre(reglage: RaceSetup) -> String:
	var ecran := EcranChargement.pour_reglage(reglage)
	var texte := ecran.sous_titre
	ecran.free()
	return texte


## Sous l'écran de chargement en réseau : une RaceSync sans course, qui avale
## les paquets encore en route de la course précédente.
func test_la_doublure_de_raceSync_ignore_les_paquets_orphelins() -> void:
	var attente := Node.new()
	var doublure := RaceSync.new()
	attente.add_child(doublure)
	add_child_autofree(attente)
	doublure._karts(PackedFloat32Array([0, 1, 2, 3]))
	doublure._classement([[0, 1, 0, false, 0, 0.0, 0, 0, 0.0]])
	doublure._objets({})
	doublure._effet(0, "choc", 0)
	assert_true(true, "aucune erreur")


func test_la_scene_de_course_ne_charge_aucun_circuit_complet() -> void:
	# Ses dépendances directes : la scène d'un circuit n'en fait pas partie,
	# seule la courbe du circuit minimal.
	for dependance in ResourceLoader.get_dependencies(RaceLauncher.SCENE_COURSE):
		var chemin := dependance.get_slice("::", 2) if dependance.contains("::") else dependance
		assert_false(chemin.begins_with("res://scenes/tracks/"), "race.tscn charge %s" % chemin)


func test_le_tour_de_chauffe_montre_chaque_objet_et_chaque_effet() -> void:
	var course := RaceLauncher.monter(RaceSetup.new())
	add_child_autofree(course)
	await wait_physics_frames(2)
	var tour := TourDeChauffe.lancer(course)
	assert_not_null(tour)
	assert_eq(course.get_viewport().get_camera_3d().get_parent(), tour, "sa caméra filme")
	# Boîte, fausse boîte, banane, trois carapaces, explosion ; aura,
	# étincelles, poussière, flammes.
	assert_gte(tour.get_child_count() - 1, 11)
	var particules := tour.find_children("*", "GPUParticles3D", true, false).size() \
		+ tour.find_children("*", "CPUParticles3D", true, false).size()
	assert_gte(particules, 3, "les particules émettent pour être compilées")
	var reste: WeakRef = weakref(tour)
	await wait_until(func() -> bool: return reste.get_ref() == null, 2.0)
	assert_null(reste.get_ref(), "puis il s'en va")
	assert_eq(course.get_viewport().get_camera_3d(), course.get_node("ChaseCamera"))


## Les particules calculées par la carte graphique (GPUParticles3D) faisaient
## planter certains téléphones (Adreno, en GL Compatibility) dès la course
## derrière le menu : tout ce qui jaillit est calculé par le processeur.
func test_aucune_particule_calculee_par_la_carte_graphique() -> void:
	for chemin in ["res://scenes/kart/kart.tscn", "res://scenes/kart/ai_kart.tscn", "res://scenes/race/race.tscn"]:
		if not ResourceLoader.exists(chemin):
			continue
		var scene: Node = (load(chemin) as PackedScene).instantiate()
		assert_eq(scene.find_children("*", "GPUParticles3D", true, false).size(), 0, chemin)
		scene.free()
	for dossier in ["res://scripts", "res://scenes"]:
		_sans_gpu_particles(dossier)


func _sans_gpu_particles(dossier: String) -> void:
	var dir := DirAccess.open(dossier)
	for sous in dir.get_directories():
		_sans_gpu_particles(dossier.path_join(sous))
	for nom in dir.get_files():
		if nom.ends_with(".tscn") or (nom.ends_with(".gd") and nom != "tour_de_chauffe.gd" and nom != "fantome_course.gd"):
			var texte := FileAccess.get_file_as_string(dossier.path_join(nom))
			assert_false(texte.contains("GPUParticles3D.new") or texte.contains("type=\"GPUParticles3D\""),
				"%s n'utilise pas de GPUParticles3D" % nom)
