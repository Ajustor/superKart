extends SceneTree

## Fait courir huit IA sur un circuit — voir essai_circuit_course.gd :
##
##   godot --headless --fixed-fps 60 --path . -s tools/essai_circuit.gd -- <id> [tours]
##
## Ce lanceur ne fait que charger l'essai à la première image : un script
## lancé par -s est compilé avant que les autoloads (GameSettings, Reseau…)
## n'existent, et les scripts de la course en dépendent.

var _lance := false


func _process(_delta: float) -> bool:
	if not _lance:
		_lance = true
		root.add_child(load("res://tools/essai_circuit_course.gd").new())
	return false
