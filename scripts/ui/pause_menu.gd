class_name PauseMenu
extends Control

## Met la course en pause : Échap, Start, ou le bouton en haut à droite pour
## ceux qui n'ont que leurs doigts. Tourne pendant la pause, forcément — c'est
## lui qui la lève.

@export var session_path: NodePath

var _session: RaceSession
var _voile: ColorRect
var _menu: Control
var _options: OptionsPanel
var _bouton_pause: Button
var _reprendre: Button

## Coupée quand l'écran de résultats s'affiche : il a ses propres boutons.
var disponible: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_session = get_node_or_null(session_path) as RaceSession

	_bouton_pause = Button.new()
	_bouton_pause.text = "II"
	_bouton_pause.focus_mode = Control.FOCUS_NONE
	_bouton_pause.custom_minimum_size = Vector2(72, 72)
	_bouton_pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_bouton_pause.position += Vector2(-88, 16)
	_bouton_pause.pressed.connect(ouvrir)
	add_child(_bouton_pause)

	_voile = ColorRect.new()
	_voile.color = Color(0, 0, 0, 0.55)
	_voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_voile)

	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var colonne := UITheme.panneau_centre(_menu, 460.0)
	colonne.add_child(UITheme.titre("PAUSE", 48))
	_reprendre = UITheme.bouton("Reprendre", fermer)
	colonne.add_child(_reprendre)
	colonne.add_child(UITheme.bouton("Recommencer", func() -> void:
		RaceLauncher.lancer(get_tree(), GameSettings.course)))
	colonne.add_child(UITheme.bouton("Options", func() -> void:
		_menu.hide()
		_options.show()))
	colonne.add_child(UITheme.bouton("Menu principal", func() -> void:
		RaceLauncher.retour_au_menu(get_tree())))

	_options = OptionsPanel.new()
	add_child(_options)
	_options.ferme.connect(func() -> void:
		_menu.show()
		_reprendre.grab_focus())

	_voile.hide()
	_menu.hide()
	_options.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if _options.visible:
		return  # l'écran d'options se ferme lui-même
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		fermer()
	else:
		ouvrir()


func ouvrir() -> void:
	if not disponible or get_tree().paused:
		return
	get_tree().paused = true
	_bouton_pause.hide()
	_voile.show()
	_menu.show()
	_reprendre.grab_focus()


func fermer() -> void:
	get_tree().paused = false
	_voile.hide()
	_menu.hide()
	_options.hide()
	_bouton_pause.visible = disponible


func rendre_indisponible() -> void:
	disponible = false
	_bouton_pause.hide()
