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
	reglages.course.roues = ModeleKart.ROLLER
	reglages.course.aileron = ModeleKart.AILETTES
	reglages.course.couleur = 6
	reglages.sauver()
	reglages.free()
	var relus: Node = load("res://scripts/core/game_settings.gd").new()
	relus.chemin = "user://test_garage.cfg"
	relus.charger()
	assert_eq(relus.course.modele, ModeleKart.PLUME)
	assert_eq(relus.course.roues, ModeleKart.ROLLER)
	assert_eq(relus.course.aileron, ModeleKart.AILETTES)
	assert_eq(relus.course.couleur, 6)
	relus.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_garage.cfg"))


func test_le_salon_transporte_les_karts() -> void:
	var l := Lobby.new()
	l.ajouter(1, "Hôte")
	l.ajouter(42, "Client")
	l.choisir_vehicule(42, ModeleKart.COSTAUD, 4, Personnage.CHEVALIER, ModeleKart.MONSTRE, ModeleKart.VOILE)
	var copie := Lobby.new()
	copie.depuis_liste(l.en_liste())
	assert_eq(copie.vehicule(42), [ModeleKart.COSTAUD, 4, Personnage.CHEVALIER, ModeleKart.MONSTRE, ModeleKart.VOILE])
	assert_eq(copie.vehicule(1), [ModeleKart.STANDARD, 0, Personnage.CHEVALIER, ModeleKart.ROUES_STANDARD,
		ModeleKart.BECQUET], "sans choix, le kart d'origine")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for place in copie.plan_de_course(rng):
		if place.peer == 42:
			assert_eq(place.modele, ModeleKart.COSTAUD)
			assert_eq(place.couleur, 4)
			assert_eq(place.roues, ModeleKart.MONSTRE)
			assert_eq(place.aileron, ModeleKart.VOILE)


func test_en_reseau_chacun_roule_dans_son_kart() -> void:
	var plan := []
	var niveau := 1
	for gid in Lobby.PLACES:
		if gid == 5:
			plan.append({gid = gid, peer = 1, nom = "Hôte", niveau_ia = 0, modele = ModeleKart.PLUME, couleur = 2})
		elif gid == 0:
			plan.append({gid = gid, peer = 42, nom = "Client", niveau_ia = 0, modele = ModeleKart.COSTAUD, couleur = 5,
				roues = ModeleKart.SLICKS, aileron = ModeleKart.GRAND_AILERON})
		else:
			plan.append({gid = gid, peer = 0, nom = Lobby.NOMS_IA[niveau - 1], niveau_ia = niveau})
			niveau += 1
	var chez_le_client := RaceLauncher.monter_reseau(plan, {piste = "circuit_01", tours = 1}, 42, false)
	var session := chez_le_client.get_node("Session") as RaceSession
	var moi := session.get_node(session.kart_paths[0]) as Kart
	assert_eq(_couleur_de(moi), ModeleKart.couleur(5))
	assert_almost_eq(moi.stats.poids,
		ModeleKart.facteur("poids", ModeleKart.COSTAUD, ModeleKart.SLICKS, ModeleKart.GRAND_AILERON), 0.001)
	var hote: Kart = null
	for k in session.kart_paths.size():
		if session.noms_reels[k] == "Hôte":
			hote = session.get_node(session.kart_paths[k])
	assert_not_null(hote)
	assert_eq(_couleur_de(hote), ModeleKart.couleur(2), "l'hôte, vu du client, dans sa couleur")
	chez_le_client.free()



# --- Les trois pièces --------------------------------------------------------

func _toutes_les_pieces() -> Array:
	var liste := []
	for i in ModeleKart.nombre():
		liste.append(ModeleKart.modele(i))
	for i in ModeleKart.nombre_roues():
		liste.append(ModeleKart.roues(i))
	for i in ModeleKart.nombre_ailerons():
		liste.append(ModeleKart.aileron(i))
	return liste


func test_chaque_piece_est_complete() -> void:
	for piece in _toutes_les_pieces():
		for cle in ["nom", "description"] + ModeleKart.CLES:
			assert_true(piece.has(cle), "%s : %s" % [piece.get("nom", "?"), cle])


func test_chaque_piece_hors_standard_gagne_et_perd_quelque_chose() -> void:
	# Aucune pièce n'est meilleure en tout : ce serait la seule qu'on prendrait.
	var listes := [ModeleKart.ROUES.slice(1), ModeleKart.AILERONS.slice(1), ModeleKart.CARROSSERIES.slice(1)]
	for liste in listes:
		for piece in liste:
			var gains := 0
			var pertes := 0
			for cle in ["vitesse", "acceleration", "virage", "glisse", "terrain"]:
				if piece[cle] > 1.0:
					gains += 1
				elif piece[cle] < 1.0:
					pertes += 1
			assert_gt(gains, 0, piece.nom)
			assert_gt(pertes, 0, piece.nom)


