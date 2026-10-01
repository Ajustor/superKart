class_name MultiplayerPanel
extends Control

## L'écran multijoueur du menu : choisir son pseudo, héberger ou rejoindre,
## puis attendre dans le salon que l'hôte lance la course. Tout ce qui se
## passe vraiment sur le réseau vit dans l'autoload Reseau ; cet écran ne fait
## que l'afficher et lui transmettre des gestes.
##
## Deux portes d'entrée : le réseau local (héberger, ou rejoindre une adresse)
## et le mode en ligne (les salons d'un serveur, voir EnLigne). Le salon est le
## même ; en ligne, c'est le chef du salon qui y choisit et lance la course.

signal ferme
## Le joueur veut changer de kart : le menu ouvre le garage, puis revient ici.
signal garage

## La largeur des panneaux : celle de l'écran de référence (1280), moins une
## marge. Un téléphone en paysage est large et bas : on s'étale en colonnes.
const LARGEUR := 1180.0

var _entree: Control
var _en_ligne: Control
var _salon: Control
## L'écran d'où l'on est entré au salon, où l'on revient en le quittant.
var _porte: Control
## Ouvrir sur le mode en ligne plutôt que sur le réseau local.
var mode_en_ligne := false

var _pseudo: LineEdit
var _adresse: LineEdit
var _liste_lan: VBoxContainer
var _aucune: Label
var _message: Label
var _heberger_bouton: Button
var _rapide: Button

var _client: EnLigne
var _pseudo_en_ligne: LineEdit
var _nom_salon: LineEdit
var _prive: Button
var _code: LineEdit
var _serveur: LineEdit
var _liste_en_ligne: VBoxContainer
var _aucun_salon: Label
var _message_en_ligne: Label
var _boutons_en_ligne: Array[Button] = []
var _rafraichissement: Timer
## Une partie rapide attend la liste des salons pour en choisir un.
var _partie_rapide := false

var _titre_salon: Label
var _joueurs: VBoxContainer
var _adresses: Label
var _piste: OptionButton
var _tours: OptionButton
var _mode: OptionButton
var _classe: OptionButton
var _miroir: CheckButton
var _lancer: Button
var _attente: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	_entree = _ecran_entree()
	_en_ligne = _ecran_en_ligne()
	_salon = _ecran_salon()
	_porte = _entree
	_client = EnLigne.new()
	add_child(_client)
	_client.liste_recue.connect(_sur_liste)
	_client.salon_recu.connect(_rejoindre_salon)
	_client.echec.connect(func(message: String) -> void:
		_partie_rapide = false
		_afficher_erreur(message))
	_rafraichissement = Timer.new()
	_rafraichissement.wait_time = 6.0
	_rafraichissement.timeout.connect(func() -> void:
		if _en_ligne.visible and not _client.occupe():
			_client.lister())
	add_child(_rafraichissement)
	Reseau.salon_change.connect(_rafraichir_salon)
	Reseau.connecte.connect(func() -> void: _montrer(_salon))
	Reseau.erreur.connect(_afficher_erreur)
	Reseau.deconnecte.connect(func(raison: String) -> void:
		_montrer(_porte)
		_afficher_erreur(raison))
	Reseau.decouverte.liste_changee.connect(_rafraichir_lan)
	visibility_changed.connect(_sur_visibilite)


func _sur_visibilite() -> void:
	if not visible:
		Reseau.decouverte.arreter_ecoute()
		return
	_message.text = ""
	_message_en_ligne.text = ""
	if Reseau.actif():
		_porte = _en_ligne if Reseau.en_ligne() else _entree
		_montrer(_salon)
	else:
		_porte = _en_ligne if mode_en_ligne else _entree
		_montrer(_porte)


