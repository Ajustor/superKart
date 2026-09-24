extends GutTest

## Les modes de jeu : les cylindrées, le Grand Prix et ses coupes, le
## contre-la-montre et son fantôme.

const REGLAGES := preload("res://scripts/core/game_settings.gd")
const FICHIER_DE_TEST := "user://test_modes.cfg"
const CLE_FANTOME := "test_fantome@clm"

const NOMS := ["Vous", "Turbo", "Zéphyr", "Piston", "Comète", "Bielle", "Rafale", "Gomme"]


func after_each() -> void:
	for chemin in [FICHIER_DE_TEST, Fantome.chemin(CLE_FANTOME)]:
		if FileAccess.file_exists(chemin):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))


# --- Cylindrées ----------------------------------------------------------------

func test_la_150cc_est_le_reglage_d_origine() -> void:
	var base := KartStats.new()
	var s := Cylindree.stats(base, Cylindree.Classe.CC150, false)
	assert_eq(s.max_speed, base.max_speed)
	assert_eq(s.acceleration, base.acceleration)


func test_chaque_cylindree_va_moins_vite_que_la_suivante() -> void:
	var base := KartStats.new()
	var avant := 0.0
	for classe in [Cylindree.Classe.CC50, Cylindree.Classe.CC100, Cylindree.Classe.CC150]:
		var s := Cylindree.stats(base, classe, false)
		assert_gt(s.max_speed, avant, Cylindree.nom(classe))
		avant = s.max_speed
		assert_eq(s.turn_rate, base.turn_rate, "le braquage ne change pas")


## Mesuré avant : en 50cc, tous les karts de l'IA tombaient dans le gouffre
## de la mine. Une trajectoire balistique de vitesse v·f, d'impulsion i·f et
## de gravité g·f² va exactement aussi loin et aussi haut qu'à la 150cc.
func test_chaque_saut_porte_aussi_loin_dans_toutes_les_cylindrees() -> void:
	var base := KartStats.new()
	var impulsion := 9.0
	var portee_150 := 0.0
	var hauteur_150 := 0.0
	for classe in [Cylindree.Classe.CC150, Cylindree.Classe.CC100, Cylindree.Classe.CC50]:
		var s := Cylindree.stats(base, classe, false)
		var montee := impulsion * s.echelle_des_tremplins
		var vol := 2.0 * montee / s.gravity
		var portee := s.max_speed * vol
		var hauteur := montee * montee / (2.0 * s.gravity)
		if classe == Cylindree.Classe.CC150:
			portee_150 = portee
			hauteur_150 = hauteur
		assert_almost_eq(portee, portee_150, 0.01, "%s : même portée" % Cylindree.nom(classe))
		assert_almost_eq(hauteur, hauteur_150, 0.01, "%s : même hauteur" % Cylindree.nom(classe))


func test_l_ia_laisse_de_la_marge_en_petite_cylindree() -> void:
	var base := KartStats.new()
	var joueur := Cylindree.stats(base, Cylindree.Classe.CC50, false)
	var ia := Cylindree.stats(base, Cylindree.Classe.CC50, true)
	assert_lt(ia.max_speed, joueur.max_speed)


func test_la_cylindree_ne_touche_pas_la_ressource_partagee() -> void:
	var reglage := RaceSetup.new()
	reglage.classe = Cylindree.Classe.CC50
	var course := RaceLauncher.monter(reglage)
	var joueur := course.get_node("Kart") as Kart
	var ia := course.get_node("AIKart1") as Kart
	var origine := load("res://resources/karts/default_kart.tres") as KartStats
	assert_almost_eq(joueur.stats.max_speed, origine.max_speed * Cylindree.VITESSE[0], 0.01)
	assert_lt(ia.stats.max_speed, joueur.stats.max_speed)
	assert_ne(joueur.stats, origine, "une copie, pas la ressource de tous les karts")
	assert_almost_eq(origine.max_speed, 22.0, 0.01)
	course.free()


