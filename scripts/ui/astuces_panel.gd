class_name AstucesPanel
extends Control

## Les astuces de l'écran de chargement, toutes à la fois, et les commandes
## telles qu'elles sont réglées (lues dans l'InputMap : une touche changée
## dans les options s'y voit aussitôt).

signal ferme

const ACTIONS := {
	&"throttle": "Accélérer",
	&"brake": "Freiner / reculer",
	&"steer_left": "Tourner à gauche",
	&"steer_right": "Tourner à droite",
	&"drift": "Sauter / déraper / figure",
	&"use_item": "Utiliser l'objet",
	&"pause": "Pause",
}

## Godot nomme les touches en anglais.
const NOMS_DE_TOUCHES := {
	"Up": "Flèche haut", "Down": "Flèche bas", "Left": "Flèche gauche", "Right": "Flèche droite",
	"Space": "Espace", "Ctrl": "Ctrl", "Escape": "Échap", "Enter": "Entrée", "Shift": "Maj",
	"Tab": "Tab", "Backspace": "Retour arrière",
}

var _commandes: GridContainer


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var colonne := UITheme.panneau_centre(self, 980.0)
	colonne.add_child(UITheme.titre("ASTUCES", 36))

	var defilement := ScrollContainer.new()
	defilement.custom_minimum_size = Vector2(0, 430)
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	colonne.add_child(defilement)
	var contenu := VBoxContainer.new()
	contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenu.add_theme_constant_override("separation", 8)
	defilement.add_child(contenu)

	for astuce in EcranChargement.ASTUCES:
		var l := Label.new()
		l.text = "• " + str(astuce)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 20)
		contenu.add_child(l)

	var titre := Label.new()
	titre.text = "Commandes"
	titre.add_theme_color_override("font_color", UITheme.ACCENT)
	titre.add_theme_font_size_override("font_size", 24)
	contenu.add_child(titre)
	_commandes = GridContainer.new()
	_commandes.columns = 2
	_commandes.add_theme_constant_override("h_separation", 24)
	contenu.add_child(_commandes)

	var retour := UITheme.bouton("Retour", func() -> void: ferme.emit())
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(retour)
	visibility_changed.connect(_remplir_commandes)
	_remplir_commandes()


func _remplir_commandes() -> void:
	if not visible or _commandes == null:
		return
	for enfant in _commandes.get_children():
		enfant.free()
	for action in ACTIONS:
		_cellule(ACTIONS[action], UITheme.TEXTE)
		_cellule(texte_des_touches(action), UITheme.TEXTE_DOUX)


## Les liaisons d'une action, lisibles : « Espace · RB ».
static func texte_des_touches(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var noms := PackedStringArray()
	for e in InputMap.action_get_events(action):
		noms.append(nom_de_l_evenement(e))
	return " · ".join(noms)


static func nom_de_l_evenement(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		var nom := OS.get_keycode_string(code)
		return NOMS_DE_TOUCHES.get(nom, nom)
	if e is InputEventJoypadButton:
		return "Manette %s" % _bouton((e as InputEventJoypadButton).button_index)
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		match m.axis:
			JOY_AXIS_TRIGGER_LEFT: return "Manette LT"
			JOY_AXIS_TRIGGER_RIGHT: return "Manette RT"
			JOY_AXIS_LEFT_X: return "Stick " + ("gauche" if m.axis_value < 0.0 else "droite")
			JOY_AXIS_LEFT_Y: return "Stick " + ("haut" if m.axis_value < 0.0 else "bas")
		return "Manette axe %d" % m.axis
	return e.as_text()


static func _bouton(b: int) -> String:
	match b:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_BACK: return "Select"
		JOY_BUTTON_DPAD_LEFT: return "croix ←"
		JOY_BUTTON_DPAD_RIGHT: return "croix →"
		JOY_BUTTON_DPAD_UP: return "croix ↑"
		JOY_BUTTON_DPAD_DOWN: return "croix ↓"
	return "bouton %d" % b


func _cellule(texte: String, couleur: Color) -> void:
	var l := Label.new()
	l.text = texte
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_font_size_override("font_size", 20)
	_commandes.add_child(l)