func _montrer(ecran: Control) -> void:
	_entree.visible = ecran == _entree
	_en_ligne.visible = ecran == _en_ligne
	_salon.visible = ecran == _salon
	if ecran != _entree:
		Reseau.decouverte.arreter_ecoute()
	if ecran == _en_ligne:
		_porte = _en_ligne
		_pseudo_en_ligne.text = GameSettings.pseudo
		_activer_en_ligne(true)
		_rafraichissement.start()
		_actualiser()
		_donner_le_focus(_rapide)
	else:
		_rafraichissement.stop()
	if ecran == _entree:
		_porte = _entree
		_pseudo.text = GameSettings.pseudo
		Reseau.decouverte.ecouter()
		_rafraichir_lan()
		_donner_le_focus(_heberger_bouton)
	elif ecran == _salon:
		_rafraichir_salon()


## Le focus pour le clavier et la manette, sur le bouton principal plutôt
## que sur un champ de texte : sur un téléphone, un champ qui prend le focus
## ouvre le clavier virtuel par-dessus l'écran sans qu'on l'ait demandé. Au
## doigt, pas de focus du tout : un bouton surligné ressemblerait à un choix.
func _donner_le_focus(bouton: Button) -> void:
	if not GameSettings.tactile_actif():
		bouton.grab_focus()


func _process(_delta: float) -> void:
	if not visible:
		return
	_message.visible = _message.text != ""
	_message_en_ligne.visible = _message_en_ligne.text != ""
	_eviter_le_clavier()


## Le clavier virtuel cache le bas de l'écran : l'écran remonte juste assez
## pour que le champ où l'on tape reste visible au-dessus.
func _eviter_le_clavier() -> void:
	var decalage := 0.0
	var champ := get_viewport().gui_get_focus_owner() as LineEdit
	var clavier := DisplayServer.virtual_keyboard_get_height()
	if champ != null and clavier > 0 and is_ancestor_of(champ):
		decalage = MultiplayerPanel.decalage_pour_clavier(champ.get_global_rect().end.y - position.y,
			get_viewport_rect().size.y, clavier, DisplayServer.window_get_size().y)
	position.y = -decalage


## De combien remonter l'écran pour qu'un champ dont le bas est à `bas_champ`
## (unités de l'écran de jeu, haut `hauteur_vue`) dépasse d'un clavier haut
## de `clavier` pixels d'une fenêtre haute de `hauteur_fenetre` pixels.
static func decalage_pour_clavier(bas_champ: float, hauteur_vue: float, clavier: int,
		hauteur_fenetre: int) -> float:
	if clavier <= 0 or hauteur_fenetre <= 0:
		return 0.0
	var haut_du_clavier := hauteur_vue * (1.0 - float(clavier) / float(hauteur_fenetre))
	return maxf(0.0, bas_champ + 16.0 - haut_du_clavier)


func _ecran_entree() -> Control:
	var ecran := Control.new()
	ecran.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ecran)
	var colonne := UITheme.panneau_defilant(ecran, LARGEUR)
	colonne.add_child(UITheme.titre("MULTIJOUEUR LOCAL", 40))
	var cotes := UITheme.deux_colonnes(colonne)

	_pseudo = LineEdit.new()
	_pseudo.placeholder_text = "Ton pseudo"
	_pseudo.max_length = 16
	_pseudo.text = GameSettings.pseudo
	cotes[0].add_child(_ligne("Pseudo", _pseudo))
	_heberger_bouton = UITheme.bouton("Héberger une partie", _heberger)
	_heberger_bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cotes[0].add_child(_heberger_bouton)
	cotes[0].add_child(UITheme.intertitre("REJOINDRE PAR ADRESSE"))
	_adresse = LineEdit.new()
	_adresse.placeholder_text = "192.168.1.20"
	_adresse.text = GameSettings.derniere_adresse
	_adresse.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_adresse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_adresse.text_submitted.connect(func(t: String) -> void: _rejoindre(t))
	var rejoindre := HBoxContainer.new()
	rejoindre.add_theme_constant_override("separation", 10)
	rejoindre.add_child(_adresse)
	var bouton := UITheme.bouton("Rejoindre", func() -> void: _rejoindre(_adresse.text))
	bouton.custom_minimum_size.x = 180
	rejoindre.add_child(bouton)
	cotes[0].add_child(rejoindre)

	cotes[1].add_child(UITheme.intertitre("PARTIES SUR CE RÉSEAU"))
	_liste_lan = VBoxContainer.new()
	cotes[1].add_child(MultiplayerPanel._liste_defilante(_liste_lan, 300))
	_aucune = Label.new()
	_aucune.text = "Aucune partie trouvée pour l'instant…"
	_aucune.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aucune.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_liste_lan.add_child(_aucune)

	_message = _etiquette_message()
	colonne.add_child(_message)
	var retour := UITheme.bouton("Retour", _fermer)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(retour)
	return ecran