func test_les_records_se_rangent_par_cylindree_et_par_mode() -> void:
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.PISTES[0])
	reglage.classe = Cylindree.Classe.CC150
	assert_eq(reglage.cle_record(), TrackCatalog.PISTES[0].id, "les records d'avant restent en 150cc")
	reglage.classe = Cylindree.Classe.CC50
	assert_eq(reglage.cle_record(), TrackCatalog.PISTES[0].id + "@50cc")
	reglage.mode = RaceSetup.Mode.CONTRE_LA_MONTRE
	assert_eq(reglage.cle_record(), TrackCatalog.PISTES[0].id + "@clm")
	assert_eq(reglage.classe_effective(), Cylindree.Classe.CC150, "le contre-la-montre se court en 150cc")


# --- Grand Prix ------------------------------------------------------------------

func test_les_coupes_se_partagent_tous_les_circuits() -> void:
	var vus := {}
	for coupe in TrackCatalog.COUPES:
		assert_eq(coupe.pistes.size(), 4, "%s : quatre courses" % coupe.nom)
		for id in coupe.pistes:
			assert_not_null(TrackCatalog.par_id(id), "%s : circuit inconnu %s" % [coupe.nom, id])
			assert_false(vus.has(id), "%s est dans deux coupes" % id)
			vus[id] = true
	assert_eq(vus.size(), TrackCatalog.PISTES.size(), "chaque circuit a sa coupe")


func test_une_coupe_enchaine_ses_quatre_circuits() -> void:
	var gp := GrandPrix.new(0)
	var vus: Array[String] = []
	while not gp.terminee():
		vus.append(gp.piste().id)
		gp.compter(PackedStringArray(NOMS))
	assert_eq(vus, Array(TrackCatalog.COUPES[0].pistes, TYPE_STRING, "", null))
	assert_eq(gp.manche, 4)


func test_les_points_s_additionnent() -> void:
	var gp := GrandPrix.new(0)
	gp.compter(PackedStringArray(NOMS))
	var inverse := NOMS.duplicate()
	inverse.reverse()
	gp.compter(PackedStringArray(inverse))
	assert_eq(gp.points["Vous"], RaceScoring.points_pour(1) + RaceScoring.points_pour(8))
	assert_eq(gp.points["Gomme"], RaceScoring.points_pour(8) + RaceScoring.points_pour(1))


func test_a_egalite_la_derniere_course_departage() -> void:
	var gp := GrandPrix.new(0)
	gp.compter(PackedStringArray(NOMS))
	var inverse := NOMS.duplicate()
	inverse.reverse()
	gp.compter(PackedStringArray(inverse))
	# Vous et Gomme ont autant de points ; Gomme a gagné la dernière.
	var classement := gp.classement()
	assert_lt(classement.find("Gomme"), classement.find("Vous"))
	assert_eq(gp.place_de("Gomme") + 1, gp.place_de("Vous"))


func test_chacun_repart_de_sa_place_d_arrivee() -> void:
	var gp := GrandPrix.new(0)
	assert_eq(gp.cases(PackedStringArray(NOMS)).size(), 0, "première course : le choix du joueur")
	gp.compter(PackedStringArray(NOMS))
	# Deuxième course : le joueur finit sixième, mais il est mieux classé
	# que ça dans la coupe aux points.
	var ordre := PackedStringArray(["Piston", "Turbo", "Zéphyr", "Comète", "Bielle", "Vous", "Rafale", "Gomme"])
	gp.compter(ordre)
	assert_lt(gp.place_de("Vous"), 6, "mieux classé dans la coupe")
	var cases := gp.cases(PackedStringArray(NOMS))
	assert_eq(cases[0], 5, "mais il repart de sa place d'arrivée : sixième case")
	assert_eq(cases[NOMS.find("Piston")], 0, "le vainqueur de la course part en pole")
	var distinctes := {}
	for c in cases:
		distinctes[c] = true
	assert_eq(distinctes.size(), NOMS.size(), "une case chacun")


