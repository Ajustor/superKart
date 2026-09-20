extends SceneTree

## Écrit le bloc [input] de project.godot via l'API du moteur.
## Lancer après toute modification de ce fichier :
##   godot --headless --script tools/setup_input_map.gd
##
## Disposition manette calquée sur celle d'un Mario Kart, parce que c'est la
## seule que les mains connaissent déjà : A accélère, B freine, la gâchette
## droite accélère aussi en analogique, R1 dérape, L1 lance l'objet.
##
## Chaque action garde une liaison clavier ET une liaison manette : le jeu doit
## rester jouable sans manette branchée, et testable en headless.

const DEADZONE := 0.2

## Godot compare le champ `device` d'un événement de la carte d'entrées.
## Laissé à 0 — sa valeur par défaut — l'action ne répondait qu'à la manette
## d'index 0, donc plus du tout après une reconnexion, un dongle, ou dès qu'une
## seconde manette prenait l'index 0. -1 est le « toutes les manettes » que la
## case correspondante de l'éditeur coche.
const TOUTES_LES_MANETTES := -1


func _init() -> void:
	_action("steer_left", [
		_touche(KEY_LEFT), _axe(JOY_AXIS_LEFT_X, -1.0), _bouton(JOY_BUTTON_DPAD_LEFT)])
	_action("steer_right", [
		_touche(KEY_RIGHT), _axe(JOY_AXIS_LEFT_X, 1.0), _bouton(JOY_BUTTON_DPAD_RIGHT)])
	_action("throttle", [
		_touche(KEY_UP), _axe(JOY_AXIS_TRIGGER_RIGHT, 1.0), _bouton(JOY_BUTTON_A)])
	_action("brake", [
		_touche(KEY_DOWN), _axe(JOY_AXIS_TRIGGER_LEFT, 1.0), _bouton(JOY_BUTTON_B)])
	# R1 et non A : A accélère désormais, et déraper avec le pouce qui tient les
	# gaz est précisément ce qu'aucun jeu de kart ne demande.
	_action("drift", [
		_touche(KEY_SPACE), _bouton(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("use_item", [
		_touche(KEY_CTRL), _bouton(JOY_BUTTON_LEFT_SHOULDER), _bouton(JOY_BUTTON_X)])

	var err := ProjectSettings.save()
	if err != OK:
		printerr("échec de l'écriture de project.godot : %d" % err)
		quit(1)
		return
	print("input map écrite")
	quit()


func _action(action: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": DEADZONE,
		"events": events,
	})


func _touche(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _axe(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var motion := InputEventJoypadMotion.new()
	motion.device = TOUTES_LES_MANETTES
	motion.axis = axis
	motion.axis_value = value
	return motion


func _bouton(button: JoyButton) -> InputEventJoypadButton:
	var press := InputEventJoypadButton.new()
	press.device = TOUTES_LES_MANETTES
	press.button_index = button
	return press
