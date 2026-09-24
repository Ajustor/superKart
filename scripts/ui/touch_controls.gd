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

## Part de l'écran, à gauche, qui sert à diriger. Bien plus large que ce qui
## est dessiné : le pouce ne regarde pas où il se pose.
const ZONE_DIRECTION := 0.42

## Le joystick, réglage par défaut : il apparaît là où le pouce se pose dans
## la zone de direction, et braque d'autant plus qu'on le pousse — un léger
## coup de pouce corrige une trajectoire, là où une flèche braquait à fond.
## Au centre, une zone morte : tenir la ligne droite ne demande pas un pouce
## immobile au pixel près. Au-delà de son bord, la base suit le pouce :
## revenir de l'autre côté ne demande jamais plus d'un rayon.
const ZONE_MORTE := 0.12
## La base suit le pouce au-delà de ce multiple du rayon.
const LAISSE := 1.2
## Courbe de réponse : au-dessus de 1, plus de finesse près du centre.
const COURBE := 1.4

var _doigts: Dictionary = {}     ## index du doigt -> action tenue
var _tenues: Dictionary = {}     ## action -> true, telles qu'envoyées à Input

## Vrai pendant le décompte : voir RaceSession.
static var gaz_auto_retenus := false
var _gaz_auto_retenus_vus := false

var _doigt_joystick := -1
var _centre_joystick := Vector2.ZERO
var _pouce := Vector2.ZERO
## Braquage envoyé à Input, de -1 (gauche) à 1 (droite).
var _direction := 0.0


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
## Avec le joystick, les deux flèches n'y sont pas.
static func boutons(taille: Vector2, joystick: bool = false) -> Array[Dictionary]:
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
	return liste.slice(2) if joystick else liste


static func rayon_joystick(taille: Vector2) -> float:
	return clampf(taille.y * 0.13, 50.0, 110.0)


## Où le joystick attend, dessiné en pâle, tant qu'aucun pouce ne le tient.
static func repos_joystick(taille: Vector2) -> Vector2:
	var r := rayon_joystick(taille)
	return Vector2(r * 1.6, taille.y - r * 1.6)


static func dans_la_zone_de_direction(point: Vector2, taille: Vector2) -> bool:
	return point.x < taille.x * ZONE_DIRECTION and point.y > taille.y * 0.35


## Le braquage, de -1 à 1, pour un pouce en `pouce` sur un joystick centré
## en `centre`. Seul l'écart horizontal compte : on dirige, on n'accélère pas.
static func braquage(centre: Vector2, pouce: Vector2, rayon: float) -> float:
	var x := clampf((pouce.x - centre.x) / rayon, -1.0, 1.0)
	if absf(x) <= ZONE_MORTE:
		return 0.0
	var t := (absf(x) - ZONE_MORTE) / (1.0 - ZONE_MORTE)
	return signf(x) * pow(t, COURBE)


## La base, rapprochée du pouce quand il s'en éloigne trop.
static func suivre(centre: Vector2, pouce: Vector2, rayon: float) -> Vector2:
	var ecart := pouce - centre
	var laisse := rayon * LAISSE
	if ecart.length() <= laisse:
		return centre
	return pouce - ecart.normalized() * laisse


## L'action sous ce point, ou &"" s'il n'y en a aucune. Avec le joystick, la
## zone de direction n'est à aucun bouton : c'est lui qui la tient.
static func action_au_point(point: Vector2, taille: Vector2, joystick: bool = false) -> StringName:
	var liste := boutons(taille)
	# La croix directionnelle : toute la moitié basse de la gauche de l'écran,
	# coupée en deux entre les deux flèches.
	if dans_la_zone_de_direction(point, taille):
		if joystick:
			return &""
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


func _process(_delta: float) -> void:
	# Le vert vient de tomber : l'accélération automatique reprend.
	if visible and gaz_auto_retenus != _gaz_auto_retenus_vus:
		_appliquer()


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
		if _doigts.has(event.index) or event.index == _doigt_joystick:
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
			and (_doigts.has(DOIGT_SOURIS) or _doigt_joystick == DOIGT_SOURIS):
		_poser(DOIGT_SOURIS, _local(event.position))


func _local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point


