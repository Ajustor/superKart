class_name TouchesPanel
extends Control

## L'écran « Changer les touches » des options : une ligne par action, deux
## boutons pour le clavier (les flèches et les lettres, rangées par position
## physique : ZQSD sur un AZERTY, WASD sur un QWERTY), un pour la manette. On
## clique, on appuie sur la nouvelle touche, c'est enregistré. Échap annule
## l'attente.

signal ferme

## Un axe de manette ne compte qu'enfoncé franchement : un stick au repos
## tremble toujours un peu.
const SEUIL_AXE := 0.6

var _boutons: Dictionary = {}
var _action: StringName = &""
var _famille := -1
var _rang := 0
## [famille, rang] de chaque colonne de boutons, de gauche à droite.
const COLONNES := [[Touches.Famille.CLAVIER, 0], [Touches.Famille.CLAVIER, 1], [Touches.Famille.MANETTE, 0]]
var _retour: Button


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var colonne := UITheme.panneau_defilant(self, 1100.0)
	colonne.add_child(UITheme.titre("TOUCHES", 36))
	var disposition := Touches.disposition()
	if disposition != "":
		var l := Label.new()
		l.text = "Clavier détecté : %s — les touches s'affichent telles qu'elles sont écrites dessus." % disposition
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
		l.add_theme_font_size_override("font_size", 20)
		colonne.add_child(l)

	var grille := GridContainer.new()
	grille.columns = 1 + COLONNES.size()
	grille.add_theme_constant_override("h_separation", 18)
	grille.add_theme_constant_override("v_separation", 8)
	colonne.add_child(grille)
	for texte in ["", "Clavier", "Clavier (2)", "Manette"]:
		var l := Label.new()
		l.text = texte
		l.add_theme_color_override("font_color", UITheme.ACCENT)
		grille.add_child(l)
	for action in Touches.ACTIONS:
		var l := Label.new()
		l.text = AstucesPanel.ACTIONS.get(action, String(action))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grille.add_child(l)
		var ligne := []
		for c in COLONNES:
			var b := Button.new()
			b.custom_minimum_size = Vector2(230, 0)
			b.pressed.connect(attendre.bind(action, c[0], c[1]))
			grille.add_child(b)
			ligne.append(b)
		_boutons[action] = ligne

	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", 16)
	colonne.add_child(bas)
	bas.add_child(UITheme.bouton("Réinitialiser", func() -> void:
		_annuler()
		GameSettings.reinitialiser_touches()
		_relire()))
	_retour = UITheme.bouton("Retour", _fermer)
	bas.add_child(_retour)

	visibility_changed.connect(func() -> void:
		if visible:
			_annuler()
			_relire()
			_retour.grab_focus())
	_relire()


## Le bouton de cette action et de cette famille attend la prochaine touche.
func attendre(action: StringName, famille: int, rang: int = 0) -> void:
	_annuler()
	_action = action
	_famille = famille
	_rang = rang
	_bouton(action, famille, rang).text = "Appuyez…" if famille == Touches.Famille.CLAVIER else "Bouton ou gâchette…"


func en_attente() -> bool:
	return _action != &""


func _input(event: InputEvent) -> void:
	if not visible or not en_attente():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_annuler()
		return
	if event is InputEventMouseButton and event.pressed:
		# Un clic ailleurs (ou un doigt, sur un écran tactile) : on renonce.
		_annuler()
		return
	var capte := capturer(event, _famille)
	if capte == null:
		return
	get_viewport().set_input_as_handled()
	var action := _action
	var rang := _rang
	_action = &""
	_famille = -1
	GameSettings.changer_touche(action, capte, rang)
	_relire()


## L'événement réduit à ce qu'on enregistre, s'il convient à cette famille ;
## null sinon (un relâchement, une touche pour la manette, un stick effleuré).
static func capturer(event: InputEvent, famille: int) -> InputEvent:
	match famille:
		Touches.Famille.CLAVIER:
			if event is InputEventKey and event.pressed and not event.echo:
				var k := event as InputEventKey
				var nouveau := InputEventKey.new()
				nouveau.physical_keycode = k.physical_keycode if k.physical_keycode != 0 else k.keycode
				return nouveau
		Touches.Famille.MANETTE:
			if event is InputEventJoypadButton and event.pressed:
				var b := InputEventJoypadButton.new()
				b.button_index = (event as InputEventJoypadButton).button_index
				return b
			if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > SEUIL_AXE:
				var m := InputEventJoypadMotion.new()
				m.axis = (event as InputEventJoypadMotion).axis
				m.axis_value = signf((event as InputEventJoypadMotion).axis_value)
				return m
	return null


func _unhandled_input(event: InputEvent) -> void:
	if visible and not en_attente() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_fermer()


func _annuler() -> void:
	_action = &""
	_famille = -1
	_relire()


func _relire() -> void:
	for action in _boutons:
		for c in COLONNES:
			var e := Touches.nieme(action, c[0], c[1])
			_bouton(action, c[0], c[1]).text = AstucesPanel.nom_de_l_evenement(e) if e != null else "—"


func _bouton(action: StringName, famille: int, rang: int = 0) -> Button:
	return _boutons[action][COLONNES.find([famille, rang])]


func _fermer() -> void:
	_annuler()
	hide()
	ferme.emit()
