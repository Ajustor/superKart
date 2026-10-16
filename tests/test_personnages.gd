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


func test_le_pilote_joue_ce_qui_arrive_au_kart() -> void:
	var kart := (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate() as Kart
	add_child_autofree(kart)
	Personnage.habiller(kart, Personnage.MAX)
	await wait_frames(2)
	var anim := kart.get_node("Body/Pilote").find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_eq(anim.current_animation, Personnage.ANIMATION, "au volant")
	kart.geste.emit(Kart.GESTE_LANCER)
	await wait_frames(2)
	assert_eq(anim.current_animation, "attack-melee-right", "il lance son objet")
	await wait_seconds(0.6)
	assert_eq(anim.current_animation, Personnage.ANIMATION, "puis reprend le volant")
	kart.motor.stun()
	await wait_frames(2)
	assert_eq(anim.current_animation, KartVisuals.ANIM_TETE_A_QUEUE, "en tête-à-queue, il panique")
	kart.motor.stun_timer = 0.0
	kart.motor.state = KartMotor.State.GRIP
	kart.geste.emit(Kart.GESTE_VICTOIRE)
	await wait_frames(2)
	assert_eq(anim.current_animation, "emote-yes", "à l'arrivée, il fête sa place")


func test_sur_le_nuage_le_pilote_se_tient_debout_au_centre() -> void:
	var kart := (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate() as Kart
	ModeleKart.habiller(kart, ModeleKart.NUAGE, ModeleKart.couleur(0), ModeleKart.MONSTRE)
	add_child_autofree(kart)
	Personnage.habiller(kart, Personnage.ZOE)
	await wait_frames(2)
	var pilote := kart.get_node("Body/Pilote") as Node3D
	assert_almost_eq(pilote.position.x, 0.0, 0.001, "au centre du nuage")
	assert_almost_eq(pilote.position.z, 0.0, 0.001)
	assert_almost_eq(pilote.position.y, ModeleKart.PIEDS_SUR_LE_NUAGE, NuageMagique.BERCEMENT + 0.001,
		"les pieds dans le haut du nuage, qui le berce")
	var anim := pilote.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_eq(anim.current_animation, Personnage.ANIMATION_DEBOUT, "debout, au repos")
	kart.geste.emit(Kart.GESTE_LANCER)
	await wait_frames(2)
	assert_eq(anim.current_animation, "attack-melee-right", "le geste passe avant le repos")
	await wait_seconds(0.6)
	assert_eq(anim.current_animation, Personnage.ANIMATION_DEBOUT, "puis il reprend la pose")
	# Rhabillé en kart, il se rassoit au volant.
	ModeleKart.habiller(kart, ModeleKart.STANDARD, ModeleKart.couleur(0))
	await wait_frames(2)
	assert_eq(anim.current_animation, Personnage.ANIMATION)
	assert_almost_eq(pilote.position.y, ModeleKart.siege().origin.y, 0.001, "assis, il ne se berce plus")


func test_chaque_pilote_sait_se_tenir_debout() -> void:
	for i in Personnage.nombre():
		var pilote := Personnage.scene(i).instantiate()
		var anim := pilote.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_true(anim != null and anim.has_animation(Personnage.ANIMATION_DEBOUT), Personnage.nom(i))
		pilote.free()
