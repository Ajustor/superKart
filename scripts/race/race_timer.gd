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
static func format(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var restant := seconds - float(minutes * 60)
	return "%d:%06.3f" % [minutes, restant]
