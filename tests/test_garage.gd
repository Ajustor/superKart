extends GutTest

## Le garage : les modèles de kart, leurs couleurs, et comment ils arrivent
## sur la grille — en solo comme en réseau.


func _couleur_de(kart: Node) -> Color:
	return ModeleKart.teinte_de(kart as Node3D)


func test_chaque_modele_est_complet() -> void:
	for i in ModeleKart.nombre():
		var m := ModeleKart.modele(i)
		for cle in ["nom", "description", "vitesse", "acceleration", "virage", "glisse", "poids"]:
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
		for cle in ["vitesse", "acceleration", "virage", "glisse", "terrain"]:
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
	assert_not_null(joueur.get_node_or_null("Body/Kenney"), "le kart Kenney")
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
	reglages.course.roues = ModeleKart.LEGERES
	reglages.course.aileron = ModeleKart.BECQUET
	reglages.course.couleur = 6
	reglages.sauver()
	reglages.free()
	var relus: Node = load("res://scripts/core/game_settings.gd").new()
	relus.chemin = "user://test_garage.cfg"
	relus.charger()
	assert_eq(relus.course.modele, ModeleKart.PLUME)
	assert_eq(relus.course.roues, ModeleKart.LEGERES)
	assert_eq(relus.course.aileron, ModeleKart.BECQUET)
	assert_eq(relus.course.couleur, 6)
	relus.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_garage.cfg"))


func test_le_salon_transporte_les_karts() -> void:
	var l := Lobby.new()
	l.ajouter(1, "Hôte")
	l.ajouter(42, "Client")
	l.choisir_vehicule(42, ModeleKart.COSTAUD, 4, Personnage.THEO, ModeleKart.MONSTRE, ModeleKart.BECQUET)
	var copie := Lobby.new()
	copie.depuis_liste(l.en_liste())
	assert_eq(copie.vehicule(42), [ModeleKart.COSTAUD, 4, Personnage.THEO, ModeleKart.MONSTRE, ModeleKart.BECQUET])
	assert_eq(copie.vehicule(1), [ModeleKart.STANDARD, 0, Personnage.THEO, ModeleKart.ROUES_STANDARD,
		ModeleKart.BECQUET], "sans choix, le kart d'origine")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for place in copie.plan_de_course(rng):
		if place.peer == 42:
			assert_eq(place.modele, ModeleKart.COSTAUD)
			assert_eq(place.couleur, 4)
			assert_eq(place.roues, ModeleKart.MONSTRE)
			assert_eq(place.aileron, ModeleKart.BECQUET)


func test_en_reseau_chacun_roule_dans_son_kart() -> void:
	var plan := []
	var niveau := 1
	for gid in Lobby.PLACES:
		if gid == 5:
			plan.append({gid = gid, peer = 1, nom = "Hôte", niveau_ia = 0, modele = ModeleKart.PLUME, couleur = 2})
		elif gid == 0:
			plan.append({gid = gid, peer = 42, nom = "Client", niveau_ia = 0, modele = ModeleKart.COSTAUD, couleur = 5,
				roues = ModeleKart.SLICKS, aileron = ModeleKart.BECQUET})
		else:
			plan.append({gid = gid, peer = 0, nom = Lobby.NOMS_IA[niveau - 1], niveau_ia = niveau})
			niveau += 1
	var chez_le_client := RaceLauncher.monter_reseau(plan, {piste = "circuit_01", tours = 1}, 42, false)
	var session := chez_le_client.get_node("Session") as RaceSession
	var moi := session.get_node(session.kart_paths[0]) as Kart
	assert_eq(_couleur_de(moi), ModeleKart.couleur(5))
	assert_almost_eq(moi.stats.poids,
		ModeleKart.facteur("poids", ModeleKart.COSTAUD, ModeleKart.SLICKS, ModeleKart.BECQUET), 0.001)
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
	var s := ModeleKart.stats(base, ModeleKart.FUSEE, ModeleKart.SLICKS, ModeleKart.BECQUET)
	assert_almost_eq(s.max_speed, base.max_speed * 1.02 * 1.008, 0.001)
	assert_almost_eq(s.acceleration, base.acceleration * 0.8 * 0.95, 0.001)


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
	var tout_terrain := ModeleKart.jauges(ModeleKart.COSTAUD, ModeleKart.MONSTRE, ModeleKart.BECQUET)
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
	ModeleKart.habiller(kart, ModeleKart.FUSEE, ModeleKart.couleur(1), ModeleKart.MONSTRE)
	var jante := kart.get_node("Wheels/WheelFL/Jante") as MeshInstance3D
	var monstre := jante.mesh
	var hauteur_monstre := (kart.get_node("Wheels/WheelFL") as Node3D).position.y
	assert_almost_eq((kart.get_node("Suspension") as KartSuspension).wheel_radius,
		float(ModeleKart.roues(ModeleKart.MONSTRE).rayon), 0.001)
	assert_false((kart.get_node("Wheels/WheelFL/Tire") as Node3D).visible, "les roues d'origine sont cachées")
	assert_false((kart.get_node("Body/Floor") as Node3D).visible, "la caisse d'origine aussi")
	# On rhabille : rien ne s'empile, tout se remplace.
	ModeleKart.habiller(kart, ModeleKart.STANDARD, ModeleKart.couleur(2))
	assert_ne(jante.mesh, monstre)
	assert_lt((kart.get_node("Wheels/WheelFL") as Node3D).position.y, hauteur_monstre,
		"une roue plus petite se monte plus bas")
	assert_eq(kart.get_node("Body").get_children().filter(func(n: Node) -> bool:
		return n.name.begins_with("Kenney")).size(), 1)
	assert_eq(kart.get_node("Wheels/WheelFL").get_children().filter(func(n: Node) -> bool:
		return n.name.begins_with("Jante")).size(), 1)
	assert_eq(_couleur_de(kart), ModeleKart.couleur(2), "repeint, même après un premier habillage")
	kart.free()


