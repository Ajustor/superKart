extends GutTest

## Ce qui entoure la course sans en faire partie : le barème, le réglage choisi
## au menu, les options enregistrées, les zones tactiles et le montage de la
## course. Rien ici n'a besoin d'une fenêtre.

const REGLAGES := preload("res://scripts/core/game_settings.gd")
const FICHIER_DE_TEST := "user://test_reglages.cfg"


func after_each() -> void:
	if FileAccess.file_exists(FICHIER_DE_TEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER_DE_TEST))


# --- Barème ------------------------------------------------------------------

func test_le_bareme_recompense_chaque_place_moins_que_la_precedente() -> void:
	for place in range(2, RaceScoring.POINTS.size() + 1):
		assert_lt(RaceScoring.points_pour(place), RaceScoring.points_pour(place - 1))
	assert_eq(RaceScoring.points_pour(1), 15)


func test_une_place_hors_bareme_ne_rapporte_rien() -> void:
	assert_eq(RaceScoring.points_pour(0), 0)
	assert_eq(RaceScoring.points_pour(99), 0)


func test_les_ordinaux() -> void:
	assert_eq(RaceScoring.ordinal(1), "1er")
	assert_eq(RaceScoring.ordinal(2), "2e")
	assert_eq(RaceScoring.ordinal(8), "8e")


# --- Réglage de course -------------------------------------------------------

func test_le_catalogue_propose_au_moins_un_circuit_complet() -> void:
	assert_gt(TrackCatalog.PISTES.size(), 0)
	for piste in TrackCatalog.PISTES:
		assert_ne(piste.id, "", "un circuit sans identifiant n'aurait pas de record")
		assert_ne(piste.nom, "")
		assert_not_null(piste.scene, "le circuit %s n'a pas de scène" % piste.id)


func test_les_identifiants_de_circuit_sont_uniques() -> void:
	var vus := {}
	for piste in TrackCatalog.PISTES:
		assert_false(vus.has(piste.id), "identifiant en double : %s" % piste.id)
		vus[piste.id] = true


func test_un_reglage_neuf_prend_le_premier_circuit() -> void:
	var reglage := RaceSetup.new()
	assert_eq(reglage.piste, TrackCatalog.PISTES[0])
	assert_eq(reglage.tours, TrackCatalog.PISTES[0].tours)


func test_la_case_tiree_au_sort_reste_sur_la_grille() -> void:
	var reglage := RaceSetup.new()
	reglage.case_de_depart = RaceSetup.CASE_ALEATOIRE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var vues := {}
	for i in 200:
		var c := reglage.case_effective(8, rng)
		assert_between(c, 1, 8)
		vues[c] = true
	assert_eq(vues.size(), 8, "toutes les cases finissent par sortir")


func test_la_case_choisie_est_respectee() -> void:
	var reglage := RaceSetup.new()
	reglage.case_de_depart = 3
	assert_eq(reglage.case_effective(8, RandomNumberGenerator.new()), 3)
	reglage.case_de_depart = 12
	assert_eq(reglage.case_effective(8, RandomNumberGenerator.new()), 8)


func test_le_lanceur_monte_la_course_demandee() -> void:
	var reglage := RaceSetup.new()
	reglage.tours = 5
	reglage.case_de_depart = 2
	var course := RaceLauncher.monter(reglage)
	var session := course.get_node("Session") as RaceSession
	assert_eq(session.lap_count, 5)
	assert_eq(session.case_du_joueur, 2)
	assert_eq(session.id_piste, reglage.piste.id)
	assert_not_null(course.get_node_or_null("Track"), "le circuit garde son nom : les chemins y mènent")
	assert_eq(session.noms.size(), session.kart_paths.size(), "un nom par kart")
	course.free()


## Chaque circuit arrive avec ses éléments, et seulement les siens : le
## premier montage déménageait les murs, rampes et trous du circuit par défaut
## de race.tscn dans le circuit choisi.
func test_chaque_circuit_garde_ses_propres_elements() -> void:
	for piste in TrackCatalog.PISTES:
		var reglage := RaceSetup.new()
		reglage.choisir_piste(piste)
		var course := RaceLauncher.monter(reglage)
		var monte := course.get_node("Track")
		var seul := piste.scene.instantiate()
		var noms_montes := monte.get_children().map(func(n: Node) -> String: return n.name)
		var noms_seuls := seul.get_children().map(func(n: Node) -> String: return n.name)
		assert_eq(noms_montes, noms_seuls, "%s : ses éléments, pas ceux d'un autre" % piste.id)
		assert_eq(course.find_children("*", "WorldEnvironment", true, false).size(), 1,
			"%s : un seul ciel" % piste.id)
		assert_eq(course.find_children("*", "DirectionalLight3D", true, false).size(), 1,
			"%s : un seul soleil" % piste.id)
		seul.free()
		course.free()


# --- Réglages enregistrés ----------------------------------------------------

