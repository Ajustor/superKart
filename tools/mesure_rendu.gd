extends SceneTree

## Ce que coûte un circuit à la carte graphique — voir mesure_rendu_course.gd :
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \\
##       --fixed-fps 30 -s tools/mesure_rendu.gd -- <id> [haute|moyenne|basse]

var _lance := false


func _process(_delta: float) -> bool:
	if not _lance:
		_lance = true
		root.add_child(load("res://tools/mesure_rendu_course.gd").new())
	return false
