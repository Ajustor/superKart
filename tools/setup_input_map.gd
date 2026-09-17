extends SceneTree

## Écrit le bloc [input] de project.godot via l'API du moteur.
## Lancer une seule fois :
##   godot --headless --script tools/setup_input_map.gd
## `use_item` ne sert qu'à partir du plan 3, mais on le déclare maintenant
## pour ne pas rouvrir ce fichier.

const DEADZONE := 0.2


func _init() -> void:
	_axis_action("steer_left", KEY_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_axis_action("steer_right", KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_axis_action("throttle", KEY_UP, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis_action("brake", KEY_DOWN, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button_action("drift", KEY_SPACE, JOY_BUTTON_A)
	_button_action("use_item", KEY_CTRL, JOY_BUTTON_X)

	var err := ProjectSettings.save()
	if err != OK:
		printerr("échec de l'écriture de project.godot : %d" % err)
		quit(1)
		return
	print("input map écrite")
	quit()


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _axis_action(action: String, keycode: Key, axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": DEADZONE,
		"events": [_key(keycode), motion],
	})


func _button_action(action: String, keycode: Key, button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": DEADZONE,
		"events": [_key(keycode), press],
	})
