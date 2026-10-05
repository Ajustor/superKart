class_name JournalPanel
extends Control

## Le journal de la partie précédente, à lire et à copier : quand le jeu
## s'est fermé d'un coup, ses dernières lignes disent où il en était.

signal ferme

var _texte: TextEdit
var _retour: Button


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var colonne := UITheme.panneau_centre(self, 1100.0)
	colonne.add_child(UITheme.titre("JOURNAL", 36))
	var chapeau := Label.new()
	chapeau.text = "La fin du journal de la partie précédente. Si le jeu s'est fermé d'un coup, « Copier » puis envoyez-le : ses dernières lignes disent où il en était."
	chapeau.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapeau.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	chapeau.add_theme_font_size_override("font_size", 19)
	colonne.add_child(chapeau)
	_texte = TextEdit.new()
	_texte.editable = false
	_texte.custom_minimum_size = Vector2(0, 380)
	_texte.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_texte.add_theme_font_size_override("font_size", 15)
	colonne.add_child(_texte)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", 16)
	colonne.add_child(bas)
	bas.add_child(UITheme.bouton("Copier", func() -> void: DisplayServer.clipboard_set(_texte.text)))
	_retour = UITheme.bouton("Retour", func() -> void: ferme.emit())
	bas.add_child(_retour)
	visibility_changed.connect(func() -> void:
		if visible:
			_texte.text = Journal.fin_du_journal_precedent()
			_texte.scroll_vertical = _texte.get_line_count()
			_retour.grab_focus())
