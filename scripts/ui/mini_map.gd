class_name MiniMap
extends Control

## Le circuit vu de haut, avec un point par concurrent. En haut à droite,
## sous l'emplacement d'objet : c'est le seul coin que ni le texte, ni les
## feux, ni les commandes tactiles n'occupent.
##
## Le nord en haut, toujours : une carte qui tourne avec le kart se lit mal
## d'un coup d'œil. Le joueur est le gros point jaune ; les autres humains
## sont bleu clair, l'IA rouge. Là où la route passe sur un pont, le pont est
## dessiné par-dessus la route qu'il enjambe.

## Distance entre deux points du tracé dessiné, en mètres.
const PAS := 4.0
## Au-delà de cette différence d'altitude, une portion qui en croise une autre
## passe dessus : c'est un pont.
const HAUTEUR_DE_PONT := 5.0
const MARGE := 12.0

const FOND := Color(0.05, 0.05, 0.08, 0.55)
const ROUTE := Color(0.88, 0.9, 0.95)
const BORD := Color(0.08, 0.08, 0.1)
const MOI := Color(1.0, 0.82, 0.15)
const HUMAIN := Color(0.35, 0.85, 1.0)
const IA := Color(0.95, 0.25, 0.2)

var session: RaceSession

var _traits: Array[PackedVector2Array] = []
var _ponts: Array[bool] = []
var _vers_carte := Transform2D.IDENTITY
var _largeur_route := 4.0
var _depart: PackedVector2Array = []
var _preparee := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# L'écran change de taille (rotation d'un téléphone) : on recadre.
	resized.connect(func() -> void: _preparee = false)


## Haut de la carte : sous l'emplacement d'objet de RaceHUD.
const HAUT := 16.0 + RaceHUD.CASE_OBJET + 12.0


## Côté de la carte, en pixels, pour un écran de cette taille. Sur un petit
## écran, elle rétrécit pour s'arrêter au-dessus des boutons tactiles de
## droite, même quand ils sont masqués : sa taille ne dépend pas d'un réglage.
static func cote(ecran: Vector2) -> float:
	var c := clampf(ecran.y * 0.28, 120.0, 230.0)
	for b in TouchControls.boutons(ecran):
		if b.centre.x > ecran.x * 0.5:
			c = minf(c, b.centre.y - b.rayon - 8.0 - HAUT)
	return maxf(c, 60.0)


## Où poser la carte : bord droit aligné sur le bouton pause.
static func cadre(ecran: Vector2) -> Rect2:
	var c := cote(ecran)
	return Rect2(Vector2(ecran.x - 16.0 - c, HAUT), Vector2(c, c))


## La transformation du plan du circuit (x, z du monde) vers la carte :
## tout le tracé tient dans `taille`, à `marge` du bord, sans être déformé.
static func cadrage(points: PackedVector2Array, taille: Vector2, marge: float) -> Transform2D:
	var mini := Vector2(INF, INF)
	var maxi := -mini
	for p in points:
		mini = mini.min(p)
		maxi = maxi.max(p)
	var etendue := (maxi - mini).max(Vector2(1.0, 1.0))
	var place := taille - Vector2(marge, marge) * 2.0
	var echelle := minf(place.x / etendue.x, place.y / etendue.y)
	var decalage := taille * 0.5 - (mini + maxi) * 0.5 * echelle
	return Transform2D(0.0, Vector2(echelle, echelle), 0.0, decalage)


