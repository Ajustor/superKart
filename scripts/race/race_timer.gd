class_name RaceTimer
extends RefCounted

## Chrono du tour en cours et meilleur tour. Ne lit aucune horloge : on lui
## donne le temps écoulé, ce qui le rend testable et indépendant du framerate.

var current: float = 0.0
var best: float = 0.0
var has_best: bool = false


func advance(delta: float) -> void:
	current += delta


func complete_lap() -> void:
	if not has_best or current < best:
		best = current
		has_best = true
	current = 0.0


## Minutes:secondes.millisecondes, la forme attendue sur un chrono de course.
##
## On arrondit au millième avant de découper. Calculer les minutes sur la
## partie entière puis arrondir le reste séparément fige les minutes trop
## tôt : un temps à moins d'un millième d'une minute pleine s'affichait
## 0:60.000 au lieu de 1:00.000.
##
## Un temps négatif n'existe pas sur un chrono ; on l'écrase plutôt que de
## montrer 0:-5.000 si un appelant nous passe une valeur qui n'en est pas un.
static func format(seconds: float) -> String:
	var millisecondes := roundi(maxf(seconds, 0.0) * 1000.0)
	var minutes := millisecondes / 60000
	var reste := millisecondes % 60000
	return "%d:%02d.%03d" % [minutes, reste / 1000, reste % 1000]
