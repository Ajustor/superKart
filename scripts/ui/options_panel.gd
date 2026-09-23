class_name OptionsPanel
extends Control

## L'écran d'options, partagé par le menu principal et la pause. Chaque geste
## s'applique et s'enregistre aussitôt : pas de bouton « Appliquer » qu'on
## oublie, et le volume se règle en entendant le résultat.

signal ferme

var _general: HSlider
var _effets: HSlider
var _musique: HSlider
var _coupe: CheckButton
var _tactile: OptionButton
var _auto: CheckButton
var _vibrations: CheckButton
var _mini_carte: CheckButton
var _fps: CheckButton
var _qualite: OptionButton
var _joystick: CheckButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	var colonne := UITheme.panneau_centre(self, 1080.0)
	colonne.add_child(UITheme.titre("OPTIONS", 38))
	# Deux colonnes : sur un téléphone tenu en paysage, une seule dépassait
	# du bas de l'écran.
	var colonnes := HBoxContainer.new()
	colonnes.add_theme_constant_override("separation", 36)
	colonne.add_child(colonnes)
	var gauche := VBoxContainer.new()
	var droite := VBoxContainer.new()
	for c in [gauche, droite]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 10)
		colonnes.add_child(c)

	gauche.add_child(_intertitre("Son"))
	_general = _curseur(gauche, "Volume général")
	_effets = _curseur(gauche, "Effets et moteur")
	_musique = _curseur(gauche, "Musique")
	_coupe = _interrupteur(gauche, "Couper le son")

	gauche.add_child(_intertitre("Affichage"))
	_qualite = _liste(gauche, "Qualité graphique", {
		"Automatique": QualiteGraphique.Niveau.AUTO, "Haute": QualiteGraphique.Niveau.HAUTE,
		"Moyenne": QualiteGraphique.Niveau.MOYENNE, "Basse": QualiteGraphique.Niveau.BASSE})
	_mini_carte = _interrupteur(gauche, "Mini-carte")
	_fps = _interrupteur(gauche, "Compteur de FPS")

	droite.add_child(_intertitre("Commandes"))
	_tactile = _liste(droite, "Commandes tactiles", {
		"Automatique": GameSettings.Tactile.AUTO, "Toujours": GameSettings.Tactile.TOUJOURS,
		"Jamais": GameSettings.Tactile.JAMAIS})
	_joystick = _interrupteur(droite, "Direction au joystick (tactile)")
	_auto = _interrupteur(droite, "Accélération automatique (tactile)")
	_vibrations = _interrupteur(droite, "Vibrations de la manette")

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
	_musique.value_changed.connect(func(v: float) -> void:
		GameSettings.volume_musique = v
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
	_mini_carte.toggled.connect(func(v: bool) -> void:
		GameSettings.mini_carte = v
		GameSettings.valider())
	_joystick.toggled.connect(func(v: bool) -> void:
		GameSettings.joystick = v
		GameSettings.valider())
	_qualite.item_selected.connect(func(i: int) -> void:
		GameSettings.qualite = _qualite.get_item_id(i)
		GameSettings.valider())
	_fps.toggled.connect(func(v: bool) -> void:
		GameSettings.afficher_fps = v
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
	_musique.set_value_no_signal(GameSettings.volume_musique)
	_coupe.set_pressed_no_signal(GameSettings.son_coupe)
	_tactile.select(_tactile.get_item_index(GameSettings.tactile))
	_auto.set_pressed_no_signal(GameSettings.acceleration_auto)
	_vibrations.set_pressed_no_signal(GameSettings.vibrations)
	_mini_carte.set_pressed_no_signal(GameSettings.mini_carte)
	_fps.set_pressed_no_signal(GameSettings.afficher_fps)
	_joystick.set_pressed_no_signal(GameSettings.joystick)
	_qualite.select(_qualite.get_item_index(GameSettings.qualite))


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


## Une ligne « intitulé … liste déroulante ». `choix` : texte → identifiant.
func _liste(colonne: VBoxContainer, texte: String, choix: Dictionary) -> OptionButton:
	var ligne := HBoxContainer.new()
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(etiquette)
	var liste := OptionButton.new()
	for nom in choix:
		liste.add_item(nom, choix[nom])
	liste.custom_minimum_size = Vector2(210, 0)
	ligne.add_child(liste)
	colonne.add_child(ligne)
	return liste


func _interrupteur(colonne: VBoxContainer, texte: String) -> CheckButton:
	var b := CheckButton.new()
	b.text = texte
	colonne.add_child(b)
	return b
