class_name ResultsScreen
extends Control

## L'écran de fin de course : la place du joueur, son temps, ses points, et le
## classement complet. Il s'ouvre dès que le joueur franchit la ligne, sans
## attendre les autres : les lignes de ceux qui roulent encore se remplissent
## à mesure qu'ils arrivent.

@export var session_path: NodePath
@export var pause_path: NodePath
@export var touch_path: NodePath

## Le temps de voir passer la ligne avant que l'écran ne la cache.
const DELAI := 1.5

var _session: RaceSession
var _grille: GridContainer
var _resume: Label
var _record: Label
var _tours: Label
var _rejouer: Button
var _podium: PodiumScreen
var _manche_comptee := false
var _attente: float = -1.0
var _rafraichissement: float = 0.0


func _ready() -> void:
	_session = get_node(session_path) as RaceSession
	assert(_session != null, "session_path doit pointer vers une RaceSession")
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.45)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(voile)

	var colonne := UITheme.panneau_centre(self, 860.0)
	colonne.add_child(UITheme.titre("RÉSULTATS", 38))
	_resume = Label.new()
	_resume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resume.add_theme_font_size_override("font_size", 30)
	colonne.add_child(_resume)
	_record = Label.new()
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record.add_theme_color_override("font_color", UITheme.ACCENT)
	_record.hide()
	colonne.add_child(_record)
	# Le temps de chacun de ses tours, le meilleur marqué d'une étoile.
	_tours = Label.new()
	_tours.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tours.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
	_tours.add_theme_font_size_override("font_size", 20)
	colonne.add_child(_tours)

	_grille = GridContainer.new()
	_grille.columns = _colonnes().size()
	_grille.add_theme_constant_override("h_separation", 28)
	_grille.add_theme_constant_override("v_separation", 0)
	colonne.add_child(_grille)

	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 16)
	_rejouer = UITheme.bouton("Rejouer", _sur_rejouer)
	var gp := _grand_prix()
	if gp != null:
		_rejouer.text = "Podium" if gp.manche == gp.manches() - 1 else "Course suivante"
	boutons.add_child(_rejouer)
	boutons.add_child(UITheme.bouton("Menu principal", func() -> void:
		if Reseau.actif():
			Reseau.abandonner()
		else:
			RaceLauncher.retour_au_menu(get_tree())))
	colonne.add_child(boutons)

	_session.arrivee.connect(_sur_arrivee)
	# En réseau, c'est l'hôte qui compte la dernière manche : chacun montre
	# le podium quand il le dit.
	Reseau.podium.connect(_sur_podium)


## La coupe en cours, si cette course en est une manche. En réseau, celle
## que l'hôte a envoyée avec la course.
func _grand_prix() -> GrandPrix:
	if Reseau.actif():
		return Reseau.grand_prix
	var reglage := GameSettings.course
	if reglage.mode != RaceSetup.Mode.GRAND_PRIX:
		return null
	return reglage.grand_prix


func _sur_podium() -> void:
	if Reseau.grand_prix != null:
		_montrer_podium(Reseau.grand_prix)


func _contre_la_montre() -> bool:
	return not Reseau.actif() and GameSettings.course.mode == RaceSetup.Mode.CONTRE_LA_MONTRE


func _colonnes() -> PackedStringArray:
	if _contre_la_montre():
		return PackedStringArray(["", "Pilote", "Temps", "Meilleur tour"])
	if _grand_prix() != null:
		return PackedStringArray(["", "Pilote", "Temps", "Meilleur tour", "Points", "Coupe"])
	return PackedStringArray(["", "Pilote", "Temps", "Meilleur tour", "Points"])


func _sur_rejouer() -> void:
	var gp := _grand_prix()
	if Reseau.actif():
		if gp != null:
			# L'hôte compte, puis lance la manche suivante pour tous.
			_manche_comptee = true
			Reseau.manche_suivante(_ordre_d_arrivee())
		else:
			Reseau.retour_salon()
		return
	if gp == null:
		RaceLauncher.lancer(get_tree(), GameSettings.course)
		return
	_compter_manche(gp)
	if gp.terminee():
		_montrer_podium(gp)
	else:
		GameSettings.course.preparer_manche()
		RaceLauncher.lancer(get_tree(), GameSettings.course)


## Ceux qui roulent encore prennent la place qu'ils occupent : on ne les
## attend pas pour passer à la suite.
func _compter_manche(gp: GrandPrix) -> void:
	if _manche_comptee:
		return
	_manche_comptee = true
	gp.compter(_ordre_d_arrivee())


## Les noms dans l'ordre du classement : ceux sous lesquels la coupe compte,
## les mêmes sur toutes les machines en réseau.
func _ordre_d_arrivee() -> PackedStringArray:
	var ordre := PackedStringArray()
	for entree in _session.classement():
		ordre.append(_session.nom_reel(entree))
	return ordre


