class_name Touches
extends RefCounted

## Les commandes que le joueur a changées : les décrire pour les enregistrer,
## les recréer au lancement, et remplacer une touche par une autre.
##
## Deux familles par action, qu'on change séparément : le clavier, et la
## manette (bouton ou axe). Changer l'une ne touche pas à l'autre.

## Les actions de jeu qu'on peut changer, dans l'ordre de l'écran.
const ACTIONS: Array[StringName] = [&"throttle", &"brake", &"steer_left", &"steer_right",
	&"drift", &"use_item", &"pause"]

enum Famille { CLAVIER, MANETTE }


static func famille(e: InputEvent) -> int:
	return Famille.CLAVIER if e is InputEventKey else Famille.MANETTE


## Un événement réduit à ce qui s'enregistre dans un ConfigFile.
static func decrire(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		var k := e as InputEventKey
		return {type = "touche", code = k.physical_keycode if k.physical_keycode != 0 else k.keycode}
	if e is InputEventJoypadButton:
		return {type = "bouton", index = (e as InputEventJoypadButton).button_index}
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		return {type = "axe", axe = m.axis, sens = signf(m.axis_value)}
	return {}


static func creer(d: Dictionary) -> InputEvent:
	match str(d.get("type", "")):
		"touche":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.code) as Key
			return k
		"bouton":
			var b := InputEventJoypadButton.new()
			b.button_index = int(d.index) as JoyButton
			return b
		"axe":
			var m := InputEventJoypadMotion.new()
			m.axis = int(d.axe) as JoyAxis
			m.axis_value = float(d.sens)
			return m
	return null


## Les commandes du projet, puis celles que le joueur a changées.
static func appliquer(changees: Dictionary) -> void:
	InputMap.load_from_project_settings()
	for action in changees:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for d in changees[action]:
			var e := creer(d)
			if e != null:
				InputMap.action_add_event(action, e)


## Les événements d'une action, décrits : ce qu'on enregistre après un
## changement.
static func decrire_action(action: StringName) -> Array:
	var liste := []
	for e in InputMap.action_get_events(action):
		var d := decrire(e)
		if not d.is_empty():
			liste.append(d)
	return liste


## Deux événements qui désignent la même touche, le même bouton ou le même
## sens du même axe.
static func identiques(a: InputEvent, b: InputEvent) -> bool:
	return decrire(a) == decrire(b)


## Combien d'emplacements par famille l'écran des touches propose : deux au
## clavier (les flèches et les lettres), un à la manette.
const EMPLACEMENTS := {Famille.CLAVIER: 2, Famille.MANETTE: 1}


## Remplace, dans `action`, le `rang`-ième événement de la même famille que
## `nouveau` (ou l'ajoute s'il n'y en a pas autant). La même touche est retirée
## des autres actions de jeu, et des autres emplacements de celle-ci : une
## touche, une action. Rend les actions changées.
static func remplacer(action: StringName, nouveau: InputEvent, rang: int = 0) -> Array[StringName]:
	var changees: Array[StringName] = [action]
	for autre in ACTIONS:
		if autre == action:
			continue
		for e in InputMap.action_get_events(autre):
			if identiques(e, nouveau):
				InputMap.action_erase_event(autre, e)
				changees.append(autre)
	var evenements := InputMap.action_get_events(action)
	var vise := -1
	var vus := 0
	for i in evenements.size():
		if famille(evenements[i]) == famille(nouveau):
			if vus == rang:
				vise = i
			vus += 1
	InputMap.action_erase_events(action)
	for i in evenements.size():
		if i == vise:
			InputMap.action_add_event(action, nouveau)
		elif not identiques(evenements[i], nouveau):
			InputMap.action_add_event(action, evenements[i])
	if vise < 0:
		InputMap.action_add_event(action, nouveau)
	return changees


## Le `rang`-ième événement de cette famille dans l'action, ou null.
static func nieme(action: StringName, quelle: int, rang: int) -> InputEvent:
	var vus := 0
	for e in InputMap.action_get_events(action):
		if famille(e) == quelle:
			if vus == rang:
				return e
			vus += 1
	return null


## Ce qui est écrit sur la touche à cette position, selon la disposition du
## clavier du joueur : les touches se rangent par position physique (celle du
## W d'un clavier QWERTY est le Z d'un AZERTY), et s'affichent sous leur vrai
## nom. Rend le code tel quel si le système ne sait pas le dire.
static func touche_affichee(physique: Key) -> Key:
	if DisplayServer.get_name() == "headless":
		return physique
	var etiquette := DisplayServer.keyboard_get_label_from_physical(physique)
	return etiquette if etiquette != KEY_NONE else physique


## La disposition du clavier détectée, pour l'écran des touches : « French »,
## « English (US) »… Vide si le système ne la donne pas.
static func disposition() -> String:
	if DisplayServer.get_name() == "headless" or DisplayServer.keyboard_get_layout_count() <= 0:
		return ""
	var courante := DisplayServer.keyboard_get_current_layout()
	var nom := DisplayServer.keyboard_get_layout_name(courante)
	if nom == "":
		nom = DisplayServer.keyboard_get_layout_language(courante).to_upper()
	return nom


## Le premier événement de cette famille dans l'action, ou null.
static func premier(action: StringName, quelle: int) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if famille(e) == quelle:
			return e
	return null
