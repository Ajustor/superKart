extends Control

## Menu principal : l'accueil, le choix de la course et les options. Trois
## écrans dans une seule scène — changer de scène pour un menu ferait
## recharger le fond à chaque clic.

var _accueil: Control
var _selection: Control
var _options: OptionsPanel
var _multi: MultiplayerPanel
var _astuces: AstucesPanel
var _garage: GaragePanel
## L'écran d'où l'on est venu au garage : l'accueil ou le salon.
var _avant_garage: Control

const NOMS_MODES := {
	RaceSetup.Mode.GRAND_PRIX: "Grand Prix",
	RaceSetup.Mode.COURSE: "Course libre",
	RaceSetup.Mode.CONTRE_LA_MONTRE: "Contre-la-montre",
	RaceSetup.Mode.BATAILLE: "Bataille",
}

var _boutons_piste: Array[Button] = []
var _boutons_arene: Array[Button] = []
var _boutons_mode: Dictionary = {}
var _boutons_coupe: Array[Button] = []
var _coupe: int = 0
var _classe: OptionButton
var _miroir: CheckButton
var _coupes: GridContainer
var _circuits: GridContainer
var _reglages: HBoxContainer
var _description: Label
var _record: Label
var _tours: OptionButton
var _depart: OptionButton
var _demarrer: Button
var _bandeau_maj: PanelContainer
var _texte_maj: Label
var _barre_maj: ProgressBar
var _bouton_maj: Button


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond()
	_version()
	_accueil = _ecran_accueil()
	_bandeau_mise_a_jour(_accueil)
	_selection = _ecran_selection()
	_options = OptionsPanel.new()
	add_child(_options)
	_options.ferme.connect(_montrer.bind(_accueil))
	_multi = MultiplayerPanel.new()
	add_child(_multi)
	_multi.ferme.connect(_montrer.bind(_accueil))
	_astuces = AstucesPanel.new()
	add_child(_astuces)
	_astuces.ferme.connect(_montrer.bind(_accueil))
	_garage = GaragePanel.new()
	add_child(_garage)
	_garage.ferme.connect(func() -> void: _montrer(_avant_garage))
	_multi.garage.connect(_ouvrir_garage.bind(_multi))
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


## Le numéro de version, discret, en bas à gauche : qu'on sache sans
## chercher quelle version on a installée.
func _version() -> void:
	var etiquette := Label.new()
	etiquette.name = "Version"
	etiquette.text = texte_version()
	etiquette.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	etiquette.add_theme_font_size_override("font_size", 16)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	etiquette.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(etiquette)


## « v1.2 », ou « dev » hors de la CI : c'est elle qui inscrit la version
## (application/config/version) dans le jeu qu'elle exporte.
static func texte_version() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if version == "" or version == "dev":
		return "dev"
	return "v" + version


## Un encart en bas à droite de l'accueil quand une nouvelle version existe :
## un bouton la télécharge et l'installe (voir MiseAJour). Caché le reste du
## temps — un jeu à jour n'a rien à dire.
func _bandeau_mise_a_jour(ecran: Control) -> void:
	_bandeau_maj = PanelContainer.new()
	_bandeau_maj.name = "MiseAJour"
	_bandeau_maj.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_bandeau_maj.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_bandeau_maj.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ecran.add_child(_bandeau_maj)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 8)
	_bandeau_maj.add_child(colonne)
	_texte_maj = Label.new()
	_texte_maj.add_theme_color_override("font_color", UITheme.ACCENT)
	_texte_maj.add_theme_font_size_override("font_size", 20)
	_texte_maj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte_maj.custom_minimum_size.x = 340
	_texte_maj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(_texte_maj)
	_barre_maj = ProgressBar.new()
	_barre_maj.max_value = 1.0
	_barre_maj.custom_minimum_size = Vector2(320, 18)
	colonne.add_child(_barre_maj)
	_bouton_maj = UITheme.bouton("Mettre à jour", func() -> void:
		if MiseAJour.etat == Etat.PRET:
			MiseAJour.installer()
		else:
			MiseAJour.mettre_a_jour())
	_bouton_maj.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(_bouton_maj)
	MiseAJour.etat_change.connect(func(_e: int) -> void: _rafraichir_mise_a_jour())
	MiseAJour.progression.connect(func(f: float) -> void: _barre_maj.value = f)
	_rafraichir_mise_a_jour()


const Etat := preload("res://scripts/core/mise_a_jour.gd").Etat


