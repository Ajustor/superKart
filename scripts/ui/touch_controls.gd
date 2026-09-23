class_name TouchControls
extends Control

## Commandes à l'écran pour les téléphones et tablettes. Elles ne pilotent
## rien elles-mêmes : elles appuient sur les mêmes actions que le clavier et
## la manette, donc PlayerInput n'a pas à savoir qu'un écran tactile existe.
##
## Les doigts sont suivis un par un : un pouce qui glisse de « gauche » à
## « droite » change de direction sans avoir à se lever, et relâcher le frein
## ne relâche pas l'accélérateur tenu par l'autre main.

## Doigt fictif prêté à la souris, pour essayer les commandes sur un ordinateur.
const DOIGT_SOURIS := 1000

## Part de l'écran, à gauche, qui sert de croix directionnelle. Bien plus large
## que les boutons dessinés : le pouce ne regarde pas où il se pose.
const ZONE_DIRECTION := 0.42

var _doigts: Dictionary = {}     ## index du doigt -> action tenue
var _tenues: Dictionary = {}     ## action -> true, telles qu'envoyées à Input


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rafraichir_visibilite()
	GameSettings.changed.connect(_rafraichir_visibilite)


func _exit_tree() -> void:
	_tout_relacher()


func _notification(what: int) -> void:
	# Pendant la pause _input ne tourne plus : un doigt levé à ce moment-là ne
	# serait jamais vu, et le kart repartirait tout seul à la reprise.
	if what == NOTIFICATION_PAUSED:
		_tout_relacher()


func _rafraichir_visibilite() -> void:
	visible = GameSettings.tactile_actif()
	if not visible:
		_tout_relacher()
	else:
		_appliquer()


## Les boutons, dans l'ordre où on les dessine : action, centre, rayon, texte.
static func boutons(taille: Vector2) -> Array[Dictionary]:
	var r := clampf(taille.y * 0.1, 44.0, 96.0)
	var marge := r * 0.5
	var bas := taille.y - marge - r
	var gauche := marge + r
	var liste: Array[Dictionary] = [
		{action = &"steer_left", centre = Vector2(gauche, bas), rayon = r, texte = "◀"},
		{action = &"steer_right", centre = Vector2(gauche + r * 2.6, bas), rayon = r, texte = "▶"},
		{action = &"throttle", centre = Vector2(taille.x - marge - r * 1.15, bas - r * 0.15), rayon = r * 1.15, texte = "GAZ"},
		{action = &"brake", centre = Vector2(taille.x - marge - r * 3.6, bas + r * 0.2), rayon = r * 0.8, texte = "FREIN"},
		{action = &"drift", centre = Vector2(taille.x - marge - r * 1.15, bas - r * 2.75), rayon = r * 0.95, texte = "DRIFT"},
		# Au-dessus du frein, à portée du même pouce que le dérapage : on lance
		# un objet entre deux glisses, pas pendant qu'on freine.
		{action = &"use_item", centre = Vector2(taille.x - marge - r * 3.45, bas - r * 2.2), rayon = r * 0.85, texte = "OBJET"},
	]
	return liste


## L'action sous ce point, ou &"" s'il n'y en a aucune.
static func action_au_point(point: Vector2, taille: Vector2) -> StringName:
	var liste := boutons(taille)
	# La croix directionnelle : toute la moitié basse de la gauche de l'écran,
	# coupée en deux entre les deux flèches.
	if point.x < taille.x * ZONE_DIRECTION and point.y > taille.y * 0.35:
		var milieu: float = (liste[0].centre.x + liste[1].centre.x) * 0.5
		return &"steer_left" if point.x < milieu else &"steer_right"
	var meilleure: StringName = &""
	var plus_proche := INF
	for b in liste.slice(2):
		var d: float = point.distance_to(b.centre)
		if d < b.rayon * 1.35 and d < plus_proche:
			plus_proche = d
			meilleure = b.action
	return meilleure


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var local := _local(event.position)
		if event.pressed:
			_poser(event.index, local)
		else:
			_lever(event.index)
	elif event is InputEventScreenDrag:
		if _doigts.has(event.index):
			_poser(event.index, _local(event.position))
	# La souris émulée depuis l'écran tactile porte le périphérique -1 : elle
	# a déjà été vue sous forme de toucher, on ne la compte pas deux fois.
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_poser(DOIGT_SOURIS, _local(event.position))
		else:
			_lever(DOIGT_SOURIS)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION \
			and _doigts.has(DOIGT_SOURIS):
		_poser(DOIGT_SOURIS, _local(event.position))


func _local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point


func _poser(doigt: int, point: Vector2) -> void:
	var action := action_au_point(point, size)
	if action == &"":
		# Un doigt posé à côté ne fait rien, mais un doigt qui GLISSE hors d'un
		# bouton le relâche : sinon il faudrait lever le pouce pour lâcher.
		_doigts.erase(doigt)
	else:
		_doigts[doigt] = action
	_appliquer()


func _lever(doigt: int) -> void:
	_doigts.erase(doigt)
	_appliquer()


## Calcule ce qui doit être tenu, et n'envoie à Input que les différences.
func _appliquer() -> void:
	var voulues := {}
	for action in _doigts.values():
		voulues[action] = true
	if visible and GameSettings.acceleration_auto and not voulues.has(&"brake"):
		voulues[&"throttle"] = true

	for action in _tenues.keys():
		if not voulues.has(action):
			Input.action_release(action)
			_tenues.erase(action)
	for action in voulues:
		if not _tenues.has(action):
			Input.action_press(action)
			_tenues[action] = true
	queue_redraw()


func _tout_relacher() -> void:
	_doigts.clear()
	for action in _tenues:
		Input.action_release(action)
	_tenues.clear()
	queue_redraw()


func _draw() -> void:
	var police := ThemeDB.fallback_font
	for b in boutons(size):
		var tenu: bool = _tenues.has(b.action) and _doigts.values().has(b.action)
		var fond := Color(1, 1, 1, 0.32) if tenu else Color(0, 0, 0, 0.28)
		draw_circle(b.centre, b.rayon, fond)
		draw_arc(b.centre, b.rayon, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
		var taille_texte := int(b.rayon * (0.7 if String(b.texte).length() == 1 else 0.36))
		var mesure := police.get_string_size(b.texte, HORIZONTAL_ALIGNMENT_CENTER, -1, taille_texte)
		var origine: Vector2 = b.centre + Vector2(-mesure.x * 0.5, mesure.y * 0.3)
		draw_string(police, origine, b.texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_texte, Color(1, 1, 1, 0.9))
