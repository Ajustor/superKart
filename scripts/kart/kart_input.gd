class_name KartInput
extends Node

## Source d'intention pour un kart. Les sous-classes remplissent `command`
## dans poll(). C'est le seul point de variation entre le joueur et l'IA :
## en aval, KartMotor ne sait pas qui lui parle.

var command := KartCommand.new()


## Met `command` à jour pour cette frame et la renvoie.
func poll(_delta: float) -> KartCommand:
	command.clear()
	return command
