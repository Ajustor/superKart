extends GutTest

## Sur chaque circuit, tout ce qui n'est pas la chaussée est hors piste : les
## sols et les reliefs qui portent le kart, les bas-côtés, le pré sous un pont.
## Seul le bitume, bordures comprises, ne ralentit pas.


func _monter(info: TrackInfo) -> Track:
	var piste: Track = info.scene.instantiate()
	add_child_autofree(piste)
	return piste


func _session(piste: Track) -> RaceSession:
	var session := RaceSession.new()
	session._track = piste
	autofree(session)
	return session


func test_sur_chaque_circuit_seul_le_bitume_est_la_piste() -> void:
	for info in TrackCatalog.PISTES:
		var piste := _monter(info)
		var session := _session(piste)
		var c := piste.track_curve
		var sols := 0
		var d := 5.0
		while d < c.length:
			if piste.hors_course(d) or piste.trou_en(d) != null or piste.en_zone_hors_piste(d, 0.0):
				d += 25.0
				continue
			var route := c.position_at(d) + c.up_at(d) * 0.4
			assert_false(session.hors_piste(route, d, 0.0), "%s à %.0f m : l'axe est la piste" % [info.id, d])
			var bord := c.position_at(d) + c.right_at(d) * (c.half_width - 0.3) + c.up_at(d) * 0.4
			assert_false(session.hors_piste(bord, d, c.half_width - 0.3),
				"%s à %.0f m : les bordures sont la piste" % [info.id, d])
			for lateral: float in [-(c.half_width + 1.0), c.half_width + 1.0, -(c.half_width + 10.0), c.half_width + 10.0]:
				var ici := c.position_at(d) + c.right_at(d) * lateral
				ici.y = c.position_at(d).y + 0.4
				if piste.sol_reel(ici, d):
					sols += 1
				assert_true(session.hors_piste(ici, d, lateral),
					"%s à %.0f m, %.0f m de l'axe : hors piste" % [info.id, d, lateral])
			d += 25.0
		gut.p("%s : %d points sur un sol réel, tous hors piste" % [info.id, sols])


func test_le_pre_sous_un_pont_est_hors_piste() -> void:
	var piste := _monter(TrackCatalog.par_id("lune_carnaval"))
	var session := _session(piste)
	var c := piste.track_curve
	# Le pont jusqu'au sommet de l'horloge, à 50 m : dessous, on n'y est pas.
	var d := 3400.0
	var dessous := c.position_at(d) - Vector3.UP * 20.0
	assert_true(session.hors_piste(dessous, d, 0.0))
