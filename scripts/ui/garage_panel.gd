class_name GaragePanel
extends Control

## Le garage : le kart du joueur, monté en trois pièces (carrosserie, roues,
## aileron), sa couleur et le pilote assis dedans. Les jauges suivent la
## combinaison. Le choix s'enregistre aussitôt, comme les options, et part à
## l'hôte si l'on est dans un salon.

signal ferme

const SCENE_KART := "res://scenes/kart/kart.tscn"

## Les trois pièces, dans l'ordre : leur nom affiché et leur bouton ▶.
const PIECES := ["Carrosserie", "Roues", "Aileron"]
var _noms_pieces: Array[Label] = []
var _suivants: Array[Button] = []
## La pièce changée en dernier : c'est elle que décrit la ligne du dessous.
var _derniere_piece := 0
var _boutons_couleur: Array[Button] = []
var _description: Label
var _jauges: Jauges
var _vitrine: Node3D
var _retour: Button
var _nom_pilote: Label
var _origine_pilote: Label


## Les caractéristiques du modèle, en barres.
class Jauges:
	extends Control
	var valeurs := PackedFloat32Array()

	func _init() -> void:
		custom_minimum_size = Vector2(380, 30.0 * ModeleKart.JAUGES.size())

	func _draw() -> void:
		var police := ThemeDB.fallback_font
		for i in ModeleKart.JAUGES.size():
			var y := 30.0 * i
			draw_string(police, Vector2(0, y + 21), ModeleKart.JAUGES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 19,
				UITheme.TEXTE_DOUX)
			var cadre := Rect2(Vector2(150, y + 8), Vector2(size.x - 150, 14))
			draw_rect(cadre, Color(1, 1, 1, 0.12))
			if i < valeurs.size():
				draw_rect(Rect2(cadre.position, Vector2(cadre.size.x * valeurs[i], cadre.size.y)), UITheme.ACCENT)


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var colonne := UITheme.panneau_defilant(self, 1000.0)
	colonne.add_child(UITheme.titre("GARAGE", 36))

	var milieu := HBoxContainer.new()
	milieu.add_theme_constant_override("separation", 24)
	colonne.add_child(milieu)
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", 6)
	milieu.add_child(gauche)
	gauche.add_child(_apercu())
	# Le pilote : on fait défiler la galerie, flèche par flèche.
	var pilote := HBoxContainer.new()
	pilote.alignment = BoxContainer.ALIGNMENT_CENTER
	pilote.add_theme_constant_override("separation", 10)
	gauche.add_child(pilote)
	var precedent := UITheme.bouton("◀", _changer_pilote.bind(-1))
	precedent.custom_minimum_size = Vector2(70, 56)
	pilote.add_child(precedent)
	_nom_pilote = Label.new()
	_nom_pilote.custom_minimum_size.x = 260
	_nom_pilote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nom_pilote.add_theme_color_override("font_color", UITheme.ACCENT)
	pilote.add_child(_nom_pilote)
	var suivant := UITheme.bouton("▶", _changer_pilote.bind(1))
	suivant.custom_minimum_size = Vector2(70, 56)
	pilote.add_child(suivant)
	_origine_pilote = Label.new()
	_origine_pilote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_origine_pilote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_origine_pilote.custom_minimum_size.x = 440
	_origine_pilote.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_origine_pilote.add_theme_font_size_override("font_size", 18)
	gauche.add_child(_origine_pilote)

	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.add_theme_constant_override("separation", 10)
	milieu.add_child(droite)
	for p in PIECES.size():
		droite.add_child(_selecteur(p))
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(380, 52)
	_description.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	droite.add_child(_description)
	_jauges = Jauges.new()
	droite.add_child(_jauges)

	var couleurs := HBoxContainer.new()
	couleurs.alignment = BoxContainer.ALIGNMENT_CENTER
	couleurs.add_theme_constant_override("separation", 10)
	colonne.add_child(couleurs)
	for i in ModeleKart.COULEURS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		b.tooltip_text = ModeleKart.NOMS_COULEURS[i]
		b.toggle_mode = true
		for etat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			var boite := StyleBoxFlat.new()
			boite.bg_color = ModeleKart.couleur(i)
			boite.set_corner_radius_all(28)
			var choisi: bool = etat == "pressed" or etat == "hover_pressed"
			boite.set_border_width_all(4 if choisi or etat == "focus" else 0)
			boite.border_color = Color.WHITE if choisi else UITheme.ACCENT
			b.add_theme_stylebox_override(etat, boite)
		b.pressed.connect(_choisir_couleur.bind(i))
		couleurs.add_child(b)
		_boutons_couleur.append(b)

	_retour = UITheme.bouton("Retour", func() -> void:
		hide()
		ferme.emit())
	_retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(_retour)
	visibility_changed.connect(func() -> void:
		if visible:
			_relire()
			_suivants[0].grab_focus())
	_relire()