func _ecran_salon() -> Control:
	var ecran := Control.new()
	ecran.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ecran)
	var colonne := UITheme.panneau_defilant(ecran, LARGEUR)
	_titre_salon = UITheme.titre("SALON", 40)
	colonne.add_child(_titre_salon)
	# Le code du salon, à donner aux amis ; en local, l'adresse Internet ou
	# pourquoi il n'y en a pas : parfois deux lignes.
	_adresses = Label.new()
	_adresses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_adresses.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_adresses.add_theme_font_size_override("font_size", 22)
	colonne.add_child(_adresses)

	# Les pilotes à gauche, les réglages de la course à droite.
	var cotes := UITheme.deux_colonnes(colonne)
	cotes[0].add_child(UITheme.intertitre("PILOTES"))
	_joueurs = VBoxContainer.new()
	_joueurs.add_theme_constant_override("separation", 4)
	cotes[0].add_child(_joueurs)

	cotes[1].add_child(UITheme.intertitre("COURSE"))
	# Une course seule, ou une des coupes. L'id est l'index de la coupe plus
	# un : un id de -1 veut dire « prends l'index » pour OptionButton.
	_mode = OptionButton.new()
	_mode.add_item("Course seule", Reseau.SANS_COUPE + 1)
	for i in TrackCatalog.COUPES.size():
		_mode.add_item("Grand Prix : %s" % TrackCatalog.COUPES[i].nom, i + 1)
	_mode.item_selected.connect(func(_i: int) -> void: _envoyer_config())
	cotes[1].add_child(_ligne("Mode", _mode))
	_classe = OptionButton.new()
	for c in Cylindree.NOMS.size():
		_classe.add_item(Cylindree.nom(c), c)
	_classe.item_selected.connect(func(_i: int) -> void: _envoyer_config())
	cotes[1].add_child(_ligne("Cylindrée", _classe))
	_piste = OptionButton.new()
	for i in TrackCatalog.PISTES.size():
		_piste.add_item(TrackCatalog.PISTES[i].nom, i)
	_piste.item_selected.connect(func(_i: int) -> void: _envoyer_config())
	cotes[1].add_child(_ligne("Circuit", _piste))
	_tours = OptionButton.new()
	for n in range(1, 6):
		_tours.add_item("%d tour%s" % [n, "s" if n > 1 else ""], n)
	_tours.item_selected.connect(func(_i: int) -> void: _envoyer_config())
	cotes[1].add_child(_ligne("Tours", _tours))
	_miroir = CheckButton.new()
	_miroir.text = "Circuits en miroir"
	_miroir.custom_minimum_size.y = 56
	_miroir.toggled.connect(func(_actif: bool) -> void: _envoyer_config())
	cotes[1].add_child(_miroir)

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
		_montrer(_porte))
	quitter.custom_minimum_size.x = 260
	boutons.add_child(quitter)
	var vers_garage := UITheme.bouton("Garage", func() -> void: garage.emit())
	vers_garage.custom_minimum_size.x = 200
	boutons.add_child(vers_garage)
	_lancer = UITheme.bouton("Lancer la course", Reseau.lancer_course)
	_lancer.custom_minimum_size.x = 300
	boutons.add_child(_lancer)
	colonne.add_child(boutons)
	return ecran

