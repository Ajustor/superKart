extends SceneTree

## Cherche les saccades d'une vraie course, rendue — voir
## essai_saccades_course.gd :
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 480x270 \
##       -s tools/essai_saccades.gd -- <id> [secondes] [sans_chauffe]
##
## Ce lanceur ne fait que charger l'essai à la première image : un script
## lancé par -s est compilé avant que les autoloads n'existent.

var _lance := false


func _process(_delta: float) -> bool:
	if not _lance:
		_lance = true
		root.add_child(load("res://tools/essai_saccades_course.gd").new())
	return false
