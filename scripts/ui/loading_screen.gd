class_name EcranChargement
extends CanvasLayer

## L'écran de chargement d'une course : il s'affiche dès le clic, charge la
## scène de course et le circuit dans un fil à part, monte la course derrière
## lui, attend que la musique soit composée et que les premières images aient
## été dessinées (les shaders se compilent à ce moment-là, derrière l'écran
## plutôt qu'en pleine course), puis — en réseau — que tous les joueurs soient
## prêts. Il s'efface quand le décompte peut commencer.
##
## Il vit d'abord seul, comme scène courante, le temps du chargement ; puis il
## passe dans la course montée, au-dessus de tout, jusqu'au départ.

signal pret

enum Etape { CHARGEMENT, MONTAGE, PREPARATION, ATTENTE_JOUEURS, FINI }

const TEXTES := {
	Etape.CHARGEMENT: "Chargement du circuit…",
	Etape.MONTAGE: "Montage de la course…",
	Etape.PREPARATION: "Préparation de la piste…",
	Etape.ATTENTE_JOUEURS: "En attente des autres joueurs…",
	Etape.FINI: "C'est parti !",
}

const ASTUCES := [
	"Tenez DRIFT en braquant : les étincelles bleues, puis orange, puis violettes donnent un turbo de plus en plus fort.",
	"Accélérez juste avant le vert pour partir en trombe. Trop tôt, et le moteur cale.",
	"Appuyez sur DRIFT en plein saut pour faire une figure : un petit turbo à l'atterrissage.",
	"Chaque tremplin donne un turbo au décollage. Ajoutez une figure : un deuxième à l'atterrissage.",
	"Collez un adversaire, juste derrière lui : quand le vent siffle, l'aspiration lance un turbo pour le doubler.",
	"Gardez OBJET enfoncé : la banane ou la carapace traîne derrière vous et arrête les carapaces.",
	"Objet tenu : lâchez pour le lancer devant, ou lâchez en freinant pour l'envoyer derrière.",
	"Sans objet, le bouton OBJET klaxonne. Chaque pilote a son klaxon.",
	"La carapace rouge suit la route jusqu'au kart de devant. La verte file tout droit et rebondit sur les murs.",
	"Couper par l'herbe ralentit… sauf sous champignon.",
	"En contre-la-montre, votre meilleur parcours revient courir contre vous, en fantôme.",
	"La carapace bleue survole le peloton et explose sur celui qui mène. Restez à distance du premier !",
	"Sous étoile, rien ne vous touche, et chaque kart percuté part en tête-à-queue.",
	"Chaque pièce ajoute un peu de vitesse de pointe, jusqu'à dix. Un choc en fait perdre trois.",
	"Méfiez-vous des boîtes rougeâtres au point d'interrogation à l'envers : ce sont des pièges.",
	"L'éclair rétrécit tous vos adversaires et leur fait lâcher leur objet.",
]

## Au-delà, on lâche la course même si la musique n'est pas prête : elle
## démarrera quand elle le sera.
const ATTENTE_MUSIQUE_MAX := 5.0
## Images dessinées derrière l'écran avant de le lever : de quoi compiler les
## shaders de ce qui est visible au départ.
const IMAGES_DE_CHAUFFE := 4
const FONDU := 0.35

## Rend la course montée (un Node pas encore dans l'arbre).
var fabrique: Callable
## Les chemins à charger d'avance, dans un fil à part.
var a_charger: PackedStringArray = []
var titre: String = ""
var sous_titre: String = ""
var description: String = ""
## Faux dans les tests : la course est ajoutée sous le parent de l'écran au
## lieu de remplacer la scène courante.
var changer_de_scene := true

var etape: Etape = Etape.CHARGEMENT
var _chauffe: TourDeChauffe
var _chauffe_faite := false
var course: Node

var _session: RaceSession
var _sync: RaceSync
var _attente: float = 0.0
var _images: int = 0
var _montage_demande := false

var _fond: Control
var _barre: ProgressBar
var _etat: Label
var _joueurs: VBoxContainer
var _astuce: Label


## L'écran qui mène à la course d'un réglage solo.
static func pour_reglage(reglage: RaceSetup) -> EcranChargement:
	var e := EcranChargement.new()
	e.fabrique = func() -> Node:
		var c := RaceLauncher.monter(reglage)
		(c.get_node("Session") as RaceSession).attente_depart = true
		return c
	e.a_charger = PackedStringArray([RaceLauncher.SCENE_COURSE])
	if reglage.piste != null:
		e.a_charger.append(reglage.piste.chemin_scene)
		e.titre = reglage.piste.nom
		e.description = reglage.piste.description
	e.sous_titre = _sous_titre(reglage)
	return e


