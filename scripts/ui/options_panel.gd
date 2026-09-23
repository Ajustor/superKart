class_name OptionsPanel
extends Control

## L'écran d'options, partagé par le menu principal et la pause. Chaque geste
## s'applique et s'enregistre aussitôt : pas de bouton « Appliquer » qu'on
## oublie, et le volume se règle en entendant le résultat.

signal ferme

var _general: HSlider
var _effets: HSlider
var _coupe: CheckButton
var _tactile: OptionButton
var _auto: CheckButton
var _vibrations: CheckButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	var colonne := UITheme.panneau_centre(self, 620.0)
	colonne.add_child(UITheme.titre("OPTIONS", 38))

	colonne.add_child(_intertitre("Son"))
	_general = _curseur(colonne, "Volume général")
	_effets = _curseur(colonne, "Effets et moteur")
	_coupe = _interrupteur(colonne, "Couper le son")

	colonne.add_child(_intertitre("Commandes"))
	var ligne := HBoxContainer.new()
	var etiquette := Label.new()
	etiquette.text = "Commandes tactiles"
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(etiquette)
	_tactile = OptionButton.new()
	_tactile.add_item("Automatique", GameSettings.Tactile.AUTO)
	_tactile.add_item("Toujours", GameSettings.Tactile.TOUJOURS)
	_tactile.add_item("Jamais", GameSettings.Tactile.JAMAIS)
	_tactile.custom_minimum_size = Vector2(230, 0)
	ligne.add_child(_tactile)
	colonne.add_child(ligne)
	_auto = _interrupteur(colonne, "Accélération automatique (tactile)")
	_vibrations = _interrupteur(colonne, "Vibrations de la manette")

	var retour := UITheme.bouton("Retour", _fermer)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(retour)

	_relire()
	_general.value_changed.connect(func(v: float) -> void:
		GameSettings.volume_general = v
		GameSettings.valider())
	_effets.value_changed.connect(func(v: float) -> void:
		GameSettings.volume_effets = v
		GameSettings.valider())
	_coupe.toggled.connect(func(v: bool) -> void:
		GameSettings.son_coupe = v
		GameSettings.valider())
	_tactile.item_selected.connect(func(i: int) -> void:
		GameSettings.tactile = _tactile.get_item_id(i)
		GameSettings.valider())
	_auto.toggled.connect(func(v: bool) -> void:
		GameSettings.acceleration_auto = v
		GameSettings.valider())
	_vibrations.toggled.connect(func(v: bool) -> void:
		GameSettings.vibrations = v
		GameSettings.valider())
	visibility_changed.connect(_sur_visibilite)


func _sur_visibilite() -> void:
	if visible:
		_relire()
		_general.grab_focus()


## Remet les contrôles sur les valeurs enregistrées, sans rien réécrire.
func _relire() -> void:
	_general.set_value_no_signal(GameSettings.volume_general)
	_effets.set_value_no_signal(GameSettings.volume_effets)
	_coupe.set_pressed_no_signal(GameSettings.son_coupe)
	_tactile.select(_tactile.get_item_index(GameSettings.tactile))
	_auto.set_pressed_no_signal(GameSettings.acceleration_auto)
	_vibrations.set_pressed_no_signal(GameSettings.vibrations)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		_fermer()


func _fermer() -> void:
	hide()
	ferme.emit()


func _intertitre(texte: String) -> Label:
	var l := Label.new()
	l.text = texte.to_upper()
	l.add_theme_color_override("font_color", UITheme.ACCENT)
	l.add_theme_font_size_override("font_size", 22)
	return l


func _curseur(colonne: VBoxContainer, texte: String) -> HSlider:
	var ligne := HBoxContainer.new()
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(etiquette)
	var curseur := HSlider.new()
	curseur.min_value = 0.0
	curseur.max_value = 1.0
	curseur.step = 0.05
	curseur.custom_minimum_size = Vector2(230, 40)
	curseur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(curseur)
	colonne.add_child(ligne)
	return curseur


func _interrupteur(colonne: VBoxContainer, texte: String) -> CheckButton:
	var b := CheckButton.new()
	b.text = texte
	colonne.add_child(b)
	return b
