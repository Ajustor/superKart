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
var _rejouer: Button
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

	_grille = GridContainer.new()
	_grille.columns = 5
	_grille.add_theme_constant_override("h_separation", 28)
	_grille.add_theme_constant_override("v_separation", 0)
	colonne.add_child(_grille)

	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 16)
	_rejouer = UITheme.bouton("Rejouer", func() -> void:
		if Reseau.actif():
			Reseau.retour_salon()
		else:
			RaceLauncher.lancer(get_tree(), GameSettings.course))
	boutons.add_child(_rejouer)
	boutons.add_child(UITheme.bouton("Menu principal", func() -> void:
		if Reseau.actif():
			Reseau.abandonner()
		else:
			RaceLauncher.retour_au_menu(get_tree())))
	colonne.add_child(boutons)

	_session.arrivee.connect(_sur_arrivee)


func _sur_arrivee(entree: RaceEntry) -> void:
	if entree == _session.entries[0]:
		_attente = DELAI
		if _session.id_piste != "" and GameSettings.proposer_record(
				_session.id_piste, _session.lap_count, entree.temps_course):
			_record.text = "Nouveau record du circuit !"
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
		_rejouer.text = "Retour au salon"
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
	_resume.text = "%s  ·  %s  ·  %d points" % [
		RaceScoring.ordinal(moi.place_finale), RaceTimer.format(moi.temps_course),
		RaceScoring.points_pour(moi.place_finale)]

	for enfant in _grille.get_children():
		_grille.remove_child(enfant)
		enfant.queue_free()
	for titre in ["", "Pilote", "Temps", "Meilleur tour", "Points"]:
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
		_cellule(str(RaceScoring.points_pour(entree.position)), couleur)


func _cellule(texte: String, couleur: Color, taille: int = 22) -> void:
	var l := Label.new()
	l.text = texte
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_font_size_override("font_size", taille)
	_grille.add_child(l)
