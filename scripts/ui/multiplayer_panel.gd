class_name MultiplayerPanel
extends Control

## L'écran multijoueur du menu : choisir son pseudo, héberger ou rejoindre,
## puis attendre dans le salon que l'hôte lance la course. Tout ce qui se
## passe vraiment sur le réseau vit dans l'autoload Reseau ; cet écran ne fait
## que l'afficher et lui transmettre des gestes.

signal ferme

var _entree: Control
var _salon: Control

var _pseudo: LineEdit
var _adresse: LineEdit
var _liste_lan: VBoxContainer
var _aucune: Label
var _message: Label

var _titre_salon: Label
var _joueurs: VBoxContainer
var _adresses: Label
var _piste: OptionButton
var _tours: OptionButton
var _lancer: Button
var _attente: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	_entree = _ecran_entree()
	_salon = _ecran_salon()
	Reseau.salon_change.connect(_rafraichir_salon)
	Reseau.connecte.connect(func() -> void: _montrer(_salon))
	Reseau.erreur.connect(_afficher_erreur)
	Reseau.deconnecte.connect(func(raison: String) -> void:
		_montrer(_entree)
		_afficher_erreur(raison))
	Reseau.decouverte.liste_changee.connect(_rafraichir_lan)
	visibility_changed.connect(_sur_visibilite)


func _sur_visibilite() -> void:
	if not visible:
		Reseau.decouverte.arreter_ecoute()
		return
	_message.text = ""
	if Reseau.actif():
		_montrer(_salon)
	else:
		_montrer(_entree)


func _montrer(ecran: Control) -> void:
	_entree.visible = ecran == _entree
	_salon.visible = ecran == _salon
	if ecran == _entree:
		Reseau.decouverte.ecouter()
		_rafraichir_lan()
		_pseudo.grab_focus()
	else:
		Reseau.decouverte.arreter_ecoute()
		_rafraichir_salon()


func _ecran_entree() -> Control:
	var ecran := Control.new()
	ecran.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ecran)
	var colonne := UITheme.panneau_centre(ecran, 720.0)
	colonne.add_child(UITheme.titre("MULTIJOUEUR", 40))

	_pseudo = LineEdit.new()
	_pseudo.placeholder_text = "Ton pseudo"
	_pseudo.max_length = 16
	_pseudo.text = GameSettings.pseudo
	_pseudo.custom_minimum_size = Vector2(320, 0)
	colonne.add_child(_ligne("Pseudo", _pseudo))

	var heberger := UITheme.bouton("Héberger une partie", _heberger)
	heberger.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(heberger)

	var intertitre := Label.new()
	intertitre.text = "PARTIES SUR CE RÉSEAU"
	intertitre.add_theme_color_override("font_color", UITheme.ACCENT)
	intertitre.add_theme_font_size_override("font_size", 20)
	colonne.add_child(intertitre)
	_liste_lan = VBoxContainer.new()
	colonne.add_child(_liste_lan)
	_aucune = Label.new()
	_aucune.text = "Aucune partie trouvée pour l'instant…"
	_aucune.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_liste_lan.add_child(_aucune)

	_adresse = LineEdit.new()
	_adresse.placeholder_text = "192.168.1.20"
	_adresse.text = GameSettings.derniere_adresse
	_adresse.custom_minimum_size = Vector2(260, 0)
	var rejoindre := HBoxContainer.new()
	rejoindre.add_theme_constant_override("separation", 10)
	var etiquette := Label.new()
	etiquette.text = "Adresse de l'hôte"
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rejoindre.add_child(etiquette)
	rejoindre.add_child(_adresse)
	var bouton := Button.new()
	bouton.text = "Rejoindre"
	bouton.pressed.connect(func() -> void: _rejoindre(_adresse.text))
	rejoindre.add_child(bouton)
	colonne.add_child(rejoindre)

	_message = Label.new()
	_message.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(_message)

	var retour := UITheme.bouton("Retour", _fermer)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(retour)
	return ecran


