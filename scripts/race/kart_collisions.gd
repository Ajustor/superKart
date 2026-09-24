class_name KartCollisions
extends Node

## Les chocs entre karts, une fois par image de physique, après que chacun a
## bougé. Placé dans la scène de course après les karts : l'ordre de l'arbre
## est l'ordre de la physique.
##
## Seuls les karts simulés ici sont touchés : un kart piloté sur une autre
## machine encaisse le choc là-bas, et on le voit arriver par le réseau.

@export var session_path: NodePath

var _session: RaceSession


func _ready() -> void:
	_session = get_node(session_path) as RaceSession


func _physics_process(_delta: float) -> void:
	if _session == null or not _session.en_course:
		return
	var karts: Array[Kart] = []
	for entree in _session.entries:
		karts.append(entree.kart)
	resoudre(karts)


## Toutes les paires, une fois chacune. Huit karts, vingt-huit paires : pas la
## peine d'une structure d'accélération.
static func resoudre(karts: Array[Kart]) -> void:
	for i in karts.size():
		for j in range(i + 1, karts.size()):
			_paire(karts[i], karts[j])


static func _paire(a: Kart, b: Kart) -> void:
	if not a.simule and not b.simule:
		return
	var pa := _position(a)
	var pb := _position(b)
	var choc := KartBump.contact(pa, pb, a.motor.heading, b.motor.heading)
	if choc == Vector3.ZERO:
		return
	# Pour le bruit du choc : seulement quand les karts se rapprochent, pas
	# à chaque image où ils se frôlent.
	var rapprochement := (KartBump.vitesse(a.motor) - KartBump.vitesse(b.motor)).dot(choc.normalized())
	if rapprochement < 0.0:
		a.bouscule.emit(-rapprochement)
		b.bouscule.emit(-rapprochement)
	# L'écartement se partage entre les karts simulés ici ; un kart distant
	# ne bouge pas, celui d'ici fait tout le chemin.
	var part := 0.5 if a.simule and b.simule else 1.0
	# Les deux chocs se calculent sur les vitesses d'avant le choc.
	var ma := a.motor
	var mb := b.motor
	var avant_a := KartMotor.new(ma.stats)
	avant_a.speed = ma.speed
	avant_a.velocity_dir = ma.velocity_dir
	avant_a.heading = ma.heading
	if a.simule:
		_deplacer(a, KartBump.encaisser(ma, pa, mb, pb, part))
	if b.simule:
		_deplacer(b, KartBump.encaisser(mb, pb, avant_a, pa, part))


static func _position(k: Kart) -> Vector3:
	return k.global_position if k.is_inside_tree() else k.position


static func _deplacer(k: Kart, decalage: Vector3) -> void:
	if k.is_inside_tree():
		k.global_position += decalage
	else:
		k.position += decalage
