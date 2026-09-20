extends GutTest

## La carte d'entrées est écrite par tools/setup_input_map.gd, pas à la main.
## Ces tests la relisent : une liaison manette perdue ne se voit pas au clavier,
## et c'est exactement le genre de régression qui ne se découvre qu'une manette
## en main, trois semaines plus tard.

const ACTIONS := [
	"steer_left", "steer_right", "throttle", "brake", "drift", "use_item",
]

## -1 = toutes les manettes. Godot compare ce champ : à 0 — sa valeur par
## défaut — l'action ne répond qu'à la manette d'index 0, donc plus du tout
## après une reconnexion ou dès qu'une seconde manette prend cet index.
const TOUTES_LES_MANETTES := -1


func _evenements(action: String) -> Array[InputEvent]:
	return InputMap.action_get_events(action)


func _manette(action: String) -> Array[InputEvent]:
	var trouves: Array[InputEvent] = []
	for e in _evenements(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			trouves.append(e)
	return trouves


func test_toutes_les_actions_de_pilotage_sont_declarees() -> void:
	for action in ACTIONS:
		assert_true(InputMap.has_action(action), "action manquante : %s" % action)


func test_chaque_action_a_au_moins_une_liaison() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		assert_gt(_evenements(action).size(), 0,
			"l'action %s n'a aucune liaison" % action)


func test_chaque_action_se_joue_au_clavier() -> void:
	for action in ACTIONS:
		var touches := 0
		for e in _evenements(action):
			if e is InputEventKey:
				touches += 1
		assert_gt(touches, 0,
			"l'action %s n'est pas jouable sans manette branchée" % action)


func test_chaque_action_se_joue_a_la_manette() -> void:
	for action in ACTIONS:
		assert_gt(_manette(action).size(), 0,
			"l'action %s n'a aucune liaison manette" % action)


func test_les_liaisons_manette_acceptent_toutes_les_manettes() -> void:
	for action in ACTIONS:
		for e in _manette(action):
			assert_eq(e.device, TOUTES_LES_MANETTES,
				"la liaison manette de %s est limitée au périphérique %d : "
				% [action, e.device]
				+ "elle cessera de répondre dès que la manette changera d'index")


func test_accelerer_et_deraper_ne_partagent_pas_de_bouton() -> void:
	# Disposition Mario Kart : A accélère, R1 dérape. Les mettre sur le même
	# bouton rendrait le dérapage injouable, puisqu'on accélère en permanence.
	var boutons_gaz := {}
	for e in _manette("throttle"):
		if e is InputEventJoypadButton:
			boutons_gaz[e.button_index] = true
	for e in _manette("drift"):
		if e is InputEventJoypadButton:
			assert_false(boutons_gaz.has(e.button_index),
				"le bouton %d accélère et dérape à la fois" % e.button_index)


func test_les_gaz_et_le_frein_sont_analogiques_a_la_manette() -> void:
	# Les gâchettes rendent une valeur continue, et KartMotor s'en sert :
	# get_action_strength module l'accélération et le freinage.
	for action in ["throttle", "brake"]:
		var axes := 0
		for e in _manette(action):
			if e is InputEventJoypadMotion:
				axes += 1
		assert_gt(axes, 0,
			"l'action %s doit avoir une gâchette analogique, pas qu'un bouton" % action)
