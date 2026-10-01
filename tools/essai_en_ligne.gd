extends SceneTree

## Essai du mode en ligne : un serveur dédié et deux joueurs, sans écran.
##
##   godot --headless --path . -- --serveur --port 8930 --nom Essai &
##   godot --headless --path . -s tools/essai_en_ligne.gd -- chef 8930 [coupe] &
##   godot --headless --path . -s tools/essai_en_ligne.gd -- invite 8930 [coupe]
##
## Le chef (le premier arrivé) règle le salon et lance la course à distance ;
## le serveur, qui ne pilote pas, simule l'IA et arbitre. Chaque joueur confie
## son kart à l'IA et écrit le classement : les deux doivent le même. En
## coupe, le serveur enchaîne lui-même les manches.

var _lance := false


func _process(_delta: float) -> bool:
	if not _lance:
		_lance = true
		root.add_child(load("res://tools/essai_en_ligne_course.gd").new())
	return false