func _reglages() -> Node:
	var r: Node = REGLAGES.new()
	r.chemin = FICHIER_DE_TEST
	return r


func test_les_reglages_survivent_a_un_redemarrage() -> void:
	var avant := _reglages()
	avant.volume_general = 0.35
	avant.volume_effets = 0.6
	avant.volume_musique = 0.25
	avant.son_coupe = true
	avant.tactile = avant.Tactile.JAMAIS
	avant.acceleration_auto = false
	avant.vibrations = false
	avant.mini_carte = false
	avant.afficher_fps = true
	avant.qualite = QualiteGraphique.Niveau.BASSE
	avant.sauver()
	avant.free()

	var apres := _reglages()
	apres.charger()
	assert_almost_eq(apres.volume_general, 0.35, 0.001)
	assert_almost_eq(apres.volume_effets, 0.6, 0.001)
	assert_almost_eq(apres.volume_musique, 0.25, 0.001)
	assert_true(apres.son_coupe)
	assert_eq(apres.tactile, apres.Tactile.JAMAIS)
	assert_false(apres.acceleration_auto)
	assert_false(apres.vibrations)
	assert_false(apres.mini_carte)
	assert_true(apres.afficher_fps)
	assert_eq(apres.qualite, QualiteGraphique.Niveau.BASSE)
	apres.free()


func test_un_fichier_absent_garde_les_valeurs_par_defaut() -> void:
	var r := _reglages()
	r.charger()
	assert_almost_eq(r.volume_general, 0.8, 0.001)
	assert_false(r.son_coupe)
	assert_true(r.mini_carte, "la mini-carte est là par défaut")
	assert_false(r.afficher_fps, "le compteur est caché par défaut")
	r.free()


func test_un_volume_hors_bornes_est_ramene() -> void:
	var fichier := ConfigFile.new()
	fichier.set_value("son", "general", 7.0)
	fichier.set_value("son", "effets", -2.0)
	fichier.save(FICHIER_DE_TEST)
	var r := _reglages()
	r.charger()
	assert_almost_eq(r.volume_general, 1.0, 0.001)
	assert_almost_eq(r.volume_effets, 0.0, 0.001)
	r.free()


func test_le_silence_reste_un_nombre() -> void:
	assert_eq(REGLAGES.volume_en_db(0.0), -80.0, "linear_to_db(0) vaut -inf")
	assert_almost_eq(REGLAGES.volume_en_db(1.0), 0.0, 0.001)


func test_seul_un_meilleur_temps_devient_record() -> void:
	var r := _reglages()
	assert_lt(r.record("x", 3), 0.0, "pas de record au départ")
	assert_true(r.proposer_record("x", 3, 90.0))
	assert_false(r.proposer_record("x", 3, 95.0), "plus lent : pas un record")
	assert_true(r.proposer_record("x", 3, 80.0))
	assert_almost_eq(r.record("x", 3), 80.0, 0.001)
	assert_lt(r.record("x", 5), 0.0, "un record en trois tours ne vaut pas pour cinq")
	r.free()

	var relu := _reglages()
	relu.charger()
	assert_almost_eq(relu.record("x", 3), 80.0, 0.001, "le record est enregistré")
	relu.free()


# --- Commandes tactiles ------------------------------------------------------

const ECRAN := Vector2(1152, 648)


func test_chaque_bouton_repond_en_son_centre() -> void:
	for b in TouchControls.boutons(ECRAN):
		assert_eq(TouchControls.action_au_point(b.centre, ECRAN), b.action,
			"le centre du bouton %s doit le déclencher" % b.action)


func test_les_boutons_tiennent_dans_l_ecran() -> void:
	var cadre := Rect2(Vector2.ZERO, ECRAN)
	for b in TouchControls.boutons(ECRAN):
		assert_true(cadre.has_point(b.centre - Vector2(b.rayon, b.rayon)) \
			and cadre.has_point(b.centre + Vector2(b.rayon, b.rayon)),
			"le bouton %s déborde de l'écran" % b.action)


func test_la_croix_couvre_tout_le_bas_gauche() -> void:
	assert_eq(TouchControls.action_au_point(Vector2(10, ECRAN.y - 10), ECRAN), &"steer_left")
	assert_eq(TouchControls.action_au_point(Vector2(ECRAN.x * 0.4, ECRAN.y - 10), ECRAN), &"steer_right")


func test_le_haut_de_l_ecran_est_libre() -> void:
	assert_eq(TouchControls.action_au_point(Vector2(ECRAN.x * 0.5, 40), ECRAN), &"",
		"le milieu de l'écran ne doit rien déclencher : c'est la route")


func test_les_boutons_ne_se_chevauchent_pas() -> void:
	var liste := TouchControls.boutons(ECRAN)
	for i in liste.size():
		for j in range(i + 1, liste.size()):
			var d: float = liste[i].centre.distance_to(liste[j].centre)
			assert_gt(d, liste[i].rayon + liste[j].rayon,
				"%s et %s se chevauchent" % [liste[i].action, liste[j].action])
