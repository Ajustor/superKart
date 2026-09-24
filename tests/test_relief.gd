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