static func _sous_titre(reglage: RaceSetup) -> String:
	match reglage.mode:
		RaceSetup.Mode.CONTRE_LA_MONTRE:
			return "Contre-la-montre"
		RaceSetup.Mode.BATAILLE:
			return "Bataille · %s · %d ballons · %d min" % [Cylindree.nom(reglage.classe), Bataille.BALLONS,
				int(Bataille.DUREE / 60.0)]
		RaceSetup.Mode.GRAND_PRIX:
			if reglage.grand_prix != null:
				var gp := reglage.grand_prix
				return "%s · course %d/%d · %s" % [gp.nom(), gp.manche + 1, gp.manches(), Cylindree.nom(gp.classe)]
	return "%s%s · %d tour%s" % [Cylindree.nom(reglage.classe), " · miroir" if reglage.miroir else "",
		reglage.tours, "s" if reglage.tours > 1 else ""]


func _ready() -> void:
	layer = 100
	_construire()
	for chemin in a_charger:
		if chemin != "" and not ResourceLoader.has_cached(chemin):
			ResourceLoader.load_threaded_request(chemin)


func _process(delta: float) -> void:
	match etape:
		Etape.CHARGEMENT:
			var avance := _avancement_du_chargement()
			_barre.value = avance * 60.0
			if avance >= 1.0:
				_passer(Etape.MONTAGE)
		Etape.MONTAGE:
			# Une image avec le texte « Montage » à l'écran avant de bloquer,
			# puis le montage en fin d'image : l'écran change de parent, ce
			# qui ne se fait pas au milieu de son propre _process.
			if not _montage_demande:
				_montage_demande = true
				_monter.call_deferred()
		Etape.PREPARATION:
			# D'abord le tour de chauffe : tous les matériaux de la course
			# dessinés une fois, derrière l'écran.
			if _chauffe == null and not _chauffe_faite:
				_chauffe_faite = true
				if course != null and course.is_inside_tree():
					_chauffe = TourDeChauffe.lancer(course)
			if _chauffe != null and is_instance_valid(_chauffe) and not _chauffe.fini():
				return
			_attente += delta
			_images += 1
			var musique_prete := _musique_prete()
			var part := 0.5 * minf(float(_images) / IMAGES_DE_CHAUFFE, 1.0) \
				+ 0.5 * (1.0 if musique_prete else minf(_attente / ATTENTE_MUSIQUE_MAX, 1.0))
			_barre.value = 70.0 + 30.0 * part
			if _images >= IMAGES_DE_CHAUFFE and (musique_prete or _attente >= ATTENTE_MUSIQUE_MAX):
				_signaler_pret()
		Etape.ATTENTE_JOUEURS:
			_rafraichir_joueurs()
			if _session == null or not _session.attente_depart:
				_terminer()


## De 0 à 1 : la part chargée de ce qui devait l'être.
func _avancement_du_chargement() -> float:
	if a_charger.is_empty():
		return 1.0
	var total := 0.0
	var progres := []
	for chemin in a_charger:
		if chemin == "" or ResourceLoader.has_cached(chemin):
			total += 1.0
			continue
		match ResourceLoader.load_threaded_get_status(chemin, progres):
			ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED, \
					ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				total += 1.0
			_:
				total += float(progres[0]) if not progres.is_empty() else 0.0
	return total / float(a_charger.size())


func _monter() -> void:
	# Récupère ce que le fil a chargé : load() le trouverait aussi, mais sans
	# ça la requête resterait ouverte.
	for chemin in a_charger:
		if chemin != "" and not ResourceLoader.has_cached(chemin):
			ResourceLoader.load_threaded_get(chemin)
	course = fabrique.call()
	_session = course.get_node_or_null("Session") as RaceSession
	_sync = course.get_node_or_null("RaceSync") as RaceSync
	if _sync != null:
		# C'est l'écran qui dira quand cette machine est prête, pas la course.
		_sync.attendre_ecran = true
	# L'écran passe dans la course, au-dessus de tout, jusqu'au départ. L'arbre
	# se prend avant : une fois détaché, l'écran n'y est plus.
	var arbre := get_tree()
	var ancien_parent := get_parent()
	ancien_parent.remove_child(self)
	course.add_child(self)
	if changer_de_scene:
		arbre.change_scene_to_node(course)
	else:
		ancien_parent.add_child(course)
	_barre.value = 70.0
	_passer(Etape.PREPARATION)


