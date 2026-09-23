class_name UITheme
extends RefCounted

## Un seul thème pour tous les écrans : menu, pause, résultats, options.
## Construit en code pour ne pas dépendre d'un .tres qu'il faudrait retoucher
## dans l'éditeur à chaque nuance. Les boutons sont gros exprès : ils doivent
## se toucher au pouce sur un téléphone.

const ACCENT := Color(1.0, 0.78, 0.18)
const FOND := Color(0.07, 0.08, 0.11, 0.92)
const TEXTE := Color(0.95, 0.96, 0.98)
const TEXTE_DOUX := Color(0.70, 0.73, 0.80)

static var _cache: Theme


static func theme() -> Theme:
	if _cache != null:
		return _cache
	var t := Theme.new()
	t.default_font_size = 26

	t.set_color("font_color", "Label", TEXTE)
	t.set_color("font_color", "Button", TEXTE)
	t.set_color("font_hover_color", "Button", Color.BLACK)
	t.set_color("font_focus_color", "Button", Color.BLACK)
	t.set_color("font_pressed_color", "Button", Color.BLACK)
	t.set_color("font_disabled_color", "Button", TEXTE_DOUX)

	t.set_stylebox("normal", "Button", _boite(Color(0.18, 0.2, 0.26)))
	t.set_stylebox("hover", "Button", _boite(ACCENT.lerp(Color.WHITE, 0.15)))
	t.set_stylebox("focus", "Button", _boite(ACCENT))
	t.set_stylebox("pressed", "Button", _boite(ACCENT.darkened(0.2)))
	t.set_stylebox("disabled", "Button", _boite(Color(0.14, 0.15, 0.18)))

	for type in ["OptionButton"]:
		t.set_stylebox("normal", type, _boite(Color(0.18, 0.2, 0.26)))
		t.set_stylebox("hover", type, _boite(Color(0.26, 0.28, 0.35)))
		t.set_stylebox("focus", type, _boite(Color(0.26, 0.28, 0.35), ACCENT))
		t.set_stylebox("pressed", type, _boite(Color(0.26, 0.28, 0.35)))
		t.set_color("font_color", type, TEXTE)
		t.set_color("font_hover_color", type, TEXTE)
		t.set_color("font_focus_color", type, TEXTE)
		t.set_color("font_pressed_color", type, TEXTE)

	# Un interrupteur n'est pas un bouton : son état se lit sur la pastille,
	# pas sur un fond jaune qui le ferait passer pour sélectionné.
	var ligne := _boite(Color(1, 1, 1, 0.04))
	var ligne_survol := _boite(Color(1, 1, 1, 0.09))
	for etat in ["normal", "pressed", "disabled"]:
		t.set_stylebox(etat, "CheckButton", ligne)
	for etat in ["hover", "hover_pressed"]:
		t.set_stylebox(etat, "CheckButton", ligne_survol)
	t.set_stylebox("focus", "CheckButton", _boite(Color.TRANSPARENT, ACCENT))
	for couleur in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(couleur, "CheckButton", TEXTE)
	t.set_color("font_hover_color", "CheckButton", ACCENT)
	t.set_color("font_focus_color", "CheckButton", ACCENT)

	t.set_stylebox("panel", "PanelContainer", _boite(FOND, Color(1, 1, 1, 0.08), 16, 18))
	t.set_stylebox("slider", "HSlider", _boite(Color(0.25, 0.27, 0.33), Color.TRANSPARENT, 4, 4))
	t.set_stylebox("grabber_area", "HSlider", _boite(ACCENT, Color.TRANSPARENT, 4, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _boite(ACCENT.lerp(Color.WHITE, 0.2), Color.TRANSPARENT, 4, 4))
	t.set_stylebox("focus", "HSlider", _boite(Color.TRANSPARENT, ACCENT, 4, 2))

	t.set_stylebox("normal", "LineEdit", _boite(Color(0.12, 0.13, 0.17), Color(1, 1, 1, 0.15), 8, 10))
	t.set_stylebox("focus", "LineEdit", _boite(Color.TRANSPARENT, ACCENT, 8, 10))
	t.set_color("font_color", "LineEdit", TEXTE)
	t.set_color("font_placeholder_color", "LineEdit", TEXTE_DOUX.darkened(0.3))
	t.set_color("caret_color", "LineEdit", ACCENT)

	t.set_font_size("font_size", "PopupMenu", 26)
	_cache = t
	return t


static func _boite(couleur: Color, bordure: Color = Color.TRANSPARENT,
		rayon: int = 10, marge: int = 14) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = couleur
	b.set_corner_radius_all(rayon)
	b.content_margin_left = marge * 1.4
	b.content_margin_right = marge * 1.4
	b.content_margin_top = marge * 0.7
	b.content_margin_bottom = marge * 0.7
	if bordure.a > 0.0:
		b.set_border_width_all(3)
		b.border_color = bordure
	return b


static func titre(texte: String, taille: int = 56) -> Label:
	var l := Label.new()
	l.text = texte
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", ACCENT)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l


static func bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(320, 60)
	b.pressed.connect(action)
	return b


## Un panneau centré à l'écran, contenant une colonne. Rend la colonne.
static func panneau_centre(parent: Control, largeur: float = 560.0) -> VBoxContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(centre)
	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(largeur, 0)
	centre.add_child(panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	panneau.add_child(colonne)
	return colonne
