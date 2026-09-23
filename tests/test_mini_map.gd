extends GutTest

## La mini-carte : où elle se pose à l'écran, comment le circuit y tient, et
## comment les ponts et les trous y sont dessinés.

const ECRANS: Array[Vector2] = [Vector2(1152, 648), Vector2(1280, 720), Vector2(2400, 1080), Vector2(800, 480)]


func test_la_carte_ne_couvre_ni_l_objet_ni_la_pause_ni_les_commandes() -> void:
	for ecran in ECRANS:
		var carte := MiniMap.cadre(ecran)
		assert_true(Rect2(Vector2.ZERO, ecran).encloses(carte), "%s : dans l'écran" % ecran)
		var objet := Rect2(Vector2(ecran.x - 104.0 - RaceHUD.CASE_OBJET, 16.0), Vector2(RaceHUD.CASE_OBJET, RaceHUD.CASE_OBJET))
		var pause := Rect2(Vector2(ecran.x - 88.0, 16.0), Vector2(72, 72))
		assert_false(carte.intersects(objet), "%s : sous l'emplacement d'objet" % ecran)
		assert_false(carte.intersects(pause), "%s : sous le bouton pause" % ecran)
		for b in TouchControls.boutons(ecran):
			var disque := Rect2(b.centre - Vector2(b.rayon, b.rayon), Vector2(b.rayon, b.rayon) * 2.0)
			assert_false(carte.intersects(disque), "%s : au-dessus du bouton %s" % [ecran, b.action])


func test_le_cadrage_tient_tout_le_trace_sans_le_deformer() -> void:
	var points := PackedVector2Array([Vector2(-100, -20), Vector2(300, -20), Vector2(300, 80), Vector2(-100, 80)])
	var t := MiniMap.cadrage(points, Vector2(200, 200), 10.0)
	for p in points:
		var q := t * p
		assert_between(q.x, 9.9, 190.1)
		assert_between(q.y, 9.9, 190.1)
	assert_almost_eq(t.get_scale().x, t.get_scale().y, 0.0001, "même échelle dans les deux sens")
	assert_almost_eq((t * Vector2(300, 0)).x - (t * Vector2(-100, 0)).x, 180.0, 0.01,
		"le plus grand côté remplit la carte")
	assert_almost_eq((t * Vector2(100, 30)), Vector2(100, 100), Vector2(0.01, 0.01), "centré")


func _monter(id: String) -> Track:
	var piste: Track = TrackCatalog.par_id(id).scene.instantiate()
	add_child_autofree(piste)
	return piste


func test_le_pont_du_ruban_celeste_passe_par_dessus() -> void:
	var decoupe := MiniMap.decouper(_monter("ruban_celeste"))
	var ponts: Array = decoupe[1]
	assert_eq(ponts.count(true), 1, "un seul pont : celui du huit")
	var traits: Array = decoupe[0]
	var pont: PackedVector2Array = traits[ponts.find(true)]
	# Le pont passe au-dessus du centre du huit, en (0, 0).
	var au_centre := false
	for p in pont:
		au_centre = au_centre or p.length() < 10.0
	assert_true(au_centre)


func test_un_circuit_sans_pont_ni_trou_est_d_un_seul_trait() -> void:
	var decoupe := MiniMap.decouper(_monter("forteresse_lave"))
	assert_eq((decoupe[1] as Array).count(true), 0, "pas de pont dans la forteresse")
	# Une seule douve : le tracé est coupé une fois, donc en deux traits.
	assert_eq((decoupe[0] as Array).size(), 2)


func test_le_trou_n_est_pas_dessine() -> void:
	var piste := _monter("plage_palmiers")
	var decoupe := MiniMap.decouper(piste)
	var c := piste.track_curve
	for t in decoupe[0]:
		for p in t:
			var d := c.distance_of(Vector3(p.x, c.position_at(c.distance_of(Vector3(p.x, 0, p.y))).y, p.y))
			assert_false(d > 780.0 and d < 788.0, "rien au-dessus du bras de mer")


func test_le_hud_montre_la_carte() -> void:
	var course := RaceLauncher.monter(RaceSetup.new())
	add_child_autofree(course)
	await wait_process_frames(3)
	var cartes := course.find_children("*", "MiniMap", true, false)
	assert_eq(cartes.size(), 1)
	var carte: MiniMap = cartes[0]
	assert_not_null(carte.session)
	assert_gt(carte.size.x, 100.0, "posée à sa taille")


func test_les_humains_sont_reperes() -> void:
	var session := RaceSession.new()
	session.duree_decompte = 0.0
	session.humains = [true, false, true]
	var piste := _monter("circuit_01")
	var karts: Array[Kart] = []
	for i in 3:
		var k := Kart.new()
		k.stats = KartStats.new()
		k.motor = KartMotor.new(k.stats)
		karts.append(k)
	session.demarrer(piste, karts)
	assert_eq(session.entries.map(func(e: RaceEntry) -> bool: return e.humain), [true, false, true])
	session.humains = []
	session.demarrer(piste, karts)
	assert_eq(session.entries.map(func(e: RaceEntry) -> bool: return e.humain), [true, false, false],
		"en solo, seul le joueur")
	for k in karts:
		k.free()
	session.free()