func _rafraichir_mise_a_jour() -> void:
	var etat: int = MiseAJour.etat
	var version: String = MiseAJour.version_disponible
	_bandeau_maj.visible = MiseAJour.mise_a_jour_connue() and etat != Etat.A_JOUR
	_barre_maj.visible = etat == Etat.TELECHARGEMENT
	_bouton_maj.disabled = etat in [Etat.TELECHARGEMENT, Etat.INSTALLATION, Etat.VERIFICATION]
	match etat:
		Etat.DISPONIBLE:
			_texte_maj.text = "Nouvelle version %s disponible !" % version
			_bouton_maj.text = "Mettre à jour" if MiseAJour.installation_automatique() else "Télécharger"
		Etat.TELECHARGEMENT:
			_texte_maj.text = "Téléchargement de la version %s…" % version
		Etat.PRET:
			_texte_maj.text = "Version %s prête à installer" % version
			_bouton_maj.text = "Installer"
		Etat.INSTALLATION:
			_texte_maj.text = "Installation de la version %s…" % version
		Etat.ERREUR:
			_texte_maj.text = "Mise à jour %s : %s" % [version, MiseAJour.erreur]
			_bouton_maj.text = "Réessayer"


func _montrer(ecran: Control) -> void:
	for e in [_accueil, _selection, _options, _multi, _astuces, _garage]:
		e.visible = e == ecran
	# Le focus clavier/manette : sans lui, un joueur à la manette ne peut rien
	# faire dans le menu.
	if ecran == _accueil:
		(_accueil.find_child("Jouer", true, false) as Button).grab_focus()
	elif ecran == _selection:
		_demarrer.grab_focus()