func _pseudo_choisi() -> String:
	var champ := _pseudo_en_ligne if _en_ligne.visible else _pseudo
	var nom := Lobby.nettoyer(champ.text)
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
	for message in [_message, _message_en_ligne]:
		message.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		message.text = texte
	_activer_en_ligne(true)


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
	# Qui choisit et lance : l'hôte en réseau local, le chef du salon en ligne.
	var hote := Reseau.peut_diriger()
	var en_ligne := Reseau.en_ligne()
	for peer in Reseau.lobby.ordre:
		# La couleur de son kart, puis son nom et son modèle.
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 10)
		var vehicule := Reseau.lobby.vehicule(peer)
		var pastille := ColorRect.new()
		pastille.color = ModeleKart.couleur(vehicule[1])
		pastille.custom_minimum_size = Vector2(18, 18)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(pastille)
		var l := Label.new()
		var marque := ""
		if en_ligne and peer == Reseau.lobby.chef():
			marque = " (chef)"
		elif not en_ligne and peer == 1:
			marque = " (hôte)"
		var toi := "  ← toi" if peer == Reseau.mon_id() else ""
		l.text = "%s%s — %s%s" % [Reseau.lobby.joueurs[peer], marque, ModeleKart.nom(vehicule[0]), toi]
		l.add_theme_color_override("font_color", UITheme.ACCENT if peer == Reseau.mon_id() else UITheme.TEXTE)
		# Un long pseudo se termine en « … » plutôt que d'écraser les réglages.
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(l)
		_joueurs.add_child(ligne)
	var places_ia := Lobby.PLACES - Reseau.lobby.joueurs.size()
	if places_ia > 0:
		var l := Label.new()
		l.text = "+ %d pilote%s IA" % [places_ia, "s" if places_ia > 1 else ""]
		l.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
		_joueurs.add_child(l)

	var adresses := ""
	# Le code d'un salon en ligne se donne aux amis : bien en vue.
	_adresses.add_theme_color_override("font_color", UITheme.ACCENT if en_ligne else UITheme.TEXTE_DOUX)
	if en_ligne:
		_titre_salon.text = str(Reseau.infos_salon.get("nom", "Salon")).to_upper()
		adresses = MultiplayerPanel.texte_code(Reseau.infos_salon)
		_attente.text = "En attente du lancement par le chef du salon…"
	else:
		_titre_salon.text = "SALON DE %s" % str(Reseau.lobby.joueurs.get(1, "…")).to_upper()
		if hote:
			adresses = MultiplayerPanel.adresses_texte()
		_attente.text = "En attente du lancement par l'hôte…"
	_adresses.text = adresses
	_adresses.visible = adresses != ""

	var piste := TrackCatalog.par_id(str(Reseau.config.get("piste", "")))
	var index := TrackCatalog.PISTES.find(piste)
	if index >= 0:
		_piste.select(index)
	_tours.select(_tours.get_item_index(int(Reseau.config.get("tours", 3))))
	_mode.select(_mode.get_item_index(int(Reseau.config.get("coupe", Reseau.SANS_COUPE)) + 1))
	_classe.select(_classe.get_item_index(int(Reseau.config.get("cylindree", Cylindree.Classe.CC150))))
	_miroir.set_pressed_no_signal(bool(Reseau.config.get("miroir", false)))
	# Ce que l'hôte a débloqué vaut pour le salon.
	_classe.set_item_disabled(_classe.get_item_index(Cylindree.Classe.CC200),
		hote and not GameSettings.debloque_200cc())
	_miroir.visible = bool(Reseau.config.get("miroir", false)) or (hote and GameSettings.debloque_miroir())
	var en_coupe := int(Reseau.config.get("coupe", Reseau.SANS_COUPE)) != Reseau.SANS_COUPE
	_mode.disabled = not hote
	_classe.disabled = not hote
	_miroir.disabled = not hote
	# En coupe, les circuits et les tours sont ceux de la coupe.
	_piste.disabled = not hote or en_coupe
	_tours.disabled = not hote or en_coupe
	_lancer.visible = hote
	_attente.visible = not hote


