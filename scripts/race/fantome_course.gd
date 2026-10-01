class_name FantomeCourse
extends Node

## Le fantôme du contre-la-montre : rejoue le meilleur parcours enregistré sur
## ce circuit, et enregistre celui du joueur. Si le joueur le bat, son
## parcours devient le nouveau fantôme.
##
## Les deux horloges partent au vert : le fantôme et le joueur prennent le
## départ ensemble, comme dans les jeux de kart.

signal fantome_battu
## Le joueur vient de boucler un tour : `ecart` secondes d'avance (négatif)
## ou de retard (positif) sur le fantôme au même passage.
signal ecart_au_passage(tour: int, ecart: float)

## Combien de temps l'écart reste affiché.
const DUREE_ECART := 3.0

@export var session_path: NodePath

## Le meilleur parcours connu, rejoué ; null au premier essai.
var fantome: Fantome
## Le parcours du joueur, en train de s'écrire.
var enregistrement := Fantome.new()

var _session: RaceSession
var _cle: String = ""
var _horloge: float = 0.0
var _prochain: float = 0.0
var _visuel: Node3D
var _caisse: Node3D
var _etiquette: Label
var _etiquette_reste: float = 0.0


func _ready() -> void:
	_session = get_node(session_path) as RaceSession
	if _session.entries.is_empty():
		await _session.grille_prete
	_cle = _session.id_piste
	if _cle != "":
		fantome = Fantome.charger(_cle)
	if fantome != null:
		_visuel = _construire_visuel(_session.entries[0].kart)
		_visuel.hide()
		get_parent().add_child.call_deferred(_visuel)
	_session.arrivee.connect(_sur_arrivee)
	_session.tour_boucle.connect(_sur_tour)
	_etiquette = _construire_etiquette()


func _process(delta: float) -> void:
	if _etiquette_reste > 0.0:
		_etiquette_reste -= delta
		_etiquette.visible = _etiquette_reste > 0.0


func _physics_process(delta: float) -> void:
	if _session == null or not _session.en_course or _session.entries.is_empty():
		return
	var joueur := _session.entries[0]
	if not joueur.finished:
		while _prochain <= _horloge + 0.0001:
			_noter(joueur.kart)
			_prochain += Fantome.PAS
	_rejouer(_horloge)
	_horloge += delta


func _noter(kart: Kart) -> void:
	var caisse := kart.get_node_or_null("Body") as Node3D
	enregistrement.ajouter(kart.global_position, kart.global_basis.get_rotation_quaternion(),
		caisse.quaternion if caisse != null else Quaternion.IDENTITY)


func _rejouer(t: float) -> void:
	if _visuel == null or not _visuel.is_inside_tree():
		return
	# Arrivé au bout de son parcours, le fantôme s'efface : il a franchi la ligne.
	_visuel.visible = t <= fantome.duree()
	if not _visuel.visible:
		return
	var instant := fantome.a_l_instant(t)
	_visuel.global_transform = Transform3D(Basis(instant.kart), instant.position)
	if _caisse != null:
		_caisse.quaternion = instant.caisse


## À chaque tour bouclé : le temps de passage, et l'écart au fantôme au même
## passage s'il en a un.
func _sur_tour(entree: RaceEntry) -> void:
	if _session.entries.is_empty() or entree != _session.entries[0]:
		return
	enregistrement.passages.append(_horloge)
	var i := enregistrement.passages.size() - 1
	if fantome == null or i >= fantome.passages.size():
		return
	var ecart := _horloge - fantome.passages[i]
	ecart_au_passage.emit(i + 1, ecart)
	_montrer_ecart(ecart)


static func texte_ecart(ecart: float) -> String:
	return "%s%.2f s" % ["−" if ecart < 0.0 else "+", absf(ecart)]


func _montrer_ecart(ecart: float) -> void:
	if _etiquette == null:
		return
	_etiquette.text = texte_ecart(ecart)
	# Vert en avance, rouge en retard : comme au chrono des jeux de kart.
	_etiquette.add_theme_color_override("font_color",
		Color(0.35, 1.0, 0.45) if ecart < 0.0 else Color(1.0, 0.35, 0.3))
	_etiquette.visible = true
	_etiquette_reste = DUREE_ECART


func _construire_etiquette() -> Label:
	var calque := CanvasLayer.new()
	calque.layer = 5
	add_child(calque)
	# Sous le chrono, en haut à gauche : là où l'œil va chercher le temps.
	var l := Label.new()
	l.position = Vector2(22, 96)
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.visible = false
	calque.add_child(l)
	return l


func _sur_arrivee(entree: RaceEntry) -> void:
	if entree != _session.entries[0] or _cle == "" or entree.hors_temps:
		return
	_noter(entree.kart)
	enregistrement.temps = entree.temps_course
	if fantome == null or enregistrement.temps < fantome.temps:
		if enregistrement.sauver(_cle):
			fantome_battu.emit()


## Une copie de la caisse et des roues du kart, sans leurs scripts ni leurs
## particules, dans un matériau translucide : on la voit, on ne la confond pas.
func _construire_visuel(kart: Kart) -> Node3D:
	var racine := Node3D.new()
	racine.name = "VisuelFantome"
	var materiau := StandardMaterial3D.new()
	materiau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiau.albedo_color = Color(0.75, 0.9, 1.0, 0.4)
	for nom in ["Body", "Wheels"]:
		var source := kart.get_node_or_null(nom) as Node3D
		if source == null:
			continue
		var copie := source.duplicate(0) as Node3D
		for enfant in copie.find_children("*", "GPUParticles3D", true, false):
			enfant.free()
		for enfant in copie.find_children("*", "CPUParticles3D", true, false):
			enfant.free()
		for maille in copie.find_children("*", "MeshInstance3D", true, false):
			(maille as MeshInstance3D).material_override = materiau
			(maille as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		racine.add_child(copie)
		if nom == "Body":
			_caisse = copie
	return racine
