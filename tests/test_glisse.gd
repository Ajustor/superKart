extends GutTest

## Le grand turbo doit se gagner partout où la route tourne longtemps, des
## épingles aux grandes courbes : un joueur au clavier tient la glisse jusqu'au
## palier 3 sans toucher le bord, sur des cercles de 12 à 90 m.

func test_le_palier_3_se_tient_des_epingles_aux_grandes_courbes() -> void:
	var stats := load("res://resources/karts/default_kart.tres") as KartStats
	for rayon in [12.0, 20.0, 30.0, 45.0, 60.0, 75.0, 90.0]:
		var r := EssaiGlisse.tenir(stats, rayon)
		assert_false(r.mur, "rayon %d m : la glisse a touché le bord" % rayon)
		assert_eq(r.palier, 3, "rayon %d m" % rayon)
		assert_lt(r.temps, 4.5, "rayon %d m : le grand turbo en moins de 4,5 s" % rayon)


func test_contre_braquer_ouvre_la_glisse_presque_droite() -> void:
	var stats := load("res://resources/karts/default_kart.tres") as KartStats
	var m := KartMotor.new(stats)
	var exterieur := stats.max_speed / (stats.drift_turn_rate * m.rapport_de_glisse(0.0))
	var neutre := stats.max_speed / (stats.drift_turn_rate * m.rapport_de_glisse(0.5))
	assert_gt(exterieur, 100.0, "au contre-braquage, une très grande courbe")
	assert_lt(neutre, 15.0, "au neutre, toujours un vrai virage")
