class_name RaceHUD
extends Control

## Trois informations, pas une de plus : le tour, le chrono, le meilleur temps.
## Le palier de mini-turbo n'y figure pas — c'est la couleur des étincelles qui
## le dit, et le joueur ne doit pas avoir à quitter la route des yeux.

@export var session_path: NodePath

var _session: RaceSession
var _label: Label


func _ready() -> void:
	_session = get_node(session_path) as RaceSession
	assert(_session != null, "session_path doit pointer vers une RaceSession")

	_label = Label.new()
	_label.position = Vector2(24, 16)
	_label.add_theme_font_size_override("font_size", 28)
	add_child(_label)


func _process(_delta: float) -> void:
	var tour := mini(_session.progress.lap + 1, _session.lap_count)
	var lignes := PackedStringArray()
	lignes.append("TOUR %d/%d" % [tour, _session.lap_count])
	lignes.append(RaceTimer.format(_session.timer.current))
	if _session.timer.has_best:
		lignes.append("MEILLEUR %s" % RaceTimer.format(_session.timer.best))
	if _session.finished:
		lignes.append("ARRIVÉE")
	_label.text = "\n".join(lignes)