func test_une_manche_de_coupe_se_monte_sur_son_circuit() -> void:
	var reglage := RaceSetup.new()
	reglage.commencer_grand_prix(1)
	assert_eq(reglage.piste.id, TrackCatalog.COUPES[1].pistes[0])
	reglage.grand_prix.compter(PackedStringArray(NOMS))
	reglage.preparer_manche()
	assert_eq(reglage.piste.id, TrackCatalog.COUPES[1].pistes[1])
	var course := RaceLauncher.monter(reglage)
	var session := course.get_node("Session") as RaceSession
	assert_eq(session.cases_imposees.size(), session.kart_paths.size(), "grille rangée par la coupe")
	course.free()


func _reglages() -> Node:
	var r: Node = REGLAGES.new()
	r.chemin = FICHIER_DE_TEST
	return r


func test_seul_un_meilleur_podium_devient_trophee() -> void:
	var r := _reglages()
	assert_eq(r.trophee(0, Cylindree.Classe.CC100), 0)
	assert_false(r.proposer_trophee(0, Cylindree.Classe.CC100, 4), "hors du podium")
	assert_true(r.proposer_trophee(0, Cylindree.Classe.CC100, 3))
	assert_false(r.proposer_trophee(0, Cylindree.Classe.CC100, 3))
	assert_true(r.proposer_trophee(0, Cylindree.Classe.CC100, 1))
	assert_eq(r.trophee(0, Cylindree.Classe.CC150), 0, "chaque cylindrée a ses trophées")
	r.course.classe = Cylindree.Classe.CC50
	r.sauver()
	r.free()
	var relu := _reglages()
	relu.charger()
	assert_eq(relu.trophee(0, Cylindree.Classe.CC100), 1)
	assert_eq(relu.course.classe, Cylindree.Classe.CC50, "la cylindrée choisie est retenue")
	relu.free()


func test_les_cles_de_record_composees_survivent_a_l_enregistrement() -> void:
	var r := _reglages()
	assert_true(r.proposer_record("circuit_01@clm", 3, 70.0))
	assert_true(r.proposer_record("circuit_01@50cc", 3, 90.0))
	r.free()
	var relu := _reglages()
	relu.charger()
	assert_almost_eq(relu.record("circuit_01@clm", 3), 70.0, 0.001)
	assert_almost_eq(relu.record("circuit_01@50cc", 3), 90.0, 0.001)
	relu.free()


# --- Contre-la-montre ----------------------------------------------------------

func test_le_contre_la_montre_se_court_seul() -> void:
	var reglage := RaceSetup.new()
	reglage.mode = RaceSetup.Mode.CONTRE_LA_MONTRE
	var course := RaceLauncher.monter(reglage)
	var session := course.get_node("Session") as RaceSession
	assert_eq(session.kart_paths.size(), 1)
	assert_null(course.get_node_or_null("AIKart1"), "pas d'IA")
	assert_true((course.get_node("Objets") as ItemManager).contre_la_montre)
	assert_not_null(course.get_node_or_null("Fantome"))
	assert_eq(session.id_piste, reglage.cle_record())
	course.free()


func test_le_contre_la_montre_donne_trois_champignons_et_pas_de_boites() -> void:
	var reglage := RaceSetup.new()
	reglage.mode = RaceSetup.Mode.CONTRE_LA_MONTRE
	var course := RaceLauncher.monter(reglage)
	add_child_autofree(course)
	var session := course.get_node("Session") as RaceSession
	await wait_until(func() -> bool: return not session.entries.is_empty(), 2.0)
	await wait_physics_frames(2)
	var objets := course.get_node("Objets") as ItemManager
	assert_eq(objets.boites.size(), 0)
	var inventaire := session.entries[0].inventaire
	assert_eq(inventaire.objet, ItemKind.TRIPLE_MUSHROOM)
	assert_eq(inventaire.charges, 3)


func _parcours() -> Fantome:
	var f := Fantome.new()
	for i in 5:
		var angle := float(i) * 0.1
		f.ajouter(Vector3(float(i) * 2.0, 0.0, 0.0), Quaternion(Vector3.UP, angle), Quaternion.IDENTITY)
	f.temps = 12.5
	return f


