extends SceneTree

## La glisse au banc d'essai : sur des cercles de 12 à 90 m, un joueur au
## clavier tient-il jusqu'au grand turbo ?
##
##   godot --headless --path . -s tools/essai_glisse.gd

func _initialize() -> void:
	var stats := load("res://resources/karts/default_kart.tres") as KartStats
	for rayon in [12.0, 20.0, 30.0, 45.0, 60.0, 75.0, 90.0]:
		var r := EssaiGlisse.tenir(stats, rayon)
		print("rayon %3d m : %s" % [rayon, ("MUR à %.1f s, palier %d" % [r.temps, r.palier]) if r.mur
			else ("palier %d à %.1f s, écart max %.1f m" % [r.palier, r.temps, r.ecart_max])])
	quit()
