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
	# Disposition classique des jeux de kart : A accélère, R1 dérape. Les mettre sur le même
	# bouton rendrait le dérapage injouable, puisqu'on accélère en permanence.
	var boutons_gaz := {}
	for e in _manette("throttle"):
		if e is InputEventJoypadButton:
			boutons_gaz[e.button_index] = true
	for e in _manette("drift"):
		if e is InputEventJoypadButton:
			assert_false(boutons_gaz.has(e.button_index),
				"le bouton %d accélère et dérape à la fois" % e.button_index)


func test_deraper_et_lancer_un_objet_sont_sur_les_gachettes() -> void:
	# Disposition classique des jeux de kart : la gâchette droite fait sauter puis déraper, la
	# gauche lance l'objet. Les gaz occupent le pouce droit en permanence, donc
	# tout ce qui se déclenche en virage doit tomber sous un index.
	var attendu := {
		"drift": JOY_AXIS_TRIGGER_RIGHT,
		"use_item": JOY_AXIS_TRIGGER_LEFT,
	}
	for action in attendu:
		var axes: Array[int] = []
		for e in _manette(action):
			if e is InputEventJoypadMotion:
				axes.append(e.axis)
		assert_true(axes.has(attendu[action]),
			"l'action %s doit être sur la gâchette %d, trouvé %s"
			% [action, attendu[action], str(axes)])


func test_les_gachettes_sont_doublees_par_leur_tranche() -> void:
	# R et ZR font tous deux déraper sur une manette Nintendo ; on garde cette
	# tolérance, parce que toutes les manettes n'exposent pas leurs gâchettes
	# comme des axes analogiques.
	var attendu := {
		"drift": JOY_BUTTON_RIGHT_SHOULDER,
		"use_item": JOY_BUTTON_LEFT_SHOULDER,
	}
	for action in attendu:
		var boutons: Array[int] = []
		for e in _manette(action):
			if e is InputEventJoypadButton:
				boutons.append(e.button_index)
		assert_true(boutons.has(attendu[action]),
			"l'action %s devrait aussi répondre à la tranche %d, trouvé %s"
			% [action, attendu[action], str(boutons)])


func test_les_gaz_ne_squattent_aucune_gachette() -> void:
	# Le jour où les gaz reviendraient sur une gâchette, ils y écraseraient le
	# dérapage ou l'objet sans que rien ne le signale.
	var gachettes := [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
	for action in ["throttle", "brake"]:
		# Relevé puis comparé en bloc : une boucle qui n'iterait sur rien
		# passerait sans lever la moindre assertion, et GUT a raison d'appeler
		# ça un test à risque.
		var occupees: Array[int] = []
		for e in _manette(action):
			if e is InputEventJoypadMotion and gachettes.has(e.axis):
				occupees.append(e.axis)
		assert_eq(occupees, [] as Array[int],
			"l'action %s occupe %s, réservé au saut et à l'objet" % [action, str(occupees)])
