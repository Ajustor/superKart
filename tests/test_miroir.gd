extends GutTest

## Le mode miroir garde tous les sauts : chaque tremplin, rampe, trou et
## accélérateur est là, au reflet exact de sa place, et ses flèches pointent
## toujours dans le sens de la course.


func _sauts(piste: Track) -> Array[TrackFeature]:
	var liste: Array[TrackFeature] = []
	for e in piste.elements():
		if e is TrackJump or e is TrackRamp or e is TrackGap or e is TrackBoost:
			liste.append(e)
	return liste


func _milieu(piste: Track, e: TrackFeature) -> Vector3:
	return TrackFeature.point(piste.track_curve, e.debut + e.longueur * 0.5, e.decalage, 0.0)


func test_chaque_saut_est_au_reflet_de_sa_place() -> void:
	for info in TrackCatalog.PISTES:
		var normal := info.scene.instantiate() as Track
		var miroir := info.scene.instantiate() as Track
		Miroir.appliquer(miroir)
		add_child(normal)
		add_child(miroir)
		var a := _sauts(normal)
		var b := _sauts(miroir)
		assert_eq(b.size(), a.size(), "%s : autant de sauts" % info.id)
		for i in mini(a.size(), b.size()):
			var p := _milieu(normal, a[i])
			var q := _milieu(miroir, b[i])
			assert_almost_eq(Vector3(-p.x, p.y, p.z).distance_to(q), 0.0, 0.05,
				"%s : %s au reflet de sa place" % [info.id, a[i].name])
			assert_eq(b[i].get_class(), a[i].get_class())
		normal.free()
		miroir.free()


func test_en_miroir_on_saute_toujours() -> void:
	var info := TrackCatalog.par_id("circuit_01")
	var piste := info.scene.instantiate() as Track
	Miroir.appliquer(piste)
	add_child(piste)
	var c := piste.track_curve
	for e in _sauts(piste):
		var d := e.debut + e.longueur * 0.5
		if e is TrackJump:
			assert_eq(piste.tremplin_en(d, e.decalage), e, "le tremplin %s pousse toujours" % e.name)
		elif e is TrackBoost:
			assert_eq(piste.accelerateur_en(d, e.decalage), e)
		elif e is TrackGap:
			assert_eq(piste.trou_en(d), e)
		elif e is TrackRamp:
			assert_not_null(piste.rampe_en(d, e.decalage), "la rampe %s est là" % e.name)
	assert_gt(c.length, 0.0)
	piste.free()


func test_la_fleche_pointe_vers_l_avant() -> void:
	var fond := Color(0, 0, 0)
	var dessin := Color(1, 1, 1)
	var image := TrackFeature.image_de_chevron(fond, dessin)
	# u (x) croît dans le sens de la course : la pointe, au milieu, est plus
	# en avant que les ailes, sur les bords.
	var pointe := -1
	var aile := -1
	for x in 32:
		if image.get_pixel(x, 15) == dessin:
			pointe = x
		if image.get_pixel(x, 2) == dessin:
			aile = x
	assert_gt(pointe, aile)
	assert_eq(image.get_pixel(31, 15), fond, "un vide franc entre deux flèches")


func test_le_miroir_retourne_le_vent_et_les_obstacles() -> void:
	var piste := Track.new()
	var vent := TrackCourant.new()
	vent.poussee_laterale = 6.0
	vent.decalage = 2.0
	piste.add_child(vent)
	var tonneau := TrackObstacle.new()
	tonneau.type = TrackObstacle.Type.TONNEAU
	tonneau.amplitude = 5.0
	piste.add_child(tonneau)
	var droit := tonneau.pose_de_la_tete(0.5).x
	Miroir._retourner_element(vent)
	Miroir._retourner_element(tonneau)
	assert_eq(vent.poussee_laterale, -6.0, "il pousse de l'autre côté")
	assert_eq(vent.decalage, -2.0)
	assert_almost_eq(tonneau.pose_de_la_tete(0.5).x, -droit, 0.001, "il roule dans l'autre sens")
	piste.free()