func test_les_pieces_se_multiplient() -> void:
	var base := KartStats.new()
	var s := ModeleKart.stats(base, ModeleKart.FUSEE, ModeleKart.SLICKS, ModeleKart.GRAND_AILERON)
	var attendu := 1.02 * 1.008 * 1.003
	assert_almost_eq(s.max_speed, base.max_speed * attendu, 0.001)
	assert_almost_eq(s.acceleration, base.acceleration * 0.8 * 0.95 * 0.95, 0.001)


func test_les_roues_monstre_tiennent_le_hors_piste() -> void:
	var base := KartStats.new()
	var monstre := ModeleKart.stats(base, ModeleKart.STANDARD, ModeleKart.MONSTRE)
	var slicks := ModeleKart.stats(base, ModeleKart.STANDARD, ModeleKart.SLICKS)
	assert_gt(monstre.offroad_speed_multiplier, base.offroad_speed_multiplier)
	assert_lt(slicks.offroad_speed_multiplier, base.offroad_speed_multiplier)
	assert_lte(monstre.offroad_speed_multiplier, 0.9, "le hors-piste reste plus lent que la route")


func test_chaque_combinaison_garde_la_parabole_des_sauts() -> void:
	# Comme les cylindrées : un kart plus lent qui quitte une rampe ne doit pas
	# tomber dans le trou qu'elle enjambe.
	var base := KartStats.new()
	for c in ModeleKart.nombre():
		for r in ModeleKart.nombre_roues():
			for a in ModeleKart.nombre_ailerons():
				var s := ModeleKart.stats(base, c, r, a)
				var v := s.max_speed / base.max_speed
				assert_almost_eq(s.gravity, base.gravity * v * v, 0.001)
				assert_almost_eq(s.echelle_des_tremplins, base.echelle_des_tremplins * v, 0.001)
				# Le rayon de braquage à fond reste sous celui de l'épingle du
				# circuit 1 (13,3 m d'axe).
				var rayon := s.max_speed / s.turn_rate
				assert_lt(rayon, 13.1, "%d/%d/%d" % [c, r, a])


func test_les_jauges_suivent_la_combinaison() -> void:
	var standard := ModeleKart.jauges(ModeleKart.STANDARD)
	var tout_terrain := ModeleKart.jauges(ModeleKart.BUGGY, ModeleKart.MONSTRE, ModeleKart.VOILE)
	assert_eq(standard.size(), ModeleKart.JAUGES.size())
	var t := ModeleKart.CLES.find("terrain")
	assert_gt(tout_terrain[t], standard[t])
	for c in ModeleKart.nombre():
		for r in ModeleKart.nombre_roues():
			for a in ModeleKart.nombre_ailerons():
				for v in ModeleKart.jauges(c, r, a):
					assert_between(v, 0.149, 1.001)


func test_l_allure_suit_les_pieces() -> void:
	var kart: Node3D = (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate()
	ModeleKart.habiller(kart, ModeleKart.FUSEE, ModeleKart.couleur(1), ModeleKart.MONSTRE, ModeleKart.GRAND_AILERON)
	var pneu := kart.get_node("Wheels/WheelFL/Tire") as MeshInstance3D
	var monstre := pneu.mesh
	var hauteur_monstre := (kart.get_node("Wheels/WheelFL") as Node3D).position.y
	assert_almost_eq((kart.get_node("Suspension") as KartSuspension).wheel_radius, 0.24, 0.001)
	var aileron := (kart.get_node("Body/Aileron") as MeshInstance3D).mesh
	assert_not_null(aileron)
	assert_not_null(kart.get_node("Body/Carrosserie"))
	# On rhabille : rien ne s'empile, tout se remplace.
	ModeleKart.habiller(kart, ModeleKart.STANDARD, ModeleKart.couleur(2))
	assert_ne(pneu.mesh, monstre)
	assert_lt((kart.get_node("Wheels/WheelFL") as Node3D).position.y, hauteur_monstre,
		"une roue plus petite se monte plus bas")
	assert_ne((kart.get_node("Body/Aileron") as MeshInstance3D).mesh, aileron)
	var ailerons := kart.get_node("Body").get_children().filter(func(n: Node) -> bool:
		return n.name.begins_with("Aileron"))
	assert_eq(ailerons.size(), 1)
	assert_eq(_couleur_de(kart), ModeleKart.couleur(2), "repeint, même après un premier habillage")
	kart.free()


func test_l_ia_court_dans_des_karts_varies() -> void:
	var reglage := RaceSetup.new()
	var course := RaceLauncher.monter(reglage)
	var session := course.get_node("Session") as RaceSession
	var vitesses := {}
	for chemin in session.kart_paths.slice(1):
		vitesses[snappedf((session.get_node(chemin) as Kart).stats.max_speed, 0.001)] = true
	assert_gt(vitesses.size(), 3, "les adversaires n'ont pas tous le même kart")
	for v in vitesses:
		assert_almost_eq(v / KartStats.new().max_speed, 1.0, 0.0101,
			"mais aucun ne gagne par son kart seul")
	course.free()


func test_la_glisse_allonge_les_mini_turbos() -> void:
	var base := KartStats.new()
	var s := ModeleKart.stats(base, ModeleKart.DERIVEUR)
	for p in s.boost_durations.size():
		assert_gt(s.boost_durations[p], base.boost_durations[p])
