class_name AideCommandes
extends Control

## L'aide des commandes : au premier lancement (GameSettings.aide_vue), puis
## depuis l'écran des astuces. Une ligne par action, ses touches au clavier
## et à la manette telles qu'elles sont réglées (lues dans l'InputMap : une
## touche changée dans les options s'y voit aussitôt).

signal ferme

## Pour chaque action : ce qu'elle fait, et ce qu'on en dit en plus.
const ACTIONS := [
	[&"throttle", "Accélérer", ""],
	[&"brake", "Freiner, reculer", ""],
	[&"steer_left", "Tourner à gauche", ""],
	[&"steer_right", "Tourner à droite", ""],
	[&"drift", "Sauter, déraper", "en l'air : une figure, et un turbo à l'atterrissage"],
	[&"use_item", "Lancer l'objet", "maintenir : le garder derrière soi ; sans objet : klaxon"],
	[&"pause", "Pause", ""],
]

var _grille: GridContainer
var _compris: Button


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var colonne := UITheme.panneau_defilant(self, 1040.0)
	colonne.add_child(UITheme.titre("COMMANDES", 36))
	var chapeau := Label.new()
	chapeau.text = "Clavier ou manette, comme vous voulez — les deux marchent en même temps."
	chapeau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapeau.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapeau.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	chapeau.add_theme_font_size_override("font_size", 20)
	colonne.add_child(chapeau)

	_grille = GridContainer.new()
	_grille.columns = 3
	_grille.add_theme_constant_override("h_separation", 28)
	_grille.add_theme_constant_override("v_separation", 10)
	colonne.add_child(_grille)

	if GameSettings.tactile_actif():
		var tactile := Label.new()
		tactile.text = "Au doigt : le joystick ou les flèches à gauche pour tourner, les boutons à droite pour sauter et lancer l'objet."
		tactile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tactile.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
		tactile.add_theme_font_size_override("font_size", 19)
		colonne.add_child(tactile)

	var options := Label.new()
	options.text = "Pour changer une touche : Options › Changer les touches."
	options.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	options.add_theme_font_size_override("font_size", 19)
	colonne.add_child(options)

	_compris = UITheme.bouton("C'est parti !", _fermer)
	_compris.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(_compris)
	visibility_changed.connect(func() -> void:
		if visible:
			_remplir()
			_compris.grab_focus())
	_remplir()


func _remplir() -> void:
	if _grille == null:
		return
	for enfant in _grille.get_children():
		enfant.free()
	for titre in ["", "Clavier", "Manette"]:
		_cellule(titre, UITheme.ACCENT, 22)
	for ligne in ACTIONS:
		var action: StringName = ligne[0]
		var quoi := str(ligne[1])
		if str(ligne[2]) != "":
			quoi += "\n" + str(ligne[2])
		_cellule(quoi, UITheme.TEXTE, 20)
		_cellule(touches(action, Touches.Famille.CLAVIER), UITheme.TEXTE_DOUX, 20)
		_cellule(touches(action, Touches.Famille.MANETTE), UITheme.TEXTE_DOUX, 20)


## Les touches d'une action pour une famille d'appareils, lisibles :
## « Flèche haut · Z ».
static func touches(action: StringName, famille: int) -> String:
	if not InputMap.has_action(action):
		return "—"
	var noms := PackedStringArray()
	for e in InputMap.action_get_events(action):
		if Touches.famille(e) == famille:
			noms.append(AstucesPanel.nom_de_l_evenement(e).trim_prefix("Manette "))
	return " · ".join(noms) if not noms.is_empty() else "—"


func _cellule(texte: String, couleur: Color, taille: int) -> void:
	var l := Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300.0 if _grille.get_child_count() % 3 == 0 else 220.0
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_font_size_override("font_size", taille)
	_grille.add_child(l)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		_fermer()


func _fermer() -> void:
	if not GameSettings.aide_vue:
		GameSettings.aide_vue = true
		GameSettings.valider()
	hide()
	ferme.emit()