## Le tracé découpé en traits continus : coupé à chaque trou, et à chaque
## entrée ou sortie de pont. Rend [traits (en mètres, x et z), ponts].
static func decouper(piste: Track) -> Array:
	var c := piste.track_curve
	var n := maxi(int(c.length / PAS), 8)
	var points: Array[Vector3] = []
	for i in n + 1:
		points.append(c.position_at(c.length * float(i) / float(n)))
	var traits: Array[PackedVector2Array] = []
	var ponts: Array[bool] = []
	var courant := PackedVector2Array()
	var pont_courant := false
	for i in n + 1:
		var d := c.length * float(i) / float(n)
		var p := points[i]
		var ici := Vector2(p.x, p.z)
		if piste.trou_en(wrapf(d, 0.0, c.length)) != null:
			if courant.size() > 1:
				traits.append(courant)
				ponts.append(pont_courant)
			courant = PackedVector2Array()
			continue
		var pont := _passe_au_dessus(points, i, piste.half_width * 2.0, c.length / float(n))
		if pont != pont_courant and not courant.is_empty():
			# Le point de raccord appartient aux deux traits : pas de trou.
			courant.append(ici)
			if courant.size() > 1:
				traits.append(courant)
				ponts.append(pont_courant)
			courant = PackedVector2Array()
		pont_courant = pont
		courant.append(ici)
	if courant.size() > 1:
		traits.append(courant)
		ponts.append(pont_courant)
	return [traits, ponts]


## Le point `i` surplombe-t-il une autre portion du tracé, éloignée le long du
## tracé mais proche vue de haut ?
static func _passe_au_dessus(points: Array[Vector3], i: int, proche: float, pas: float) -> bool:
	var p := points[i]
	var n := points.size()
	var loin := int(60.0 / pas)
	for j in n:
		var ecart := absi(j - i)
		if mini(ecart, n - 1 - ecart) < loin:
			continue
		var q := points[j]
		if p.y - q.y > HAUTEUR_DE_PONT and Vector2(p.x - q.x, p.z - q.z).length() < proche:
			return true
	return false


func _preparer() -> void:
	var piste := session.circuit()
	if piste == null or piste.track_curve == null or size.x < 20.0:
		return
	var decoupe := decouper(piste)
	_traits.assign(decoupe[0])
	_ponts.assign(decoupe[1])
	var tous := PackedVector2Array()
	for t in _traits:
		tous.append_array(t)
	_vers_carte = cadrage(tous, size, MARGE)
	for i in _traits.size():
		_traits[i] = _vers_carte * _traits[i]
	_largeur_route = maxf(piste.half_width * 2.0 * _vers_carte.get_scale().x, 3.0)
	# La ligne de départ : un trait en travers de la route.
	var c := piste.track_curve
	var o := c.position_at(0.0)
	var droite := c.right_at(0.0) * piste.half_width * 1.3
	_depart = PackedVector2Array([
		_vers_carte * Vector2(o.x - droite.x, o.z - droite.z),
		_vers_carte * Vector2(o.x + droite.x, o.z + droite.z),
	])
	_preparee = true


func _process(_delta: float) -> void:
	if session == null or session.entries.is_empty():
		return
	if not _preparee:
		_preparer()
	queue_redraw()


func _draw() -> void:
	if not _preparee:
		return
	draw_rect(Rect2(Vector2.ZERO, size), FOND)
	# Le sol d'abord, les ponts ensuite, chacun avec son liseré : un pont passe
	# nettement par-dessus la route qu'il enjambe.
	for couche in [false, true]:
		for i in _traits.size():
			if _ponts[i] == couche:
				draw_polyline(_traits[i], BORD, _largeur_route + 3.0, true)
		for i in _traits.size():
			if _ponts[i] == couche:
				draw_polyline(_traits[i], ROUTE, _largeur_route, true)
	draw_line(_depart[0], _depart[1], BORD, 3.0, true)

	# Les autres d'abord, le joueur par-dessus tout le monde.
	for i in range(session.entries.size() - 1, -1, -1):
		var e := session.entries[i]
		if not e.kart.is_inside_tree():
			continue
		var p := e.kart.global_position
		var ou := _vers_carte * Vector2(p.x, p.z)
		if i == 0:
			draw_circle(ou, 7.5, Color.WHITE)
			draw_circle(ou, 5.5, MOI)
		else:
			draw_circle(ou, 5.0, BORD)
			draw_circle(ou, 3.8, HUMAIN if e.humain else IA)