func test_les_roues_touchent_le_sol() -> void:
	# Pendues sous leur ancre de la longueur du ressort au repos, les roues
	# de chaque train touchent le sol (y = 0) ; la caisse Kenney suit.
	var kart: Node3D = (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate()
	var suspension := kart.get_node("Suspension") as KartSuspension
	var pendant := suspension.rest_length - suspension.travel * 0.5
	for r in ModeleKart.nombre_roues():
		ModeleKart.habiller(kart, ModeleKart.STANDARD, ModeleKart.couleur(0), r)
		var rayon: float = ModeleKart.roues(r).rayon
		for roue in kart.get_node("Wheels").get_children():
			assert_almost_eq((roue as Node3D).position.y - pendant, rayon, 0.001, ModeleKart.roues(r).nom)
		var chassis := kart.get_node("Body/Kenney") as Node3D
		assert_almost_eq(chassis.position.y + ModeleKart.RAYON_KENNEY * ModeleKart.ECHELLE, rayon, 0.001)
	kart.free()


func test_la_peinture_se_partage_par_couleur() -> void:
	assert_same(ModeleKart.peinture(ModeleKart.couleur(3)), ModeleKart.peinture(ModeleKart.couleur(3)))
	assert_ne(ModeleKart.peinture(ModeleKart.couleur(3)), ModeleKart.peinture(ModeleKart.couleur(4)))


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


# --- Le nuage magique --------------------------------------------------------

func _kart_habille(carrosserie: int, train: int = ModeleKart.ROUES_STANDARD) -> Node3D:
	var kart: Node3D = (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate()
	ModeleKart.habiller(kart, carrosserie, ModeleKart.couleur(1), train)
	return kart


func _jantes_visibles(kart: Node3D) -> int:
	var n := 0
	for roue in kart.get_node("Wheels").get_children():
		var jante := roue.get_node_or_null("Jante") as Node3D
		if jante != null and jante.visible:
			n += 1
	return n


func test_le_nuage_remplace_la_caisse() -> void:
	var kart := _kart_habille(ModeleKart.NUAGE, ModeleKart.MONSTRE)
	var nuage := kart.get_node_or_null("Body/Nuage") as NuageMagique
	assert_not_null(nuage, "le nuage dans la caisse")
	assert_true(nuage.visible)
	var kenney := kart.get_node_or_null("Body/Kenney") as Node3D
	assert_true(kenney == null or not kenney.visible, "plus de kart Kenney")
	assert_eq(kart.get_node("Wheels").get_child_count(), 4, "les roues restent, la suspension en dépend")
	assert_eq(_jantes_visibles(kart), 0, "mais on ne les voit plus")
	assert_almost_eq((kart.get_node("Suspension") as KartSuspension).wheel_radius,
		float(ModeleKart.roues(ModeleKart.ROUES_STANDARD).rayon), 0.001, "posé comme sur des roues Standard")
	assert_true(ModeleKart.sur_un_nuage(kart))
	kart.free()


func test_du_kart_au_nuage_et_retour_rien_ne_s_empile() -> void:
	var kart := _kart_habille(ModeleKart.FUSEE)
	for carrosserie in [ModeleKart.NUAGE, ModeleKart.FUSEE, ModeleKart.NUAGE, ModeleKart.PLUME]:
		ModeleKart.habiller(kart, carrosserie, ModeleKart.couleur(2), ModeleKart.SLICKS)
		var nuage := ModeleKart.est_nuage(carrosserie)
		var caisse := kart.get_node("Body")
		var nuages := caisse.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Nuage"))
		var kenneys := caisse.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Kenney"))
		assert_lte(nuages.size(), 1, "un seul nuage")
		assert_eq(kenneys.size(), 1, "un seul kart Kenney")
		assert_eq((kenneys[0] as Node3D).visible, not nuage, ModeleKart.nom(carrosserie))
		if not nuages.is_empty():
			assert_eq((nuages[0] as Node3D).visible, nuage, ModeleKart.nom(carrosserie))
		assert_eq(_jantes_visibles(kart), 0 if nuage else 4, ModeleKart.nom(carrosserie))
	assert_false(ModeleKart.sur_un_nuage(kart))
	assert_eq(_couleur_de(kart), ModeleKart.couleur(2), "le kart retrouve sa peinture")
	kart.free()


func test_les_roues_ne_changent_rien_au_nuage() -> void:
	var base := KartStats.new()
	var reference := ModeleKart.stats(base, ModeleKart.NUAGE)
	var jauges := ModeleKart.jauges(ModeleKart.NUAGE)
	for r in ModeleKart.nombre_roues():
		var s := ModeleKart.stats(base, ModeleKart.NUAGE, r)
		assert_almost_eq(s.max_speed, reference.max_speed, 0.0001, ModeleKart.roues(r).nom)
		assert_almost_eq(s.turn_rate, reference.turn_rate, 0.0001)
		assert_almost_eq(s.offroad_speed_multiplier, reference.offroad_speed_multiplier, 0.0001)
		assert_almost_eq(s.poids, reference.poids, 0.0001)
		assert_eq(ModeleKart.jauges(ModeleKart.NUAGE, r), jauges)
	# Il flotte sur l'herbe, mais un rien le bouscule.
	assert_gt(reference.offroad_speed_multiplier, base.offroad_speed_multiplier)
	assert_lt(reference.poids, base.poids)


func test_au_garage_le_nuage_cache_les_roues_et_la_couleur() -> void:
	var avant: int = GameSettings.course.modele
	var roues_avant: int = GameSettings.course.roues
	var chemin_avant: String = GameSettings.chemin
	GameSettings.chemin = "user://test_garage_nuage.cfg"
	var garage := GaragePanel.new()
	add_child_autofree(garage)
	GameSettings.course.modele = ModeleKart.FUSEE
	GameSettings.course.roues = ModeleKart.SLICKS
	garage._relire()
	assert_true(garage._lignes[1].visible, "un kart a des roues")
	assert_true(garage._couleurs.visible, "et une couleur")
	assert_eq(garage._lignes[0].get_child(0).text, "Kart")
	GameSettings.course.modele = ModeleKart.COSTAUD
	garage._changer_piece(0, 1)
	assert_eq(GameSettings.course.modele, ModeleKart.NUAGE)
	assert_false(garage._lignes[1].visible, "un nuage n'a pas de roues")
	assert_false(garage._couleurs.visible, "et il est toujours doré")
	assert_not_null(garage._vitrine.get_node_or_null("Body/Nuage"), "la vitrine montre le nuage")
	garage._changer_piece(0, 1)
	assert_eq(GameSettings.course.modele, ModeleKart.STANDARD, "on repasse sur un kart")
	assert_true(garage._lignes[1].visible)
	assert_true(garage._couleurs.visible)
	assert_eq(GameSettings.course.roues, ModeleKart.SLICKS, "les roues choisies sont restées")
	GameSettings.course.modele = avant
	GameSettings.course.roues = roues_avant
	GameSettings.chemin = chemin_avant
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_garage_nuage.cfg"))


func test_un_joueur_sur_le_nuage_traverse_le_reseau() -> void:
	var l := Lobby.new()
	l.ajouter(1, "Hôte")
	l.ajouter(42, "Client")
	l.choisir_vehicule(42, ModeleKart.NUAGE, 4, Personnage.LOU, ModeleKart.MONSTRE, ModeleKart.BECQUET)
	var copie := Lobby.new()
	copie.depuis_liste(l.en_liste())
	assert_eq(copie.vehicule(42)[0], ModeleKart.NUAGE)
	var plan := copie.plan_de_course(RandomNumberGenerator.new())
	var client: Dictionary = plan.filter(func(p): return p.peer == 42)[0]
	assert_eq(client.modele, ModeleKart.NUAGE)
	var chez_l_hote := RaceLauncher.monter_reseau(plan, {piste = "circuit_01", tours = 1}, 1, true)
	var session := chez_l_hote.get_node("Session") as RaceSession
	var lui: Kart = null
	for k in session.kart_paths.size():
		if session.noms_reels[k] == "Client":
			lui = session.get_node(session.kart_paths[k])
	assert_not_null(lui)
	assert_true(ModeleKart.sur_un_nuage(lui), "vu de l'hôte, il est sur son nuage")
	assert_true((lui.get_node("Body/Nuage") as Node3D).visible)
	assert_almost_eq(lui.stats.poids, ModeleKart.facteur("poids", ModeleKart.NUAGE), 0.001)
	chez_l_hote.free()
