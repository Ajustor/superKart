extends GutTest

## Le relief des circuits : sous la route partout, au ras des bas-côtés, et
## creusé sous les trous.

var piste: Track


func before_all() -> void:
	piste = (load("res://scenes/tracks/track_01.tscn") as PackedScene).instantiate() as Track
	add_child(piste)


func after_all() -> void:
	piste.free()


func _relief() -> TrackTerrain:
	for e in piste.elements():
		if e is TrackTerrain:
			return e
	return null


func test_le_relief_ne_perce_jamais_la_route() -> void:
	var relief := _relief()
	assert_not_null(relief)
	var c := piste.track_curve
	var pires := []
	var d := 0.0
	while d < c.length:
		if piste.trou_en(d) == null:
			for lateral in [-c.half_width, -c.half_width * 0.5, 0.0, c.half_width * 0.5, c.half_width]:
				var p := TrackFeature.point(c, d, lateral, 0.0)
				var h := relief.hauteur_en(p.x, p.z)
				if h > p.y - 0.05:
					pires.append("%d m, %+.0f : %.2f au-dessus" % [d, lateral, h - p.y])
		d += 2.0
	assert_eq(pires.size(), 0, "\n".join(pires.slice(0, 12)))


func test_le_relief_se_creuse_sous_le_trou() -> void:
	var relief := _relief()
	var c := piste.track_curve
	var d := 332.0
	assert_not_null(piste.trou_en(d))
	var p := c.position_at(d)
	assert_lt(relief.hauteur_en(p.x, p.z), p.y - RaceSession.FALL_DEPTH, "assez profond pour qu'on y tombe")


## Les reliefs d'un circuit, et l'emprise (x, z) de leur maillage : hors de
## là, il n'y a pas de relief.
func _reliefs_de(circuit: Track) -> Array:
	var liste := []
	for e in circuit.elements():
		if e is TrackTerrain:
			var maillage := e.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var boite := maillage.mesh.get_aabb()
			liste.append([e, Rect2(boite.position.x, boite.position.z, boite.size.x, boite.size.z)])
	return liste


## Où un relief passe au-dessus de la chaussée moins SOUS_LE_BORD, entre ces
## distances.
func _percees(circuit: Track, de: float, a: float) -> Array:
	var c := circuit.track_curve
	var pires := []
	var reliefs := _reliefs_de(circuit)
	var d := de
	while d <= a:
		if circuit.trou_en(d) == null and not circuit.hors_course(d):
			for lateral in [-c.half_width, -c.half_width * 0.5, 0.0, c.half_width * 0.5, c.half_width]:
				var p := TrackFeature.point(c, d, lateral, 0.0)
				for r: Array in reliefs:
					if not (r[1] as Rect2).has_point(Vector2(p.x, p.z)):
						continue
					var h: float = (r[0] as TrackTerrain).hauteur_en(p.x, p.z)
					if h > p.y - TrackTerrain.SOUS_LE_BORD + 0.01:
						pires.append("%s, %d m, %+.0f : %.2f au-dessus du bitume" % [(r[0] as Node).name, d, lateral, h - p.y])
		d += 2.0
	return pires


func test_hors_de_sa_portion_le_relief_reste_sous_la_route() -> void:
	var etoiles := (load("res://scenes/tracks/etoiles.tscn") as PackedScene).instantiate() as Track
	add_child_autofree(etoiles)
	var pires := _percees(etoiles, 1500.0, 1610.0)
	assert_eq(pires.size(), 0, "%d points :\n%s" % [pires.size(), "\n".join(pires.slice(0, 12))])


func test_aucun_relief_ne_perce_aucune_route() -> void:
	var pires := []
	for info in TrackCatalog.PISTES + TrackCatalog.ARENES:
		var circuit := info.scene.instantiate() as Track
		add_child(circuit)
		if not _reliefs_de(circuit).is_empty():
			for p in _percees(circuit, 0.0, circuit.track_curve.length):
				pires.append("%s : %s" % [info.id, p])
		circuit.free()
	assert_eq(pires.size(), 0, "%d points :\n%s" % [pires.size(), "\n".join(pires.slice(0, 20))])
