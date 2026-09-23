class_name RaceHUD
extends Control

## Quatre informations, pas une de plus : la place, le tour, le chrono, le
## meilleur temps. Le palier de mini-turbo n'y figure pas — c'est la couleur
## des étincelles qui le dit, et le joueur ne doit pas avoir à quitter la route
## des yeux.
##
## S'y ajoutent ce qui n'existe qu'un instant : les feux et le décompte au
## départ, l'annonce du dernier tour, et l'arrivée. Et, sous l'objet, la
## mini-carte (MiniMap).

@export var session_path: NodePath

## Durée d'affichage du « GO ! » et des annonces, en secondes.
const DUREE_ANNONCE := 1.2
const RAYON_FEU := 26.0

## L'emplacement d'objet, en haut à droite, à gauche du bouton pause.
const CASE_OBJET := 92.0
## Pendant la roulette, un pictogramme différent toutes les ... secondes.
const PAS_ROULETTE := 0.08

var _session: RaceSession
var _label: Label
var _annonce: Label
var _temps_annonce: float = 0.0
var _depuis_depart: float = -1.0
var _carte: MiniMap


func _ready() -> void:
	_session = get_node(session_path) as RaceSession
	assert(_session != null, "session_path doit pointer vers une RaceSession")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_label = Label.new()
	_label.position = Vector2(24, 16)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)

	_annonce = Label.new()
	_annonce.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_annonce.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_annonce.grow_vertical = Control.GROW_DIRECTION_BOTH
	_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_annonce.add_theme_font_size_override("font_size", 120)
	_annonce.add_theme_color_override("font_color", UITheme.ACCENT)
	_annonce.add_theme_color_override("font_outline_color", Color.BLACK)
	_annonce.add_theme_constant_override("outline_size", 16)
	_annonce.position.y -= 80.0
	add_child(_annonce)

	_carte = MiniMap.new()
	_carte.session = _session
	add_child(_carte)
	_placer_la_carte()
	resized.connect(_placer_la_carte)

	_session.depart.connect(func() -> void:
		_depuis_depart = 0.0
		_annoncer("GO !"))
	_session.tour_boucle.connect(_sur_tour)
	_session.depart_du_joueur.connect(_sur_depart_du_joueur)


func _placer_la_carte() -> void:
	var cadre := MiniMap.cadre(size)
	_carte.position = cadre.position
	_carte.size = cadre.size


func _sur_depart_du_joueur(resultat: int) -> void:
	if resultat == RaceSession.Depart.TURBO:
		_annoncer("TURBO !")
	elif resultat == RaceSession.Depart.CALE:
		_annoncer("CALÉ !")


func _sur_tour(entree: RaceEntry) -> void:
	if entree != _session.entries[0]:
		return
	if entree.finished:
		_annoncer("ARRIVÉE !\n%s" % RaceScoring.ordinal(entree.place_finale), 3.0)
	elif entree.tours_comptes == _session.lap_count - 1:
		_annoncer("DERNIER TOUR !")


func _annoncer(texte: String, duree: float = DUREE_ANNONCE) -> void:
	_annonce.text = texte
	_annonce.add_theme_font_size_override("font_size", 120 if texte.length() <= 4 else 72)
	_temps_annonce = duree


func _process(delta: float) -> void:
	if _session.entries.is_empty():
		return
	var moi := _session.entries[0]
	var tour := mini(moi.progress.lap + 1, _session.lap_count)
	var lignes := PackedStringArray()
	# maxi(..., 1) couvre la toute première image, avant que classer() n'ait
	# tourné : afficher « 0e » serait un bug visible.
	lignes.append("%s / %d" % [RaceScoring.ordinal(maxi(moi.position, 1)), _session.entries.size()])
	lignes.append("TOUR %d/%d" % [tour, _session.lap_count])
	lignes.append(RaceTimer.format(moi.timer.current))
	if moi.timer.has_best:
		lignes.append("MEILLEUR %s" % RaceTimer.format(moi.timer.best))
	_label.text = "\n".join(lignes)

	if not _session.en_course:
		_annonce.text = str(ceili(_session.decompte_restant))
		_annonce.add_theme_font_size_override("font_size", 120)
		_annonce.visible = _session.decompte_restant > 0.0
	else:
		_temps_annonce = maxf(_temps_annonce - delta, 0.0)
		_annonce.visible = _temps_annonce > 0.0
		if _depuis_depart >= 0.0:
			_depuis_depart += delta
	queue_redraw()


func _draw() -> void:
	if _session == null or _session.entries.is_empty():
		return
	_dessiner_objet()
	_dessiner_feux()


## L'emplacement d'objet. Pendant la roulette les pictogrammes défilent ; ensuite
## l'objet tiré reste affiché, avec le nombre de charges s'il y en a plusieurs.
func _dessiner_objet() -> void:
	var inventaire := _session.entries[0].inventaire
	var cadre := Rect2(Vector2(size.x - 104.0 - CASE_OBJET, 16.0), Vector2(CASE_OBJET, CASE_OBJET))
	draw_rect(cadre, Color(0.05, 0.05, 0.07, 0.7))
	draw_rect(cadre, Color(1, 1, 1, 0.6), false, 3.0)
	if inventaire.est_vide():
		return
	var montre := inventaire.objet
	if inventaire.roulette > 0.0:
		var pas := int(Time.get_ticks_msec() / (PAS_ROULETTE * 1000.0))
		montre = ItemKind.TIRABLES[pas % ItemKind.TIRABLES.size()]
	ItemIcons.dessiner(self, montre, cadre.get_center(), CASE_OBJET * 0.4)
	if inventaire.roulette <= 0.0 and inventaire.charges > 1:
		draw_string(ThemeDB.fallback_font, cadre.position + Vector2(CASE_OBJET - 30.0, CASE_OBJET - 8.0),
			"×%d" % inventaire.charges, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


## Les feux de départ : trois rouges qui s'allument une seconde après l'autre,
## puis trois verts au départ, qui s'effacent peu après.
func _dessiner_feux() -> void:
	var allumes := 0
	var couleur := Color(0.95, 0.12, 0.1)
	if not _session.en_course:
		allumes = clampi(4 - ceili(_session.decompte_restant), 0, 3)
	elif _depuis_depart >= 0.0 and _depuis_depart < DUREE_ANNONCE:
		allumes = 3
		couleur = Color(0.2, 0.95, 0.3)
	else:
		return
	var centre := Vector2(size.x * 0.5, 70.0)
	var ecart := RAYON_FEU * 2.6
	draw_rect(Rect2(centre - Vector2(ecart * 1.5 + 4, RAYON_FEU + 12), Vector2(ecart * 3 + 8, RAYON_FEU * 2 + 24)),
		Color(0.05, 0.05, 0.06, 0.85))
	for i in 3:
		var c := centre + Vector2((i - 1) * ecart, 0)
		draw_circle(c, RAYON_FEU, couleur if i < allumes else Color(0.2, 0.2, 0.22))