func _poser(doigt: int, point: Vector2) -> void:
	if GameSettings.joystick:
		if doigt == _doigt_joystick:
			_pouce = point
			_centre_joystick = suivre(_centre_joystick, point, rayon_joystick(size))
			_appliquer()
			return
		if _doigt_joystick < 0 and not _doigts.has(doigt) and dans_la_zone_de_direction(point, size):
			_doigt_joystick = doigt
			_centre_joystick = point
			_pouce = point
			_appliquer()
			return
	var action := action_au_point(point, size, GameSettings.joystick)
	if action == &"":
		# Un doigt posé à côté ne fait rien, mais un doigt qui GLISSE hors d'un
		# bouton le relâche : sinon il faudrait lever le pouce pour lâcher.
		_doigts.erase(doigt)
	else:
		_doigts[doigt] = action
	_appliquer()


func _lever(doigt: int) -> void:
	if doigt == _doigt_joystick:
		_doigt_joystick = -1
	_doigts.erase(doigt)
	_appliquer()


## Calcule ce qui doit être tenu, et n'envoie à Input que les différences.
func _appliquer() -> void:
	var voulues := {}
	for action in _doigts.values():
		voulues[action] = true
	_gaz_auto_retenus_vus = gaz_auto_retenus
	if visible and GameSettings.acceleration_auto and not gaz_auto_retenus and not voulues.has(&"brake"):
		voulues[&"throttle"] = true
	_diriger()

	for action in _tenues.keys():
		if not voulues.has(action):
			Input.action_release(action)
			_tenues.erase(action)
	for action in voulues:
		if not _tenues.has(action):
			Input.action_press(action)
			PlayerInput.noter_appui(action)
			_tenues[action] = true
	queue_redraw()


## Envoie le braquage du joystick, en analogique : Input.get_axis lit la
## force de chaque côté, et le kart braque d'autant.
func _diriger() -> void:
	var voulu := 0.0
	if _doigt_joystick >= 0:
		# Plus sensible, moins de chemin à faire pour braquer à fond.
		voulu = braquage(_centre_joystick, _pouce, rayon_joystick(size) / GameSettings.sensibilite_joystick)
	if is_equal_approx(voulu, _direction):
		return
	_direction = voulu
	for cote in [[&"steer_left", -voulu], [&"steer_right", voulu]]:
		if cote[1] > 0.0:
			Input.action_press(cote[0], cote[1])
		else:
			Input.action_release(cote[0])


func _tout_relacher() -> void:
	_doigts.clear()
	for action in _tenues:
		Input.action_release(action)
	_tenues.clear()
	_doigt_joystick = -1
	if _direction != 0.0:
		_direction = 0.0
		Input.action_release(&"steer_left")
		Input.action_release(&"steer_right")
	queue_redraw()


func _draw() -> void:
	var police := ThemeDB.fallback_font
	if GameSettings.joystick:
		_dessiner_joystick()
	for b in boutons(size, GameSettings.joystick):
		var tenu: bool = _tenues.has(b.action) and _doigts.values().has(b.action)
		var fond := Color(1, 1, 1, 0.32) if tenu else Color(0, 0, 0, 0.28)
		draw_circle(b.centre, b.rayon, fond)
		draw_arc(b.centre, b.rayon, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
		var taille_texte := int(b.rayon * (0.7 if String(b.texte).length() == 1 else 0.36))
		var mesure := police.get_string_size(b.texte, HORIZONTAL_ALIGNMENT_CENTER, -1, taille_texte)
		var origine: Vector2 = b.centre + Vector2(-mesure.x * 0.5, mesure.y * 0.3)
		draw_string(police, origine, b.texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_texte, Color(1, 1, 1, 0.9))


func _dessiner_joystick() -> void:
	var r := rayon_joystick(size)
	var tenu := _doigt_joystick >= 0
	var centre := _centre_joystick if tenu else repos_joystick(size)
	draw_circle(centre, r, Color(0, 0, 0, 0.28 if tenu else 0.16))
	draw_arc(centre, r, 0.0, TAU, 48, Color(1, 1, 1, 0.55 if tenu else 0.3), 3.0, true)
	# La zone morte, pour qu'on sache où la ligne droite se tient.
	draw_arc(centre, r * ZONE_MORTE, 0.0, TAU, 24, Color(1, 1, 1, 0.25), 2.0, true)
	var bouton := centre
	if tenu:
		bouton = centre + (_pouce - centre).limit_length(r)
	draw_circle(bouton, r * 0.45, Color(1, 1, 1, 0.45 if tenu else 0.22))
