class_name PodiumScreen
extends Control

## La fin d'une coupe : les trois premiers sur le podium, le classement
## complet à côté, et ce que le joueur remporte.

const COULEURS := [Color(1.0, 0.8, 0.2), Color(0.8, 0.83, 0.88), Color(0.8, 0.5, 0.25)]
const HAUTEURS := [190.0, 140.0, 100.0]
const MEDAILLES := ["Trophée d'or", "Trophée d'argent", "Trophée de bronze"]

var _titre: Label
var _message: Label
var _marches: HBoxContainer
var _liste: GridContainer
var _menu: Button


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.55)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(voile)

	var colonne := UITheme.panneau_centre(self, 900.0)
	_titre = UITheme.titre("", 40)
	colonne.add_child(_titre)

	var milieu := HBoxContainer.new()
	milieu.add_theme_constant_override("separation", 40)
	milieu.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_child(milieu)
	_marches = HBoxContainer.new()
	_marches.alignment = BoxContainer.ALIGNMENT_CENTER
	_marches.add_theme_constant_override("separation", 8)
	_marches.custom_minimum_size = Vector2(480, 300)
	milieu.add_child(_marches)
	_liste = GridContainer.new()
	_liste.columns = 3
	_liste.add_theme_constant_override("h_separation", 20)
	_liste.add_theme_constant_override("v_separation", 0)
	milieu.add_child(_liste)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 30)
	_message.add_theme_color_override("font_color", UITheme.ACCENT)
	colonne.add_child(_message)

	_menu = UITheme.bouton("Menu principal", _sortir)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(_menu)


## En réseau, l'hôte ramène tout le monde au salon ; les autres peuvent
## partir sans l'attendre.
func _sortir() -> void:
	if Reseau.actif():
		if Reseau.est_hote():
			Reseau.retour_salon()
		else:
			Reseau.abandonner()
		return
	GameSettings.course.mode = RaceSetup.Mode.COURSE
	GameSettings.course.grand_prix = null
	RaceLauncher.retour_au_menu(get_tree())


## `nouveaute` : ce que ce trophée vient de débloquer, s'il y a lieu.
func montrer(gp: GrandPrix, moi: String, nouveaute: String = "") -> void:
	if Reseau.actif():
		_menu.text = "Retour au salon" if Reseau.est_hote() else "Quitter la partie"
	var classement := gp.classement()
	_titre.text = "%s  ·  %s" % [gp.nom().to_upper(), Cylindree.nom(gp.classe)]

	for enfant in _marches.get_children():
		enfant.free()
	# Deuxième, premier, troisième : le premier au milieu, le plus haut.
	for rang in [1, 0, 2]:
		if rang < classement.size():
			_marches.add_child(_marche(rang, classement[rang], int(gp.points[classement[rang]]), classement[rang] == moi))

	for enfant in _liste.get_children():
		enfant.free()
	for i in classement.size():
		var couleur := UITheme.ACCENT if classement[i] == moi else UITheme.TEXTE
		_cellule(RaceScoring.ordinal(i + 1), couleur)
		_cellule(classement[i], couleur)
		_cellule("%d pts" % int(gp.points[classement[i]]), couleur)

	var place := gp.place_de(moi)
	if place == 1:
		_message.text = "Vous remportez la %s ! %s" % [gp.nom(), MEDAILLES[0]]
	elif place >= 2 and place <= 3:
		_message.text = "%s place : %s" % [RaceScoring.ordinal(place), MEDAILLES[place - 1].to_lower()]
	else:
		_message.text = "Vous terminez %s. Le podium, ce sera pour la prochaine fois !" % RaceScoring.ordinal(place)
	if nouveaute != "":
		_message.text += "\n" + nouveaute
	show()
	_menu.grab_focus()


func _marche(rang: int, nom: String, points: int, joueur: bool) -> Control:
	var pile := VBoxContainer.new()
	pile.alignment = BoxContainer.ALIGNMENT_END
	pile.custom_minimum_size = Vector2(150, 300)
	pile.add_theme_constant_override("separation", 4)
	var etiquette := Label.new()
	etiquette.text = nom
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette.add_theme_color_override("font_color", UITheme.ACCENT if joueur else UITheme.TEXTE)
	etiquette.add_theme_font_size_override("font_size", 26)
	pile.add_child(etiquette)
	var socle := ColorRect.new()
	socle.color = COULEURS[rang]
	socle.custom_minimum_size = Vector2(150, 0)
	var numero := Label.new()
	numero.text = "%d\n%d pts" % [rang + 1, points]
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numero.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	numero.add_theme_font_size_override("font_size", 24)
	numero.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	socle.add_child(numero)
	pile.add_child(socle)
	# Les marches montent l'une après l'autre : le troisième, le deuxième,
	# puis le premier.
	var montee := socle.create_tween()
	montee.tween_interval(0.3 + 0.35 * float(2 - rang))
	montee.tween_property(socle, "custom_minimum_size:y", HAUTEURS[rang], 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return pile


func _cellule(texte: String, couleur: Color) -> void:
	var l := Label.new()
	l.text = texte
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_font_size_override("font_size", 22)
	_liste.add_child(l)
