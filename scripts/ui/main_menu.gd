extends Control

## Menu principal : l'accueil, le choix de la course et les options. Trois
## écrans dans une seule scène — changer de scène pour un menu ferait
## recharger le fond à chaque clic.

var _accueil: Control
var _selection: Control
var _options: OptionsPanel
var _multi: MultiplayerPanel

var _boutons_piste: Array[Button] = []
var _description: Label
var _record: Label
var _tours: OptionButton
var _depart: OptionButton
var _demarrer: Button


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond()
	_accueil = _ecran_accueil()
	_selection = _ecran_selection()
	_options = OptionsPanel.new()
	add_child(_options)
	_options.ferme.connect(_montrer.bind(_accueil))
	_multi = MultiplayerPanel.new()
	add_child(_multi)
	_multi.ferme.connect(_montrer.bind(_accueil))
	# De retour d'une course en réseau : on revient droit au salon.
	_montrer(_multi if Reseau.actif() else _accueil)


func _fond() -> void:
	var degrade := Gradient.new()
	degrade.set_color(0, Color(0.10, 0.16, 0.30))
	degrade.set_color(1, Color(0.02, 0.03, 0.06))
	var texture := GradientTexture2D.new()
	texture.gradient = degrade
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var fond := TextureRect.new()
	fond.texture = texture
	fond.stretch_mode = TextureRect.STRETCH_SCALE
	fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fond)


func _montrer(ecran: Control) -> void:
	for e in [_accueil, _selection, _options, _multi]:
		e.visible = e == ecran
	# Le focus clavier/manette : sans lui, un joueur à la manette ne peut rien
	# faire dans le menu.
	if ecran == _accueil:
		(_accueil.find_child("Jouer", true, false) as Button).grab_focus()
	elif ecran == _selection:
		_demarrer.grab_focus()


func _ecran_accueil() -> Control:
	var ecran := Control.new()
	ecran.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ecran)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ecran.add_child(centre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 18)
	centre.add_child(colonne)

	colonne.add_child(UITheme.titre("SUPERKART", 96))
	var sous_titre := Label.new()
	sous_titre.text = "Course de karts"
	sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sous_titre.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	colonne.add_child(sous_titre)
	colonne.add_child(_espace(24))

	# Une lambda et non _montrer.bind(_selection) : l'écran de sélection est
	# construit après celui-ci, bind aurait capturé null.
	var jouer := UITheme.bouton("Jouer", func() -> void: _montrer(_selection))
	jouer.name = "Jouer"
	jouer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(jouer)
	var multi := UITheme.bouton("Multijoueur", func() -> void: _montrer(_multi))
	multi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(multi)
	var options := UITheme.bouton("Options", func() -> void: _montrer(_options))
	options.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(options)
	# Sur mobile et sur le web, quitter est l'affaire du système.
	if not (OS.has_feature("mobile") or OS.has_feature("web")):
		var quitter := UITheme.bouton("Quitter", func() -> void: get_tree().quit())
		quitter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		colonne.add_child(quitter)
	return ecran


func _ecran_selection() -> Control:
	var ecran := Control.new()
	ecran.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ecran)
	var colonne := UITheme.panneau_centre(ecran, 760.0)
	colonne.add_child(UITheme.titre("CHOIX DE LA COURSE", 40))

	var reglage := GameSettings.course
	var groupe := ButtonGroup.new()
	var liste := HFlowContainer.new()
	liste.add_theme_constant_override("h_separation", 12)
	colonne.add_child(liste)
	for piste in TrackCatalog.PISTES:
		var b := Button.new()
		b.text = piste.nom
		b.toggle_mode = true
		b.button_group = groupe
		b.custom_minimum_size = Vector2(300, 72)
		b.button_pressed = piste == reglage.piste
		b.pressed.connect(_choisir_piste.bind(piste))
		liste.add_child(b)
		_boutons_piste.append(b)

	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_description.add_theme_font_size_override("font_size", 22)
	_description.custom_minimum_size = Vector2(0, 60)
	colonne.add_child(_description)

	_tours = OptionButton.new()
	for n in range(1, 6):
		_tours.add_item("%d tour%s" % [n, "s" if n > 1 else ""], n)
	_tours.item_selected.connect(func(i: int) -> void:
		reglage.tours = _tours.get_item_id(i)
		_rafraichir_record())
	colonne.add_child(_ligne("Nombre de tours", _tours))

	_depart = OptionButton.new()
	_depart.add_item("Tirée au sort", RaceSetup.CASE_ALEATOIRE)
	for n in range(1, RaceSetup.CONCURRENTS + 1):
		var texte := "%s case" % RaceScoring.ordinal(n)
		if n == 1:
			texte = "1re case (pole position)"
		elif n == RaceSetup.CONCURRENTS:
			texte += " (fond de grille)"
		_depart.add_item(texte, n)
	_depart.item_selected.connect(func(i: int) -> void:
		reglage.case_de_depart = _depart.get_item_id(i))
	_depart.select(_depart.get_item_index(reglage.case_de_depart))
	colonne.add_child(_ligne("Position de départ", _depart))

	_record = Label.new()
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record.add_theme_color_override("font_color", UITheme.ACCENT)
	colonne.add_child(_record)

	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 16)
	var retour := UITheme.bouton("Retour", _montrer.bind(_accueil))
	retour.custom_minimum_size.x = 220
	boutons.add_child(retour)
	_demarrer = UITheme.bouton("Démarrer !", func() -> void:
		RaceLauncher.lancer(get_tree(), GameSettings.course))
	_demarrer.custom_minimum_size.x = 260
	boutons.add_child(_demarrer)
	colonne.add_child(boutons)

	_choisir_piste(reglage.piste, reglage.tours)
	return ecran


func _choisir_piste(piste: TrackInfo, tours: int = 0) -> void:
	if piste == null:
		_demarrer.disabled = true
		return
	var reglage := GameSettings.course
	reglage.choisir_piste(piste)
	if tours > 0:
		reglage.tours = tours
	_description.text = piste.description
	_tours.select(_tours.get_item_index(reglage.tours))
	_rafraichir_record()


func _rafraichir_record() -> void:
	var reglage := GameSettings.course
	var meilleur := GameSettings.record(reglage.piste.id, reglage.tours)
	if meilleur > 0.0:
		_record.text = "Record : %s" % RaceTimer.format(meilleur)
	else:
		_record.text = "Pas encore de record en %d tour%s" % [reglage.tours, "s" if reglage.tours > 1 else ""]


func _unhandled_input(event: InputEvent) -> void:
	if _selection.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_montrer(_accueil)


func _ligne(texte: String, controle: Control) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(etiquette)
	controle.custom_minimum_size = Vector2(340, 0)
	ligne.add_child(controle)
	return ligne


func _espace(hauteur: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hauteur)
	return c
