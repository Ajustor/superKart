extends SceneTree

## Lance un outil qui a besoin d'un écran et des autoloads :
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##       -s tools/lance_outil.gd -- <outil> [arguments…]
##
## <outil> : vignettes (vignettes.gd) ou icones_objets (icones_objets.gd).
## Un script lancé par -s est compilé avant que les autoloads (GameSettings,
## Reseau…) n'existent, et les scripts de la course en dépendent : ce lanceur
## ne fait que charger l'outil à la première image.

var _lance := false


func _process(_delta: float) -> bool:
	if not _lance:
		_lance = true
		var outil: String = OS.get_cmdline_user_args()[0]
		root.add_child(load("res://tools/%s.gd" % outil).new())
	return false
