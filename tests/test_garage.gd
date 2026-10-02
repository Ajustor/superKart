extends GutTest

## Le garage : les modèles de kart, leurs couleurs, et comment ils arrivent
## sur la grille — en solo comme en réseau.


func _couleur_de(kart: Node) -> Color:
	var plancher := kart.get_node("Body/Floor") as MeshInstance3D
	return (plancher.get_surface_override_material(0) as StandardMaterial3D).albedo_color


func test_chaque_modele_est_complet() -> void:
	for i in ModeleKart.nombre():
		var m := ModeleKart.modele(i)
		for cle in ["nom", "description", "vitesse", "acceleration", "virage", "glisse", "poids", "caisse"]:
			assert_true(m.has(cle), "%s : %s" % [ModeleKart.nom(i), cle])
		assert_eq(ModeleKart.jauges(i).size(), ModeleKart.JAUGES.size())
	assert_eq(ModeleKart.NOMS_COULEURS.size(), ModeleKart.COULEURS.size())


func test_le_standard_ne_change_rien() -> void:
	var base := KartStats.new()
	var s := ModeleKart.stats(base, ModeleKart.STANDARD)
	assert_ne(s, base, "une copie")
	assert_eq(s.max_speed, base.max_speed)
	assert_eq(s.drift_tiers, base.drift_tiers)


func test_chaque_modele_gagne_et_perd_quelque_chose() -> void:
	# Aucun modèle n'est meilleur en tout : ce serait le seul qu'on choisirait.
	for i in range(1, ModeleKart.nombre()):
		var m := ModeleKart.modele(i)
		var gains := 0
		var pertes := 0
		for cle in ["vitesse", "acceleration", "virage", "glisse"]:
			if m[cle] > 1.0:
				gains += 1
			elif m[cle] < 1.0:
				pertes += 1
		assert_gt(gains, 0, ModeleKart.nom(i))
		assert_gt(pertes, 0, ModeleKart.nom(i))


func test_le_deriveur_charge_plus_vite() -> void:
	var base := KartStats.new()
	var s := ModeleKart.stats(base, ModeleKart.DERIVEUR)
	for p in s.drift_tiers.size():
		assert_lt(s.drift_tiers[p], base.drift_tiers[p])


func test_le_costaud_pousse_le_leger() -> void:
	# Le lourd, derrière, pousse le léger : le léger gagne plus que le lourd
	# ne perd.
	var lourd := KartMotor.new(ModeleKart.stats(KartStats.new(), ModeleKart.COSTAUD))
	var leger := KartMotor.new(ModeleKart.stats(KartStats.new(), ModeleKart.PLUME))
	lourd.speed = 22.0
	leger.speed = 12.0
	var copie_lourd := KartMotor.new(lourd.stats)
	copie_lourd.speed = lourd.speed
	KartBump.encaisser(lourd, Vector3(0, 0, 0), leger, Vector3(0, 0, -1.0))
	KartBump.encaisser(leger, Vector3(0, 0, -1.0), copie_lourd, Vector3(0, 0, 0))
	var perte_lourd := 22.0 - lourd.speed
	var gain_leger := leger.speed - 12.0
	assert_gt(perte_lourd, 0.0)
	assert_gt(gain_leger, perte_lourd * 1.4)


func test_la_course_habille_le_joueur_et_colore_l_ia() -> void:
	var reglage := RaceSetup.new()
	reglage.modele = ModeleKart.FUSEE
	reglage.couleur = 3
	var course := RaceLauncher.monter(reglage)
	var session := course.get_node("Session") as RaceSession
	var joueur := session.get_node(session.kart_paths[0]) as Kart
	assert_almost_eq(joueur.stats.max_speed, KartStats.new().max_speed * ModeleKart.modele(ModeleKart.FUSEE).vitesse, 0.01)
	assert_eq(_couleur_de(joueur), ModeleKart.couleur(3))
	assert_eq(joueur.get_node("Body").scale, ModeleKart.modele(ModeleKart.FUSEE).caisse)
	var vues := [ModeleKart.couleur(3)]
	for chemin in session.kart_paths.slice(1):
		var c := _couleur_de(session.get_node(chemin))
		assert_does_not_have(vues, c, "chaque kart a sa couleur")
		vues.append(c)
	course.free()


func test_le_choix_du_garage_survit_au_redemarrage() -> void:
	var reglages: Node = load("res://scripts/core/game_settings.gd").new()
	reglages.chemin = "user://test_garage.cfg"
	reglages.course.modele = ModeleKart.PLUME
	reglages.course.couleur = 6
	reglages.sauver()
	reglages.free()
	var relus: Node = load("res://scripts/core/game_settings.gd").new()
	relus.chemin = "user://test_garage.cfg"
	relus.charger()
	assert_eq(relus.course.modele, ModeleKart.PLUME)
	assert_eq(relus.course.couleur, 6)
	relus.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_garage.cfg"))


func test_le_salon_transporte_les_karts() -> void:
	var l := Lobby.new()
	l.ajouter(1, "Hôte")
	l.ajouter(42, "Client")
	l.choisir_vehicule(42, ModeleKart.COSTAUD, 4)
	var copie := Lobby.new()
	copie.depuis_liste(l.en_liste())
	assert_eq(copie.vehicule(42), [ModeleKart.COSTAUD, 4, Personnage.CHEVALIER])
	assert_eq(copie.vehicule(1), [ModeleKart.STANDARD, 0, Personnage.CHEVALIER], "sans choix, le kart d'origine")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for place in copie.plan_de_course(rng):
		if place.peer == 42:
			assert_eq(place.modele, ModeleKart.COSTAUD)
			assert_eq(place.couleur, 4)


func test_en_reseau_chacun_roule_dans_son_kart() -> void:
	var plan := []
	var niveau := 1
	for gid in Lobby.PLACES:
		if gid == 5:
			plan.append({gid = gid, peer = 1, nom = "Hôte", niveau_ia = 0, modele = ModeleKart.PLUME, couleur = 2})
		elif gid == 0:
			plan.append({gid = gid, peer = 42, nom = "Client", niveau_ia = 0, modele = ModeleKart.COSTAUD, couleur = 5})
		else:
			plan.append({gid = gid, peer = 0, nom = Lobby.NOMS_IA[niveau - 1], niveau_ia = niveau})
			niveau += 1
	var chez_le_client := RaceLauncher.monter_reseau(plan, {piste = "circuit_01", tours = 1}, 42, false)
	var session := chez_le_client.get_node("Session") as RaceSession
	var moi := session.get_node(session.kart_paths[0]) as Kart
	assert_eq(_couleur_de(moi), ModeleKart.couleur(5))
	assert_almost_eq(moi.stats.poids, ModeleKart.modele(ModeleKart.COSTAUD).poids, 0.001)
	var hote: Kart = null
	for k in session.kart_paths.size():
		if session.noms_reels[k] == "Hôte":
			hote = session.get_node(session.kart_paths[k])
	assert_not_null(hote)
	assert_eq(_couleur_de(hote), ModeleKart.couleur(2), "l'hôte, vu du client, dans sa couleur")
	chez_le_client.free()
