extends SceneTree

## Filme un tour d'un circuit — voir film_circuit_course.gd :
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 \\
##       --fixed-fps 30 --write-movie tour.avi -s tools/film_circuit.gd -- <id> [case] [tours]
##
## Ce lanceur ne fait que charger le tournage à la première image : un
## script lancé par -s est compilé avant que les autoloads n'existent.

var _lance := false


func _process(_delta: float) -> bool:
	if not _lance:
		_lance = true
		root.add_child(load("res://tools/film_circuit_course.gd").new())
	return false