func test_le_fantome_interpole_entre_deux_echantillons() -> void:
	var f := _parcours()
	assert_almost_eq(f.duree(), 4.0 * Fantome.PAS, 0.0001)
	var milieu := f.a_l_instant(Fantome.PAS * 1.5)
	assert_almost_eq(milieu.position.x, 3.0, 0.001)
	assert_almost_eq(milieu.kart.get_angle(), 0.15, 0.001)
	var apres := f.a_l_instant(99.0)
	assert_almost_eq(apres.position.x, 8.0, 0.001, "au-delà de la fin : le dernier échantillon")


func test_le_fantome_se_relit_tel_quel() -> void:
	var f := _parcours()
	assert_true(f.sauver(CLE_FANTOME))
	var relu := Fantome.charger(CLE_FANTOME)
	assert_not_null(relu)
	assert_eq(relu.echantillons(), f.echantillons())
	assert_almost_eq(relu.temps, 12.5, 0.0001)
	assert_almost_eq(relu.a_l_instant(0.07).position.x, f.a_l_instant(0.07).position.x, 0.0001)


func test_un_fantome_abime_est_ignore() -> void:
	DirAccess.make_dir_recursive_absolute(Fantome.DOSSIER)
	var fichier := FileAccess.open(Fantome.chemin(CLE_FANTOME), FileAccess.WRITE)
	fichier.store_string("pas un fantôme")
	fichier.close()
	assert_null(Fantome.charger(CLE_FANTOME))
	assert_null(Fantome.charger("circuit_qui_n_existe_pas"))


func test_la_course_enregistre_le_parcours_du_joueur() -> void:
	var reglage := RaceSetup.new()
	reglage.mode = RaceSetup.Mode.CONTRE_LA_MONTRE
	var course := RaceLauncher.monter(reglage)
	var session := course.get_node("Session") as RaceSession
	session.duree_decompte = 0.0
	add_child_autofree(course)
	var fantome := course.get_node("Fantome") as FantomeCourse
	await wait_physics_frames(12)
	assert_gt(fantome.enregistrement.echantillons(), 0, "il note dès le vert")
	assert_lt(fantome.enregistrement.echantillons(), 12, "vingt fois par seconde, pas à chaque image")


func test_le_fantome_garde_ses_temps_de_passage() -> void:
	var f := _parcours()
	f.passages = PackedFloat32Array([31.5, 62.0])
	assert_true(f.sauver(CLE_FANTOME))
	var relu := Fantome.charger(CLE_FANTOME)
	assert_eq(relu.passages, f.passages)


func test_l_ecart_au_fantome_s_affiche_a_chaque_tour() -> void:
	var reglage := RaceSetup.new()
	reglage.mode = RaceSetup.Mode.CONTRE_LA_MONTRE
	var course := RaceLauncher.monter(reglage)
	add_child_autofree(course)
	var session := course.get_node("Session") as RaceSession
	await wait_until(func() -> bool: return not session.entries.is_empty(), 2.0)
	var suivi := course.get_node("Fantome") as FantomeCourse
	suivi.fantome = _parcours()
	suivi.fantome.passages = PackedFloat32Array([30.0, 60.0])
	watch_signals(suivi)
	suivi._horloge = 29.6
	suivi._sur_tour(session.entries[0])
	assert_signal_emitted_with_parameters(suivi, "ecart_au_passage", [1, 29.6 - 30.0])
	suivi._horloge = 60.25
	suivi._sur_tour(session.entries[0])
	assert_signal_emitted_with_parameters(suivi, "ecart_au_passage", [2, 60.25 - 60.0])
	assert_eq(suivi.enregistrement.passages.size(), 2, "et les passages du joueur sont notés")


func test_l_ecart_se_lit_comme_au_chrono() -> void:
	assert_eq(FantomeCourse.texte_ecart(-0.426), "−0.43 s")
	assert_eq(FantomeCourse.texte_ecart(1.5), "+1.50 s")