## Le code d'un salon en ligne : de quoi y faire venir ses amis.
static func texte_code(infos: Dictionary) -> String:
	var code := str(infos.get("code", ""))
	if code == "":
		return ""
	if bool(infos.get("prive", false)):
		return "Salon privé · code %s : donne-le à tes amis pour qu'ils te rejoignent." % code
	return "Code du salon : %s" % code


static func adresses_texte() -> String:
	var a := Reseau.adresses_locales()
	var lignes := PackedStringArray()
	if a.is_empty():
		lignes.append("Pas d'adresse réseau trouvée : es-tu connecté au Wi-Fi ?")
	else:
		lignes.append("Pour te rejoindre : %s" % " ou ".join(a))
	var internet := Reseau.port_internet.texte()
	if internet != "":
		lignes.append(internet)
	return "\n".join(lignes)


func _envoyer_config() -> void:
	var piste: TrackInfo = TrackCatalog.PISTES[_piste.get_selected_id()]
	Reseau.choisir_config(piste.id, _tours.get_selected_id(), _classe.get_selected_id(),
		_mode.get_selected_id() - 1, _miroir.button_pressed)


func _ligne(texte: String, controle: Control) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	var etiquette := Label.new()
	etiquette.text = texte
	# Une largeur d'étiquette fixe : les champs s'alignent d'une ligne à
	# l'autre et prennent tout le reste.
	etiquette.custom_minimum_size.x = 210
	ligne.add_child(etiquette)
	controle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(controle)
	return ligne


func _unhandled_input(event: InputEvent) -> void:
	if visible and (_entree.visible or _en_ligne.visible) and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_fermer()


func _fermer() -> void:
	Reseau.decouverte.arreter_ecoute()
	_rafraichissement.stop()
	_partie_rapide = false
	hide()
	ferme.emit()


# --- En ligne -------------------------------------------------------------------

