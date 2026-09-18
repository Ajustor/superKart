class_name KartInput
extends Node

## Source d'intention pour un kart. Les sous-classes remplissent `command`
## dans _fill(). C'est le seul point de variation entre le joueur et l'IA :
## en aval, KartMotor ne sait pas qui lui parle.

## Renseigné par Kart._ready(). Le joueur n'en a pas besoin — le singleton
## Input est global — mais l'IA doit lire la position et la vitesse du kart
## qu'elle pilote, et mieux vaut une poignée au contrat qu'un get_parent()
## improvisé dans chaque sous-classe.
var kart: Kart

var command := KartCommand.new()


## Point d'entrée, volontairement non surchargeable en pratique : il garantit
## qu'aucun champ ne garde la valeur de la frame précédente, même si une
## sous-classe oublie d'en écrire un.
func poll(delta: float) -> KartCommand:
	command.clear()
	_fill(delta)
	return command


## À surcharger. La commande est déjà remise à neuf.
func _fill(_delta: float) -> void:
	pass
