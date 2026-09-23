extends SceneTree

## Essai du multijoueur à deux instances, sans écran ni joueur :
##
##   godot --headless --path . -s tools/essai_reseau.gd -- hote   &
##   godot --headless --path . -s tools/essai_reseau.gd -- client
##
## Avec « coupe » en second argument (des deux côtés), l'hôte lance une coupe
## en 100cc, de manches d'un tour, et enchaîne les manches ; chacun écrit les
## points après chaque manche, la grille de départ et le podium.
##
## L'hôte ouvre une partie, le client la rejoint sur 127.0.0.1, l'hôte lance
## une course d'un tour ; chaque kart humain est confié à l'IA pour aller au
## bout. Chacun écrit le départ, les objets de son joueur, les arrivées et le
## classement final : les deux journaux doivent donner le même classement et
## les mêmes temps.
##
## En temps réel, sans --fixed-fps : l'hôte finirait sa course avant que le
## client ait fini de charger la sienne.

## Ce lanceur ne fait que charger l'essai (essai_reseau_course.gd) à la
## première image : un script lancé par -s est compilé avant que les
## autoloads (GameSettings, Reseau…) n'existent, et les scripts de la course
## en dépendent — les commandes tactiles ne compilaient pas pendant l'essai.

var _lance := false


func _process(_delta: float) -> bool:
	if not _lance:
		_lance = true
		root.add_child(load("res://tools/essai_reseau_course.gd").new())
	return false
