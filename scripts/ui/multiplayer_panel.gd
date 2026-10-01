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

var _client: EnLigne
var _pseudo_en_ligne: LineEdit
var _nom_salon: LineEdit
var _prive: CheckButton
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
		_pseudo_en_ligne.grab_focus()
	else:
		_rafraichissement.stop()
	if ecran == _entree:
		_porte = _entree
		_pseudo.text = GameSettings.pseudo
		Reseau.decouverte.ecouter()
		_rafraichir_lan()
		_pseudo.grab_focus()
	elif ecran == _salon:
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
	# L'adresse Internet, ou pourquoi il n'y en a pas : parfois deux lignes.
	_adresses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_adresses.custom_minimum_size.x = 660
	_adresses.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_adresses.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_adresses.add_theme_font_size_override("font_size", 20)
	colonne.add_child(_adresses)

	_joueurs = VBoxContainer.new()
	colonne.add_child(_joueurs)

	# Une course seule, ou une des coupes. L'id est l'index de la coupe plus
	# un : un id de -1 veut dire « prends l'index » pour OptionButton.
	_mode = OptionButton.new()
	_mode.add_item("Course seule", Reseau.SANS_COUPE + 1)
	for i in TrackCatalog.COUPES.size():
		_mode.add_item("Grand Prix : %s" % TrackCatalog.COUPES[i].nom, i + 1)
	_mode.item_selected.connect(func(_i: int) -> void: _envoyer_config())
	colonne.add_child(_ligne("Mode", _mode))
	_classe = OptionButton.new()
	for c in Cylindree.NOMS.size():
		_classe.add_item(Cylindree.nom(c), c)
	_classe.item_selected.connect(func(_i: int) -> void: _envoyer_config())
	colonne.add_child(_ligne("Cylindrée", _classe))
	_miroir = CheckButton.new()
	_miroir.text = "Circuits en miroir"
	_miroir.toggled.connect(func(_actif: bool) -> void: _envoyer_config())
	colonne.add_child(_miroir)

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
		_montrer(_porte))
	quitter.custom_minimum_size.x = 220
	boutons.add_child(quitter)
	var vers_garage := UITheme.bouton("Garage", func() -> void: garage.emit())
	vers_garage.custom_minimum_size.x = 160
	boutons.add_child(vers_garage)
	_lancer = UITheme.bouton("Lancer la course", Reseau.lancer_course)
	_lancer.custom_minimum_size.x = 240
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
		ligne.add_child(l)
		_joueurs.add_child(ligne)
	var places_ia := Lobby.PLACES - Reseau.lobby.joueurs.size()
	if places_ia > 0:
		var l := Label.new()
		l.text = "+ %d pilote%s IA" % [places_ia, "s" if places_ia > 1 else ""]
		l.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
		_joueurs.add_child(l)

	var adresses := ""
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
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(etiquette)
	controle.custom_minimum_size.x = maxf(controle.custom_minimum_size.x, 320)
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
	var colonne := UITheme.panneau_centre(ecran, 760.0)
	colonne.add_child(UITheme.titre("EN LIGNE", 40))

	_pseudo_en_ligne = LineEdit.new()
	_pseudo_en_ligne.placeholder_text = "Ton pseudo"
	_pseudo_en_ligne.max_length = 16
	_pseudo_en_ligne.custom_minimum_size = Vector2(320, 0)
	colonne.add_child(_ligne("Pseudo", _pseudo_en_ligne))

	var rapide := UITheme.bouton("Partie rapide", _lancer_partie_rapide)
	rapide.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(rapide)
	_boutons_en_ligne.append(rapide)

	# Créer son salon : public, il apparaît dans la liste ; privé, on y entre
	# par son code.
	var creer := HBoxContainer.new()
	creer.add_theme_constant_override("separation", 10)
	_nom_salon = LineEdit.new()
	_nom_salon.placeholder_text = "Nom du salon"
	_nom_salon.max_length = 32
	_nom_salon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	creer.add_child(_nom_salon)
	_prive = CheckButton.new()
	_prive.text = "Privé"
	creer.add_child(_prive)
	var bouton_creer := Button.new()
	bouton_creer.text = "Créer un salon"
	bouton_creer.pressed.connect(_creer_salon)
	creer.add_child(bouton_creer)
	_boutons_en_ligne.append(bouton_creer)
	colonne.add_child(creer)

	var par_code := HBoxContainer.new()
	par_code.add_theme_constant_override("separation", 10)
	var etiquette := Label.new()
	etiquette.text = "Code d'un salon"
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	par_code.add_child(etiquette)
	_code = LineEdit.new()
	_code.placeholder_text = "ABCDE"
	_code.max_length = 5
	_code.custom_minimum_size.x = 140
	_code.text_submitted.connect(func(_t: String) -> void: _rejoindre_par_code())
	par_code.add_child(_code)
	var bouton_code := Button.new()
	bouton_code.text = "Rejoindre"
	bouton_code.pressed.connect(_rejoindre_par_code)
	par_code.add_child(bouton_code)
	_boutons_en_ligne.append(bouton_code)
	colonne.add_child(par_code)

	var entete := HBoxContainer.new()
	var intertitre := Label.new()
	intertitre.text = "SALONS PUBLICS"
	intertitre.add_theme_color_override("font_color", UITheme.ACCENT)
	intertitre.add_theme_font_size_override("font_size", 20)
	intertitre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entete.add_child(intertitre)
	var actualiser := Button.new()
	actualiser.text = "Actualiser"
	actualiser.pressed.connect(_actualiser)
	entete.add_child(actualiser)
	colonne.add_child(entete)
	_liste_en_ligne = VBoxContainer.new()
	colonne.add_child(_liste_en_ligne)
	_aucun_salon = Label.new()
	_aucun_salon.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_liste_en_ligne.add_child(_aucun_salon)

	_message_en_ligne = Label.new()
	_message_en_ligne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(_message_en_ligne)

	# Un autre serveur que celui du jeu : le sien, ou celui d'un ami.
	_serveur = LineEdit.new()
	_serveur.placeholder_text = str(ProjectSettings.get_setting(EnLigne.REGLAGE, "")) \
		if str(ProjectSettings.get_setting(EnLigne.REGLAGE, "")) != "" else "superkart.exemple.org"
	_serveur.text = GameSettings.serveur_en_ligne
	_serveur.text_submitted.connect(func(_t: String) -> void: _actualiser())
	_serveur.focus_exited.connect(_retenir_serveur)
	colonne.add_child(_ligne("Serveur", _serveur))

	var retour := UITheme.bouton("Retour", _fermer)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(retour)
	return ecran


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