func _ecran_en_ligne() -> Control:
	var ecran := Control.new()
	ecran.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ecran)
	var colonne := UITheme.panneau_defilant(ecran, LARGEUR)
	colonne.add_child(UITheme.titre("EN LIGNE", 40))
	var cotes := UITheme.deux_colonnes(colonne)

	# À gauche : qui l'on est, et comment entrer dans un salon.
	_pseudo_en_ligne = LineEdit.new()
	_pseudo_en_ligne.placeholder_text = "Ton pseudo"
	_pseudo_en_ligne.max_length = 16
	cotes[0].add_child(_ligne("Pseudo", _pseudo_en_ligne))

	_rapide = UITheme.bouton("Partie rapide", _lancer_partie_rapide)
	_rapide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cotes[0].add_child(_rapide)
	_boutons_en_ligne.append(_rapide)

	# Créer son salon : public, il apparaît dans la liste ; privé, on y entre
	# par son code.
	cotes[0].add_child(UITheme.intertitre("CRÉER UN SALON"))
	var creer := HBoxContainer.new()
	creer.add_theme_constant_override("separation", 10)
	_nom_salon = LineEdit.new()
	_nom_salon.placeholder_text = "Nom du salon"
	_nom_salon.max_length = 32
	_nom_salon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nom_salon.text_submitted.connect(func(_t: String) -> void: _creer_salon())
	creer.add_child(_nom_salon)
	# Un bouton à bascule qui dit en toutes lettres ce qu'on va créer :
	# l'interrupteur d'un CheckButton se voit mal sur fond sombre.
	_prive = Button.new()
	_prive.toggle_mode = true
	_prive.text = "Public"
	_prive.custom_minimum_size = Vector2(150, 60)
	_prive.toggled.connect(func(prive: bool) -> void:
		_prive.text = "Privé 🔒" if prive else "Public")
	creer.add_child(_prive)
	var bouton_creer := UITheme.bouton("Créer", _creer_salon)
	bouton_creer.custom_minimum_size.x = 130
	creer.add_child(bouton_creer)
	_boutons_en_ligne.append(bouton_creer)
	cotes[0].add_child(creer)

	cotes[0].add_child(UITheme.intertitre("REJOINDRE UN AMI"))
	var par_code := HBoxContainer.new()
	par_code.add_theme_constant_override("separation", 10)
	_code = LineEdit.new()
	_code.placeholder_text = "Code, ex. K7XQ2"
	_code.max_length = 5
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# En majuscules à mesure qu'on tape : le code se lit tel qu'on l'a reçu.
	_code.text_changed.connect(func(texte: String) -> void:
		if texte != texte.to_upper():
			var curseur := _code.caret_column
			_code.text = texte.to_upper()
			_code.caret_column = curseur)
	_code.text_submitted.connect(func(_t: String) -> void: _rejoindre_par_code())
	par_code.add_child(_code)
	var bouton_code := UITheme.bouton("Rejoindre", _rejoindre_par_code)
	bouton_code.custom_minimum_size.x = 180
	par_code.add_child(bouton_code)
	_boutons_en_ligne.append(bouton_code)
	cotes[0].add_child(par_code)

	# Un autre serveur que celui du jeu : le sien, ou celui d'un ami.
	_serveur = LineEdit.new()
	_serveur.placeholder_text = str(ProjectSettings.get_setting(EnLigne.REGLAGE, "")) \
		if str(ProjectSettings.get_setting(EnLigne.REGLAGE, "")) != "" else "superkart.exemple.org"
	_serveur.text = GameSettings.serveur_en_ligne
	_serveur.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_serveur.text_submitted.connect(func(_t: String) -> void: _actualiser())
	_serveur.focus_exited.connect(_retenir_serveur)
	cotes[0].add_child(_ligne("Serveur", _serveur))

	# À droite : les salons publics.
	var entete := HBoxContainer.new()
	var intertitre := UITheme.intertitre("SALONS PUBLICS")
	intertitre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entete.add_child(intertitre)
	var actualiser := UITheme.bouton("Actualiser", _actualiser)
	actualiser.custom_minimum_size.x = 180
	entete.add_child(actualiser)
	cotes[1].add_child(entete)
	_liste_en_ligne = VBoxContainer.new()
	cotes[1].add_child(MultiplayerPanel._liste_defilante(_liste_en_ligne, 300))
	_aucun_salon = Label.new()
	_aucun_salon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aucun_salon.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_liste_en_ligne.add_child(_aucun_salon)

	_message_en_ligne = _etiquette_message()
	colonne.add_child(_message_en_ligne)
	var retour := UITheme.bouton("Retour", _fermer)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(retour)
	return ecran


## Une liste dans une boîte de hauteur fixe qui défile : la colonne garde sa
## taille quel que soit le nombre de parties trouvées.
static func _liste_defilante(liste: VBoxContainer, hauteur: float) -> ScrollContainer:
	var boite := ScrollContainer.new()
	boite.custom_minimum_size.y = hauteur
	boite.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	boite.follow_focus = true
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", 8)
	boite.add_child(liste)
	return boite


## Une ligne pour les erreurs et les « connexion… », cachée quand elle est
## vide pour ne pas creuser un trou dans l'écran.
static func _etiquette_message() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.visible = false
	return l

func _retenir_serveur() -> void:
	var adresse := _serveur.text.strip_edges()
	if adresse != GameSettings.serveur_en_ligne:
		GameSettings.serveur_en_ligne = adresse
		GameSettings.sauver()


func _actualiser() -> void:
	_retenir_serveur()
	if EnLigne.url() == "":
		_aucun_salon.text = "Aucun serveur en ligne n'est réglé : indique son adresse ci-dessous."
		_vider_liste()
		return
	if _client.occupe():
		return
	if _liste_en_ligne.get_child_count() <= 1:
		_aucun_salon.text = "Recherche des salons…"
	_client.lister()


