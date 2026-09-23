extends SceneTree

## Photographie un circuit — voir capture_circuit_vues.gd :
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \\
##       -s tools/capture_circuit.gd -- <id> <dossier> [distance…]
##
## Ce lanceur ne fait que charger la prise de vues à la première image : un
## script lancé par -s est compilé avant que les autoloads n'existent.

var _lance := false


func _process(_delta: float) -> bool:
	if not _lance:
		_lance = true
		root.add_child(load("res://tools/capture_circuit_vues.gd").new())
	return false
