extends GutTest

## Les pilotes assis dans les karts : chacun se construit, s'assoit, garde son
## klaxon, et voyage dans le salon en réseau.


func test_chaque_pilote_se_construit_en_une_seule_maillage() -> void:
	for i in Personnage.nombre():
		var m := Personnage.maillage(i)
		assert_eq(m.get_surface_count(), 1, Personnage.nom(i))
		assert_gt(m.surface_get_array_len(0), 100, Personnage.nom(i))
		var boite := m.get_aabb()
		assert_lt(boite.size.y, 1.6, "%s tient dans le kart" % Personnage.nom(i))


func test_les_pilotes_partagent_leur_maillage() -> void:
	assert_same(Personnage.maillage(Personnage.PIRATE), Personnage.maillage(Personnage.PIRATE))


func test_le_pilote_s_assoit_et_donne_son_klaxon() -> void:
	var kart := (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate() as Kart
	add_child_autofree(kart)
	Personnage.habiller(kart, Personnage.TORTUE)
	Personnage.habiller(kart, Personnage.LIEVRE)
	var pilotes := kart.get_node("Body").find_children("Pilote", "", false, false)
	assert_eq(pilotes.size(), 1, "on remplace, on n'empile pas")
	assert_eq(kart.hauteur_klaxon, Personnage.hauteur_klaxon(Personnage.LIEVRE))
	assert_gt(Personnage.hauteur_klaxon(Personnage.LIEVRE), Personnage.hauteur_klaxon(Personnage.TORTUE),
		"le lièvre klaxonne plus aigu que la tortue")


func test_chaque_pilote_a_un_nom_et_une_origine() -> void:
	var noms := {}
	for i in Personnage.nombre():
		assert_ne(Personnage.nom(i), "")
		assert_ne(Personnage.origine(i), "")
		noms[Personnage.nom(i)] = true
	assert_eq(noms.size(), Personnage.nombre(), "pas deux fois le même")


func test_l_ia_prend_les_pilotes_libres() -> void:
	var libres := Personnage.libres([Personnage.PIRATE, Personnage.ROBOT])
	assert_false(libres.has(Personnage.PIRATE))
	assert_eq(libres.size(), Personnage.nombre() - 2)


func test_le_pilote_voyage_dans_le_salon() -> void:
	var lobby := Lobby.new()
	lobby.ajouter(1, "Jo")
	lobby.choisir_vehicule(1, ModeleKart.FUSEE, 3, Personnage.SORCIERE)
	var relu := Lobby.new()
	relu.depuis_liste(lobby.en_liste())
	assert_eq(relu.vehicule(1), [ModeleKart.FUSEE, 3, Personnage.SORCIERE])
	var plan := lobby.plan_de_course(RandomNumberGenerator.new())
	var jo: Dictionary = plan.filter(func(p): return p.peer == 1)[0]
	assert_eq(jo.personnage, Personnage.SORCIERE)


func test_une_course_seule_assoit_un_pilote_par_kart() -> void:
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.PISTES[0])
	reglage.personnage = Personnage.RENART
	var course := RaceLauncher.monter(reglage)
	add_child_autofree(course)
	await wait_physics_frames(2)
	var session := course.get_node("Session") as RaceSession
	var vus := {}
	for chemin in session.kart_paths:
		var pilote := session.get_node(chemin).get_node_or_null("Body/Pilote") as MeshInstance3D
		assert_not_null(pilote)
		vus[pilote.mesh] = true
	var joueur := session.get_node(session.kart_paths[0]).get_node("Body/Pilote") as MeshInstance3D
	assert_same(joueur.mesh, Personnage.maillage(Personnage.RENART))
	assert_eq(vus.size(), session.kart_paths.size(), "huit pilotes différents")