func _musique_prete() -> bool:
	if _session == null or _session.entries.is_empty():
		return false
	var piste := _session.circuit()
	return piste == null or Musique.deja_composee(piste.musique) != null


func _signaler_pret() -> void:
	_barre.value = 100.0
	pret.emit()
	if _sync != null:
		_sync.signaler_charge()
		_passer(Etape.ATTENTE_JOUEURS)
		_rafraichir_joueurs()
		return
	if _session != null:
		_session.attente_depart = false
	_terminer()


func _terminer() -> void:
	_passer(Etape.FINI)
	var fondu := create_tween()
	fondu.tween_property(_fond, "modulate:a", 0.0, FONDU)
	fondu.tween_callback(queue_free)


func _passer(nouvelle: Etape) -> void:
	etape = nouvelle
	_etat.text = TEXTES[nouvelle]


# --- Affichage ---------------------------------------------------------------------

func _construire() -> void:
	_fond = Control.new()
	_fond.theme = UITheme.theme()
	_fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Il couvre tout, y compris les commandes tactiles : rien ne passe à travers.
	_fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fond)

	var degrade := Gradient.new()
	degrade.set_color(0, Color(0.10, 0.16, 0.30))
	degrade.set_color(1, Color(0.02, 0.03, 0.06))
	var texture := GradientTexture2D.new()
	texture.gradient = degrade
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var image := TextureRect.new()
	image.texture = texture
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond.add_child(image)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond.add_child(centre)
	var colonne := VBoxContainer.new()
	colonne.custom_minimum_size = Vector2(760, 0)
	colonne.add_theme_constant_override("separation", 14)
	centre.add_child(colonne)

	colonne.add_child(UITheme.titre(titre.to_upper() if titre != "" else "CHARGEMENT", 54))
	if sous_titre != "":
		var sous := Label.new()
		sous.text = sous_titre
		sous.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sous.add_theme_font_size_override("font_size", 26)
		colonne.add_child(sous)
	if description != "":
		var texte := Label.new()
		texte.text = description
		texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		texte.add_theme_color_override("font_color", UITheme.TEXTE_DOUX)
		texte.add_theme_font_size_override("font_size", 20)
		colonne.add_child(texte)

	_barre = ProgressBar.new()
	_barre.custom_minimum_size = Vector2(0, 26)
	_barre.show_percentage = false
	var plein := StyleBoxFlat.new()
	plein.bg_color = UITheme.ACCENT
	plein.set_corner_radius_all(8)
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color(1, 1, 1, 0.1)
	vide.set_corner_radius_all(8)
	_barre.add_theme_stylebox_override("fill", plein)
	_barre.add_theme_stylebox_override("background", vide)
	colonne.add_child(_barre)

	_etat = Label.new()
	_etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etat.add_theme_font_size_override("font_size", 22)
	colonne.add_child(_etat)

	_joueurs = VBoxContainer.new()
	_joueurs.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_child(_joueurs)

	_astuce = Label.new()
	_astuce.text = "Astuce : " + str(ASTUCES[randi() % ASTUCES.size()])
	_astuce.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_astuce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_astuce.add_theme_color_override("font_color", UITheme.ACCENT.lerp(Color.WHITE, 0.4))
	_astuce.add_theme_font_size_override("font_size", 20)
	colonne.add_child(_astuce)

	_passer(Etape.CHARGEMENT)


## En réseau : chaque joueur humain, prêt ou pas.
func _rafraichir_joueurs() -> void:
	if _sync == null:
		return
	var etats := _sync.etats_de_chargement()
	if _joueurs.get_child_count() == etats.size():
		var i := 0
		for nom in etats:
			(_joueurs.get_child(i) as Label).text = _ligne_joueur(nom, etats[nom])
			i += 1
		return
	for enfant in _joueurs.get_children():
		enfant.free()
	for nom in etats:
		var l := Label.new()
		l.text = _ligne_joueur(nom, etats[nom])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22)
		_joueurs.add_child(l)


static func _ligne_joueur(nom: String, pret_: bool) -> String:
	return "%s  %s" % ["✓" if pret_ else "…", nom]