func _ecran_salon() -> Control:
	var ecran := Control.new()
	ecran.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ecran)
	var colonne := UITheme.panneau_centre(ecran, 720.0)
	_titre_salon = UITheme.titre("SALON", 40)
	colonne.add_child(_titre_salon)
	_adresses = Label.new()
	_adresses.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_adresses.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_adresses.add_theme_font_size_override("font_size", 20)
	colonne.add_child(_adresses)

	_joueurs = VBoxContainer.new()
	colonne.add_child(_joueurs)

	_piste = OptionButton.new()
	for i in TrackCatalog.PISTES.size():
		_piste.add_item(TrackCatalog.PISTES[i].nom, i)
	_piste.item_selected.connect(func(_i: int) -> void: _envoyer_config())
	colonne.add_child(_ligne("Circuit", _piste))
	_tours = OptionButton.new()
	for n in range(1, 6):
		_tours.add_item("%d tour%s" % [n, "s" if n > 1 else ""], n)
	_tours.item_selected.connect(func(_i: int) -> void: _envoyer_config())
	colonne.add_child(_ligne("Nombre de tours", _tours))

	_attente = Label.new()
	_attente.text = "En attente du lancement par l'hôte…"
	_attente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attente.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	colonne.add_child(_attente)

	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 16)
	var quitter := UITheme.bouton("Quitter le salon", func() -> void:
		Reseau.quitter()
		_montrer(_entree))
	quitter.custom_minimum_size.x = 260
	boutons.add_child(quitter)
	_lancer = UITheme.bouton("Lancer la course", Reseau.lancer_course)
	_lancer.custom_minimum_size.x = 260
	boutons.add_child(_lancer)
	colonne.add_child(boutons)
	return ecran


func _pseudo_choisi() -> String:
	var nom := Lobby.nettoyer(_pseudo.text)
	GameSettings.pseudo = nom
	GameSettings.sauver()
	return nom


func _heberger() -> void:
	_message.text = ""
	Reseau.heberger(_pseudo_choisi())


func _rejoindre(adresse: String) -> void:
	_message.text = ""
	if adresse.strip_edges() == "":
		_afficher_erreur("Tape l'adresse IP de l'hôte, ou choisis une partie dans la liste.")
		return
	GameSettings.derniere_adresse = adresse.strip_edges()
	if Reseau.rejoindre(adresse, _pseudo_choisi()) == OK:
		_message.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
		_message.text = "Connexion à %s…" % adresse.strip_edges()


func _afficher_erreur(texte: String) -> void:
	_message.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	_message.text = texte


func _rafraichir_lan() -> void:
	for enfant in _liste_lan.get_children():
		if enfant != _aucune:
			enfant.queue_free()
	var parties: Dictionary = Reseau.decouverte.parties
	_aucune.visible = parties.is_empty()
	for ip in parties:
		var infos: Dictionary = parties[ip]
		var b := Button.new()
		b.text = "%s — %d/%d joueurs  (%s)" % [infos.nom, infos.joueurs, infos.max, ip]
		b.pressed.connect(func() -> void: _rejoindre(ip))
		_liste_lan.add_child(b)


func _rafraichir_salon() -> void:
	if _joueurs == null:
		return
	for enfant in _joueurs.get_children():
		enfant.queue_free()
	var hote := Reseau.est_hote()
	for peer in Reseau.lobby.ordre:
		var l := Label.new()
		var marque := " (hôte)" if peer == 1 else ""
		var toi := "  ← toi" if peer == Reseau.mon_id() else ""
		l.text = "• %s%s%s" % [Reseau.lobby.joueurs[peer], marque, toi]
		l.add_theme_color_override("font_color", UITheme.ACCENT if peer == Reseau.mon_id() else UITheme.TEXTE)
		_joueurs.add_child(l)
	var places_ia := Lobby.PLACES - Reseau.lobby.joueurs.size()
	if places_ia > 0:
		var l := Label.new()
		l.text = "+ %d pilote%s IA" % [places_ia, "s" if places_ia > 1 else ""]
		l.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
		_joueurs.add_child(l)

	_titre_salon.text = "SALON DE %s" % str(Reseau.lobby.joueurs.get(1, "…")).to_upper()
	var adresses := MultiplayerPanel.adresses_texte() if hote else ""
	_adresses.text = adresses
	_adresses.visible = adresses != ""

	var piste := TrackCatalog.par_id(str(Reseau.config.get("piste", "")))
	var index := TrackCatalog.PISTES.find(piste)
	if index >= 0:
		_piste.select(index)
	_tours.select(_tours.get_item_index(int(Reseau.config.get("tours", 3))))
	_piste.disabled = not hote
	_tours.disabled = not hote
	_lancer.visible = hote
	_attente.visible = not hote


static func adresses_texte() -> String:
	var a := Reseau.adresses_locales()
	if a.is_empty():
		return "Pas d'adresse réseau trouvée : es-tu connecté au Wi-Fi ?"
	return "Pour te rejoindre : %s" % " ou ".join(a)


func _envoyer_config() -> void:
	var piste: TrackInfo = TrackCatalog.PISTES[_piste.get_selected_id()]
	Reseau.choisir_config(piste.id, _tours.get_selected_id())


func _ligne(texte: String, controle: Control) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(etiquette)
	controle.custom_minimum_size.x = maxf(controle.custom_minimum_size.x, 320)
	ligne.add_child(controle)
	return ligne


func _unhandled_input(event: InputEvent) -> void:
	if visible and _entree.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_fermer()


func _fermer() -> void:
	Reseau.decouverte.arreter_ecoute()
	hide()
	ferme.emit()