func _vider_liste() -> void:
	for enfant in _liste_en_ligne.get_children():
		if enfant != _aucun_salon:
			enfant.queue_free()
	_aucun_salon.visible = true


func _sur_liste(salons: Array) -> void:
	if _partie_rapide:
		_partie_rapide = false
		var choisi := EnLigne.choisir_pour_partie_rapide(salons)
		if choisi.is_empty():
			_patienter("Aucun salon libre : création d'un salon…")
			_client.creer("Salon de %s" % _pseudo_choisi(), false)
		else:
			_rejoindre_salon(choisi)
		return
	_vider_liste()
	_aucun_salon.text = "Aucun salon public pour l'instant : crée le tien !"
	_aucun_salon.visible = salons.is_empty()
	for s: Dictionary in salons:
		var b := Button.new()
		b.text = MultiplayerPanel.texte_salon(s)
		b.disabled = not MultiplayerPanel.salon_joignable(s)
		b.pressed.connect(_rejoindre_salon.bind(s))
		_liste_en_ligne.add_child(b)


## Une ligne de la liste des salons.
static func texte_salon(s: Dictionary) -> String:
	var texte := "%s — %d/%d joueurs" % [s.get("nom", "Salon"), int(s.get("joueurs", 0)),
		int(s.get("places", Lobby.PLACES))]
	if int(s.get("version", Reseau.VERSION)) != Reseau.VERSION:
		texte += "  (autre version)"
	elif bool(s.get("en_course", false)):
		var piste := str(s.get("piste", ""))
		texte += "  (en course%s)" % (" : " + piste if piste != "" else "")
	return texte


static func salon_joignable(s: Dictionary) -> bool:
	return int(s.get("version", Reseau.VERSION)) == Reseau.VERSION \
		and not bool(s.get("en_course", false)) \
		and int(s.get("joueurs", 0)) < int(s.get("places", Lobby.PLACES))


func _lancer_partie_rapide() -> void:
	_pseudo_choisi()
	if EnLigne.url() == "":
		_afficher_erreur("Aucun serveur en ligne n'est réglé : indique son adresse ci-dessous.")
		return
	_partie_rapide = true
	_patienter("Recherche d'un salon…")
	_client.lister()


func _creer_salon() -> void:
	var pseudo := _pseudo_choisi()
	var nom := _nom_salon.text.strip_edges()
	if nom == "":
		nom = "Salon de %s" % pseudo
	_patienter("Création du salon…")
	_client.creer(nom, _prive.button_pressed)


func _rejoindre_par_code() -> void:
	var code := _code.text.strip_edges().to_upper()
	if not EnLigne.code_valide(code):
		_afficher_erreur("Un code de salon fait 5 lettres ou chiffres.")
		return
	_pseudo_choisi()
	_patienter("Recherche du salon %s…" % code)
	_client.chercher(code)


func _rejoindre_salon(salon: Dictionary) -> void:
	if int(salon.get("version", Reseau.VERSION)) != Reseau.VERSION:
		_afficher_erreur("Ce salon tourne sur une autre version du jeu : mets le jeu à jour.")
		return
	var hote := str(salon.get("hote", ""))
	if hote == "" or int(salon.get("port", 0)) <= 0:
		_afficher_erreur("Ce salon n'est pas joignable.")
		return
	_patienter("Connexion au salon « %s »…" % salon.get("nom", ""))
	if Reseau.rejoindre(hote, _pseudo_choisi(), int(salon.port)) != OK:
		_activer_en_ligne(true)


## Un message d'attente, et les boutons désactivés le temps de la réponse.
func _patienter(texte: String) -> void:
	_message_en_ligne.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_message_en_ligne.text = texte
	_activer_en_ligne(false)


func _activer_en_ligne(actif: bool) -> void:
	for b in _boutons_en_ligne:
		b.disabled = not actif
