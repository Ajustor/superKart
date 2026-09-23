extends CanvasLayer

## Le compteur de performances, par-dessus tout le reste : menus, course,
## pause. Déclaré en autoload (`PerfOverlay`) et affiché selon le réglage
## Options → Affichage → Compteur de FPS.
##
## Une ligne, en haut au milieu : images par seconde, durée moyenne et pire
## durée d'image sur la dernière seconde, à-coups depuis l'affichage, temps de
## physique et appels de dessin. Vert à 55 images par seconde et plus, orange
## à partir de 30, rouge en dessous.

const VERT := Color(0.45, 1.0, 0.5)
const ORANGE := Color(1.0, 0.72, 0.25)
const ROUGE := Color(1.0, 0.35, 0.3)

var mesure := MesureImages.new()
var _texte: Label
var _derniere := 0
var _depuis_affichage := 0.0


func _ready() -> void:
	layer = 100
	# Il compte aussi pendant la pause : c'est là qu'on règle la qualité.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fond := PanelContainer.new()
	fond.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	fond.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fond.position.y = 4.0
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	fond.add_theme_stylebox_override("panel", style)
	_texte = Label.new()
	_texte.add_theme_font_size_override("font_size", 18)
	_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(_texte)
	add_child(fond)
	_suivre_le_reglage()
	GameSettings.changed.connect(_suivre_le_reglage)


func _suivre_le_reglage() -> void:
	var avant := visible
	visible = GameSettings.afficher_fps
	if visible and not avant:
		mesure.remettre_a_zero()
		_derniere = 0


func _process(_delta: float) -> void:
	if not visible:
		return
	# L'horloge réelle, pas delta : delta est borné et lissé par le moteur,
	# un gel de 300 ms n'y apparaît pas en entier.
	var maintenant := Time.get_ticks_usec()
	if _derniere > 0:
		mesure.ajouter((maintenant - _derniere) / 1000.0)
	_derniere = maintenant
	# Réécrire le texte à chaque image coûterait plus que ce qu'il mesure.
	_depuis_affichage += _delta
	if _depuis_affichage < 0.25:
		return
	_depuis_affichage = 0.0
	var fps := mesure.images_par_seconde()
	_texte.text = "%d FPS  ·  %.1f ms (pire %.0f)  ·  à-coups %d  ·  physique %.1f ms  ·  %d dessins" % [
		roundi(fps), mesure.duree_moyenne(), mesure.pire(), mesure.a_coups,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
	_texte.add_theme_color_override("font_color", VERT if fps >= 55.0 else (ORANGE if fps >= 30.0 else ROUGE))
