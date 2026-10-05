extends GutTest

## Les pilotes assis dans les karts : chacun se construit, s'assoit, garde son
## klaxon, et voyage dans le salon en réseau.


func test_chaque_pilote_a_son_modele_et_conduit() -> void:
	for i in Personnage.nombre():
		var pilote := Personnage.scene(i).instantiate()
		var anim := pilote.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_not_null(anim, Personnage.nom(i))
		if anim != null:
			assert_true(anim.has_animation(Personnage.ANIMATION), "%s sait conduire" % Personnage.nom(i))
		pilote.free()


func test_les_pilotes_partagent_leur_modele() -> void:
	assert_same(Personnage.scene(Personnage.LOU), Personnage.scene(Personnage.LOU))


func test_le_pilote_s_assoit_et_donne_son_klaxon() -> void:
	var kart := (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate() as Kart
	add_child_autofree(kart)
	Personnage.habiller(kart, Personnage.GUS)
	Personnage.habiller(kart, Personnage.LOU)
	var pilotes := kart.get_node("Body").find_children("Pilote", "", false, false)
	assert_eq(pilotes.size(), 1, "on remplace, on n'empile pas")
	assert_eq(kart.hauteur_klaxon, Personnage.hauteur_klaxon(Personnage.LOU))
	assert_gt(Personnage.hauteur_klaxon(Personnage.LOU), Personnage.hauteur_klaxon(Personnage.GUS),
		"Lou klaxonne plus aigu que Gus")


func test_chaque_pilote_a_un_nom_et_une_origine() -> void:
	var noms := {}
	for i in Personnage.nombre():
		assert_ne(Personnage.nom(i), "")
		assert_ne(Personnage.origine(i), "")
		noms[Personnage.nom(i)] = true
	assert_eq(noms.size(), Personnage.nombre(), "pas deux fois le même")


func test_l_ia_prend_les_pilotes_libres() -> void:
	var libres := Personnage.libres([Personnage.MAX, Personnage.VICTOR])
	assert_false(libres.has(Personnage.MAX))
	assert_eq(libres.size(), Personnage.nombre() - 2)


func test_le_pilote_voyage_dans_le_salon() -> void:
	var lobby := Lobby.new()
	lobby.ajouter(1, "Jo")
	lobby.choisir_vehicule(1, ModeleKart.FUSEE, 3, Personnage.NINA)
	var relu := Lobby.new()
	relu.depuis_liste(lobby.en_liste())
	assert_eq(relu.vehicule(1).slice(0, 3), [ModeleKart.FUSEE, 3, Personnage.NINA])
	var plan := lobby.plan_de_course(RandomNumberGenerator.new())
	var jo: Dictionary = plan.filter(func(p): return p.peer == 1)[0]
	assert_eq(jo.personnage, Personnage.NINA)


func test_une_course_seule_assoit_un_pilote_par_kart() -> void:
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.PISTES[0])
	reglage.personnage = Personnage.MEI
	var course := RaceLauncher.monter(reglage)
	add_child_autofree(course)
	await wait_physics_frames(2)
	var session := course.get_node("Session") as RaceSession
	var vus := {}
	for chemin in session.kart_paths:
		var kart := session.get_node(chemin) as Node3D
		assert_not_null(kart.get_node_or_null("Body/Pilote"))
		vus[Personnage.pilote_de(kart)] = true
	assert_eq(Personnage.pilote_de(session.get_node(session.kart_paths[0])), Personnage.MEI)
	assert_eq(vus.size(), session.kart_paths.size(), "huit pilotes différents")