func _ouvrir_garage(depuis: Control) -> void:
	_avant_garage = depuis
	_montrer(_garage)


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
	var garage := UITheme.bouton("Garage", func() -> void: _ouvrir_garage(_accueil))
	garage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(garage)
	var multi := UITheme.bouton("Multijoueur", func() -> void: _montrer(_multi))
	multi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(multi)
	var options := UITheme.bouton("Options", func() -> void: _montrer(_options))
	options.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(options)
	var astuces := UITheme.bouton("Astuces", func() -> void: _montrer(_astuces))
	astuces.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(astuces)
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
	var colonne := UITheme.panneau_centre(ecran, 980.0)
	colonne.add_child(UITheme.titre("CHOIX DE LA COURSE", 34))
	var reglage := GameSettings.course

	# Le mode et la cylindrée, sur une ligne.
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 10)
	colonne.add_child(haut)
	var groupe_modes := ButtonGroup.new()
	for mode in [RaceSetup.Mode.GRAND_PRIX, RaceSetup.Mode.COURSE, RaceSetup.Mode.CONTRE_LA_MONTRE,
			RaceSetup.Mode.BATAILLE]:
		var b := _bascule(NOMS_MODES[mode], groupe_modes, Vector2(160, 56), 19)
		b.pressed.connect(_choisir_mode.bind(mode))
		haut.add_child(b)
		_boutons_mode[mode] = b
	_classe = OptionButton.new()
	for c in Cylindree.NOMS.size():
		_classe.add_item(Cylindree.nom(c), c)
	# La 200cc se gagne : or dans toutes les coupes en 150cc.
	var i200 := _classe.get_item_index(Cylindree.Classe.CC200)
	if not GameSettings.debloque_200cc():
		_classe.set_item_text(i200, "200cc 🔒")
		_classe.set_item_disabled(i200, true)
		if reglage.classe == Cylindree.Classe.CC200:
			reglage.classe = Cylindree.Classe.CC150
	_classe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_classe.item_selected.connect(func(i: int) -> void:
		reglage.classe = _classe.get_item_id(i)
		GameSettings.sauver()
		_rafraichir())
	haut.add_child(_classe)
	# Le miroir se gagne : or dans toutes les coupes en 100cc.
	_miroir = CheckButton.new()
	_miroir.text = "Miroir" if GameSettings.debloque_miroir() else "Miroir 🔒"
	_miroir.disabled = not GameSettings.debloque_miroir()
	if _miroir.disabled:
		reglage.miroir = false
	_miroir.button_pressed = reglage.miroir
	_miroir.add_theme_font_size_override("font_size", 20)
	_miroir.toggled.connect(func(actif: bool) -> void:
		reglage.miroir = actif
		_rafraichir())
	haut.add_child(_miroir)

	# Les coupes, pour le Grand Prix : deux par ligne, pour tenir sur l'écran
	# d'un téléphone en paysage.
	_coupes = GridContainer.new()
	_coupes.columns = 2
	_coupes.add_theme_constant_override("h_separation", 12)
	_coupes.add_theme_constant_override("v_separation", 10)
	var groupe_coupes := ButtonGroup.new()
	for i in TrackCatalog.COUPES.size():
		var b := _bascule("", groupe_coupes, Vector2(470, 104), 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = i == _coupe
		b.pressed.connect(func() -> void:
			_coupe = i
			_rafraichir())
		_coupes.add_child(b)
		_boutons_coupe.append(b)
	colonne.add_child(_coupes)

	# Les circuits, pour une course seule ou le contre-la-montre.
	_circuits = GridContainer.new()
	_circuits.columns = 4
	_circuits.add_theme_constant_override("h_separation", 8)
	_circuits.add_theme_constant_override("v_separation", 8)
	var groupe := ButtonGroup.new()
	for piste in TrackCatalog.PISTES:
		var b := _bascule(piste.nom, groupe, Vector2(234, 52), 19)
		b.button_pressed = piste == reglage.piste
		b.pressed.connect(_choisir_piste.bind(piste))
		_circuits.add_child(b)
		_boutons_piste.append(b)
	# Les arènes, pour la bataille, dans la même grille (même groupe).
	for arene in TrackCatalog.ARENES:
		var b := _bascule(arene.nom, groupe, Vector2(234, 52), 19)
		b.button_pressed = arene == reglage.piste
		b.pressed.connect(_choisir_piste.bind(arene))
		_circuits.add_child(b)
		_boutons_arene.append(b)
	colonne.add_child(_circuits)

	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_description.add_theme_font_size_override("font_size", 20)
	_description.custom_minimum_size = Vector2(0, 52)
	colonne.add_child(_description)

	_tours = OptionButton.new()
	for n in range(1, 6):
		_tours.add_item("%d tour%s" % [n, "s" if n > 1 else ""], n)
	_tours.item_selected.connect(func(i: int) -> void:
		reglage.tours = _tours.get_item_id(i)
		_rafraichir())

	_depart = OptionButton.new()
	_depart.add_item("Case tirée au sort", RaceSetup.CASE_ALEATOIRE)
	for n in range(1, RaceSetup.CONCURRENTS + 1):
		var texte := "%s case" % RaceScoring.ordinal(n)
		if n == 1:
			texte = "1re case (pole)"
		elif n == RaceSetup.CONCURRENTS:
			texte += " (fond)"
		_depart.add_item(texte, n)
	_depart.item_selected.connect(func(i: int) -> void:
		reglage.case_de_depart = _depart.get_item_id(i))
	_depart.select(_depart.get_item_index(reglage.case_de_depart))

	_reglages = HBoxContainer.new()
	_reglages.add_theme_constant_override("separation", 12)
	_tours.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_depart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reglages.add_child(_tours)
	_reglages.add_child(_depart)
	colonne.add_child(_reglages)

	_record = Label.new()
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record.add_theme_color_override("font_color", UITheme.ACCENT)
	_record.add_theme_font_size_override("font_size", 22)
	colonne.add_child(_record)

	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 16)
	var retour := UITheme.bouton("Retour", _montrer.bind(_accueil))
	retour.custom_minimum_size.x = 220
	boutons.add_child(retour)
	_demarrer = UITheme.bouton("Démarrer !", _lancer)
	_demarrer.custom_minimum_size.x = 260
	boutons.add_child(_demarrer)
	colonne.add_child(boutons)

	_classe.select(_classe.get_item_index(reglage.classe))
	# Une coupe laissée en plan (menu principal en pleine manche) ne reprend
	# pas : on revient au choix de la coupe.
	if reglage.mode == RaceSetup.Mode.GRAND_PRIX and reglage.grand_prix != null:
		_coupe = reglage.grand_prix.coupe
		_boutons_coupe[_coupe].button_pressed = true
	_choisir_mode(reglage.mode)
	_choisir_piste(reglage.piste, reglage.tours)
	return ecran


func _bascule(texte: String, groupe: ButtonGroup, taille: Vector2, police: int) -> Button:
	var b := Button.new()
	b.text = texte
	b.toggle_mode = true
	b.button_group = groupe
	b.custom_minimum_size = taille
	b.add_theme_font_size_override("font_size", police)
	return b