func _process(delta: float) -> void:
	if visible and _vitrine != null:
		_vitrine.rotate_y(0.6 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()
		ferme.emit()


## Le kart qui tourne sur lui-même, dans un monde à lui.
func _apercu() -> Control:
	var cadre := SubViewportContainer.new()
	cadre.custom_minimum_size = Vector2(440, 270)
	cadre.stretch = true
	var vue := SubViewport.new()
	vue.own_world_3d = true
	vue.transparent_bg = true
	vue.msaa_3d = Viewport.MSAA_4X
	cadre.add_child(vue)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.25, 2.9)
	camera.rotation_degrees = Vector3(-17, 0, 0)
	camera.fov = 45.0
	vue.add_child(camera)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, 30, 0)
	vue.add_child(soleil)
	var ambiance := WorldEnvironment.new()
	ambiance.environment = Environment.new()
	ambiance.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiance.environment.ambient_light_color = Color(0.6, 0.65, 0.75)
	ambiance.environment.background_mode = Environment.BG_CLEAR_COLOR
	vue.add_child(ambiance)
	_vitrine = Node3D.new()
	_vitrine.rotation_degrees.y = 35.0
	vue.add_child(_vitrine)
	# Seulement la caisse et les roues : le kart entier se mettrait à rouler,
	# à écouter les commandes et à faire du bruit.
	var kart := (load(SCENE_KART) as PackedScene).instantiate()
	for nom in ["Body", "Wheels"]:
		var partie := kart.get_node_or_null(nom)
		if partie != null:
			kart.remove_child(partie)
			partie.owner = null
			_vitrine.add_child(partie)
	var etincelles := _vitrine.get_node_or_null("Body/Sparks")
	if etincelles != null:
		etincelles.free()
	kart.free()
	return cadre


## Une ligne « Carrosserie  ◀ Fusée ▶ ».
func _selecteur(piece: int) -> Control:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 8)
	var titre := Label.new()
	titre.text = PIECES[piece]
	titre.custom_minimum_size.x = 150
	titre.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	ligne.add_child(titre)
	var precedent := UITheme.bouton("◀", _changer_piece.bind(piece, -1))
	precedent.custom_minimum_size = Vector2(60, 50)
	ligne.add_child(precedent)
	var nom_piece := Label.new()
	nom_piece.custom_minimum_size.x = 200
	nom_piece.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Une largeur fixe : les flèches restent alignées d'une ligne à l'autre.
	nom_piece.clip_text = true
	nom_piece.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nom_piece.add_theme_color_override("font_color", UITheme.ACCENT)
	ligne.add_child(nom_piece)
	_noms_pieces.append(nom_piece)
	var suivant := UITheme.bouton("▶", _changer_piece.bind(piece, 1))
	suivant.custom_minimum_size = Vector2(60, 50)
	ligne.add_child(suivant)
	_suivants.append(suivant)
	return ligne


func _relire() -> void:
	var reglage := GameSettings.course
	for i in _boutons_couleur.size():
		_boutons_couleur[i].set_pressed_no_signal(i == reglage.couleur)
	var pieces := [ModeleKart.modele(reglage.modele), ModeleKart.roues(reglage.roues),
		ModeleKart.aileron(reglage.aileron)]
	for p in pieces.size():
		_noms_pieces[p].text = pieces[p].nom
	_description.text = "%s : %s" % [pieces[_derniere_piece].nom, pieces[_derniere_piece].description]
	_jauges.valeurs = ModeleKart.jauges(reglage.modele, reglage.roues, reglage.aileron)
	_jauges.queue_redraw()
	ModeleKart.habiller(_vitrine, reglage.modele, ModeleKart.couleur(reglage.couleur), reglage.roues,
		reglage.aileron)
	Personnage.habiller(_vitrine, reglage.personnage)
	_nom_pilote.text = Personnage.nom(reglage.personnage)
	_origine_pilote.text = "D'après : %s" % Personnage.origine(reglage.personnage)


func _changer_pilote(pas: int) -> void:
	GameSettings.course.personnage = posmod(GameSettings.course.personnage + pas, Personnage.nombre())
	_enregistrer()


func _changer_piece(piece: int, pas: int) -> void:
	var reglage := GameSettings.course
	match piece:
		0: reglage.modele = posmod(reglage.modele + pas, ModeleKart.nombre())
		1: reglage.roues = posmod(reglage.roues + pas, ModeleKart.nombre_roues())
		2: reglage.aileron = posmod(reglage.aileron + pas, ModeleKart.nombre_ailerons())
	_derniere_piece = piece
	_enregistrer()


func _choisir_couleur(i: int) -> void:
	GameSettings.course.couleur = i
	_enregistrer()


func _enregistrer() -> void:
	GameSettings.valider()
	Reseau.annoncer_vehicule()
	_relire()