func _montrer_podium(gp: GrandPrix) -> void:
	if _podium == null:
		_podium = PodiumScreen.new()
		add_child(_podium)
	for enfant in get_children():
		if enfant != _podium and enfant is CanvasItem:
			(enfant as CanvasItem).hide()
	var moi := _session.nom_reel(_session.entries[0])
	var nouveautes := PackedStringArray()
	# Les trophées, comme les records, ne se gagnent qu'en solo.
	if not Reseau.actif():
		var avait_200 := GameSettings.debloque_200cc()
		var avait_miroir := GameSettings.debloque_miroir()
		GameSettings.proposer_trophee(gp.coupe, gp.classe, gp.place_de(moi))
		if not avait_200 and GameSettings.debloque_200cc():
			nouveautes.append("200cc débloquée !")
		if not avait_miroir and GameSettings.debloque_miroir():
			nouveautes.append("Mode miroir débloqué !")
	_podium.montrer(gp, moi, " ".join(nouveautes))


func _sur_arrivee(entree: RaceEntry) -> void:
	if entree == _session.entries[0]:
		_attente = DELAI
		if _session.id_piste != "" and GameSettings.proposer_record(
				_session.id_piste, _session.lap_count, entree.temps_course):
			_record.text = "Nouveau record du circuit !"
			if _contre_la_montre():
				_record.text = "Nouveau record ! Votre fantôme vous attendra."
			_record.show()
	if visible:
		_remplir()


func _process(delta: float) -> void:
	if _attente >= 0.0:
		_attente -= delta
		if _attente <= 0.0:
			_attente = -1.0
			_ouvrir()
		return
	# Tant que d'autres roulent, leurs lignes bougent : places et tours.
	if visible and not _session.terminee:
		_rafraichissement -= delta
		if _rafraichissement <= 0.0:
			_rafraichissement = 0.5
			_remplir()


func _ouvrir() -> void:
	# En réseau, c'est l'hôte qui ramène tout le monde au salon.
	if Reseau.actif():
		var gp := _grand_prix()
		if gp == null:
			_rejouer.text = "Retour au salon"
		else:
			_rejouer.text = "Podium" if gp.manche == gp.manches() - 1 else "Course suivante"
		_rejouer.visible = Reseau.est_hote()
	var pause := get_node_or_null(pause_path) as PauseMenu
	if pause != null:
		pause.fermer()
		pause.rendre_indisponible()
	var tactile := get_node_or_null(touch_path) as Control
	if tactile != null:
		tactile.hide()
	_remplir()
	show()
	if _rejouer.visible:
		_rejouer.grab_focus()


func _remplir() -> void:
	var moi := _session.entries[0]
	_tours.text = texte_des_tours(moi.timer.tours)
	var gp := _grand_prix()
	if _contre_la_montre():
		var record := GameSettings.record(_session.id_piste, _session.lap_count)
		_resume.text = "Temps : %s" % RaceTimer.format(moi.temps_course)
		if record > 0.0 and not _record.visible:
			_resume.text += "  ·  record : %s" % RaceTimer.format(record)
	else:
		_resume.text = "%s  ·  %s  ·  %d points" % [
			RaceScoring.ordinal(moi.place_finale), RaceTimer.format(moi.temps_course),
			RaceScoring.points_pour(moi.place_finale)]
		if gp != null:
			_resume.text = "%s, course %d/%d  ·  %s" % [gp.nom(), gp.manche + 1, gp.manches(), _resume.text]

	for enfant in _grille.get_children():
		_grille.remove_child(enfant)
		enfant.queue_free()
	var colonnes := _colonnes()
	for titre in colonnes:
		_cellule(titre, UITheme.TEXTE_DOUX, 18)

	for entree in _session.classement():
		var couleur := UITheme.ACCENT if entree == moi else UITheme.TEXTE
		if not entree.finished:
			couleur = UITheme.TEXTE_DOUX
		_cellule(RaceScoring.ordinal(entree.position), couleur)
		_cellule(entree.nom, couleur)
		if entree.finished:
			_cellule(RaceTimer.format(entree.temps_course), couleur)
		else:
			_cellule("tour %d/%d…" % [mini(entree.tours_comptes + 1, _session.lap_count), _session.lap_count], couleur)
		_cellule(RaceTimer.format(entree.timer.best) if entree.timer.has_best else "—", couleur)
		# Des points provisoires pour ceux qui courent encore : leur place
		# peut encore changer, la couleur éteinte le dit.
		if colonnes.size() > 4:
			_cellule(str(RaceScoring.points_pour(entree.position)), couleur)
		if gp != null:
			# Le total de la coupe, cette course comprise.
			var total := int(gp.points.get(_session.nom_reel(entree), 0))
			if not _manche_comptee:
				total += RaceScoring.points_pour(entree.position)
			_cellule(str(total), couleur)


func _cellule(texte: String, couleur: Color, taille: int = 22) -> void:
	var l := Label.new()
	l.text = texte
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_font_size_override("font_size", taille)
	_grille.add_child(l)


## « Tours : 0:31.200 · ★ 0:30.100 · 0:30.800 », le meilleur étoilé.
static func texte_des_tours(tours: PackedFloat32Array) -> String:
	if tours.is_empty():
		return ""
	var meilleur := 0
	for i in tours.size():
		if tours[i] < tours[meilleur]:
			meilleur = i
	var morceaux := PackedStringArray()
	for i in tours.size():
		morceaux.append(("★ " if i == meilleur and tours.size() > 1 else "") + RaceTimer.format(tours[i]))
	return "Tours : " + " · ".join(morceaux)
