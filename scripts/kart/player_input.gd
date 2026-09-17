class_name PlayerInput
extends KartInput

## Lit le clavier et la manette. Aucune allocation : on réutilise
## l'instance de KartCommand héritée de KartInput.


func poll(_delta: float) -> KartCommand:
	command.steer = Input.get_axis(&"steer_left", &"steer_right")
	command.throttle = Input.get_action_strength(&"throttle")
	command.brake = Input.get_action_strength(&"brake")
	command.drift = Input.is_action_pressed(&"drift")
	command.use_item = Input.is_action_just_pressed(&"use_item")
	return command