func _choisir_mode(mode: RaceSetup.Mode) -> void:
	var reglage := GameSettings.course
	reglage.mode = mode
	_boutons_mode[mode].button_pressed = true
	_coupes.visible = mode == RaceSetup.Mode.GRAND_PRIX
	_circuits.visible = not _coupes.visible
	_classe.visible = mode != RaceSetup.Mode.CONTRE_LA_MONTRE
	_tours.visible = mode == RaceSetup.Mode.COURSE
	var bataille := mode == RaceSetup.Mode.BATAILLE
	# En bataille, les karts partent dispersés dans l'arène : pas de case.
	_depart.visible = mode != RaceSetup.Mode.CONTRE_LA_MONTRE and not bataille
	_miroir.visible = not bataille
	for b in _boutons_piste:
		b.visible = not bataille
	for b in _boutons_arene:
		b.visible = bataille
	# Une arène ne se court pas, un circuit ne se bat pas.
	var est_arene := TrackCatalog.ARENES.has(reglage.piste)
	if bataille and not est_arene:
		_choisir_piste(TrackCatalog.ARENES[0])
		_boutons_arene[0].button_pressed = true
	elif not bataille and est_arene:
		_choisir_piste(TrackCatalog.PISTES[0])
		_boutons_piste[0].button_pressed = true
	if mode == RaceSetup.Mode.CONTRE_LA_MONTRE and reglage.piste != null:
		reglage.tours = reglage.piste.tours
	_rafraichir()


func _choisir_piste(piste: TrackInfo, tours: int = 0) -> void:
	if piste == null:
		_demarrer.disabled = true
		return
	var reglage := GameSettings.course
	reglage.choisir_piste(piste)
	if tours > 0 and reglage.mode == RaceSetup.Mode.COURSE:
		reglage.tours = tours
	_tours.select(_tours.get_item_index(reglage.tours))
	_rafraichir()


func _lancer() -> void:
	var reglage := GameSettings.course
	if reglage.mode == RaceSetup.Mode.GRAND_PRIX:
		reglage.commencer_grand_prix(_coupe)
	RaceLauncher.lancer(get_tree(), reglage)


## Remet à jour tout ce qui dépend du réglage : le texte des coupes, la
## description, le record.
func _rafraichir() -> void:
	var reglage := GameSettings.course
	for i in _boutons_coupe.size():
		var coupe: Dictionary = TrackCatalog.COUPES[i]
		var noms := PackedStringArray()
		for id in coupe.pistes:
			noms.append(TrackCatalog.par_id(id).nom)
		var texte := "%s\n%s" % [coupe.nom, " · ".join(noms)]
		var trophee := GameSettings.trophee(i, reglage.classe)
		if trophee > 0:
			texte += "\n%s en %s" % [PodiumScreen.MEDAILLES[trophee - 1], Cylindree.nom(reglage.classe)]
		_boutons_coupe[i].text = texte
		_boutons_coupe[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	match reglage.mode:
		RaceSetup.Mode.GRAND_PRIX:
			_description.text = "Quatre courses de trois tours contre sept pilotes. Les points s'additionnent, et les trois premiers de la coupe montent sur le podium."
			_record.text = ""
		RaceSetup.Mode.BATAILLE:
			_description.text = "Trois ballons chacun, et chaque objet qui vous touche en crève un. Le dernier en lice gagne ; au bout de %d minutes, on compte les ballons." % int(Bataille.DUREE / 60.0)
			_record.text = ""
		RaceSetup.Mode.CONTRE_LA_MONTRE:
			_description.text = "Seul en piste en 150cc, trois champignons en poche. Battez votre record : votre meilleur parcours revient courir contre vous, en fantôme."
			_rafraichir_record()
		_:
			_description.text = reglage.piste.description if reglage.piste != null else ""
			_rafraichir_record()


func _rafraichir_record() -> void:
	var reglage := GameSettings.course
	if reglage.piste == null:
		_record.text = ""
		return
	var meilleur := GameSettings.record(reglage.cle_record(), reglage.tours)
	var ou := reglage.piste.nom
	if reglage.mode == RaceSetup.Mode.COURSE:
		ou = "%s, %s" % [ou, Cylindree.nom(reglage.classe)]
	if reglage.miroir:
		ou += ", miroir"
	if meilleur > 0.0:
		_record.text = "Record (%s) : %s" % [ou, RaceTimer.format(meilleur)]
		if reglage.mode == RaceSetup.Mode.CONTRE_LA_MONTRE and Fantome.charger(reglage.cle_record()) != null:
			_record.text += "  ·  fantôme prêt"
	else:
		_record.text = "Pas encore de record (%s, %d tour%s)" % [ou, reglage.tours, "s" if reglage.tours > 1 else ""]


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
