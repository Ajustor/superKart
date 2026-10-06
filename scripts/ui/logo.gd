class_name Logo
extends Control

## Le logo de l'écran d'accueil, dessiné : « SUPER » blanc et « KART » jaune,
## penchés vers l'avant comme lancés, cerclés de noir, sur un damier de
## drapeau d'arrivée.

const ITALIQUE := 0.22
const TAILLE := 92
## Les cases du damier, en pixels.
const CASE := 14.0

var _police: FontVariation


func _init() -> void:
	custom_minimum_size = Vector2(600, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_police = FontVariation.new()
	_police.base_font = ThemeDB.fallback_font
	_police.variation_embolden = 1.1
	_police.spacing_glyph = 2


func _draw() -> void:
	var mot_1 := "SUPER"
	var mot_2 := "KART"
	var l_super := _police.get_string_size(mot_1, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE).x
	var l_kart := _police.get_string_size(mot_2, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE).x
	var ecart := 14.0
	var largeur := l_super + ecart + l_kart
	var ligne := size.y * 0.66
	var gauche := (size.x - largeur) * 0.5

	# Le damier, deux rangées, sous les lettres et un peu plus large qu'elles.
	var bande := Rect2(gauche - 30.0, ligne - 4.0, largeur + 60.0, CASE * 2.0)
	_damier(bande)

	# Les lettres penchées : un cisaillement autour de la ligne de base.
	draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-ITALIQUE, 1), Vector2(ITALIQUE * ligne, 0)))
	_mot(mot_1, Vector2(gauche, ligne), Color(0.97, 0.97, 1.0))
	_mot(mot_2, Vector2(gauche + l_super + ecart, ligne), UITheme.ACCENT)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _mot(texte: String, ou: Vector2, couleur: Color) -> void:
	# Une ombre décalée, un trait noir épais, puis la lettre.
	draw_string_outline(_police, ou + Vector2(5, 6), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE, 18,
		Color(0, 0, 0, 0.45))
	draw_string_outline(_police, ou, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE, 16, Color(0.06, 0.06, 0.1))
	draw_string(_police, ou, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE, couleur)


func _damier(cadre: Rect2) -> void:
	draw_rect(cadre.grow(3.0), Color(0.06, 0.06, 0.1))
	var colonnes := int(cadre.size.x / CASE)
	for rangee in 2:
		for c in colonnes:
			var carre := Rect2(cadre.position + Vector2(c * CASE, rangee * CASE), Vector2(CASE, CASE))
			draw_rect(carre, Color.WHITE if (c + rangee) % 2 == 0 else Color(0.12, 0.12, 0.16))
