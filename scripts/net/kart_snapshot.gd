class_name KartSnapshot
extends RefCounted

## L'état d'un kart tel qu'il voyage sur le réseau : où il est, comment il est
## tourné, et ce que son moteur fait. Le moteur compte parce que c'est lui que
## lisent les étincelles, l'inclinaison de la caisse et le son : un kart
## distant qui glisse doit se voir glisser.
##
## Un tableau de flottants plutôt qu'un dictionnaire : vingt nombres par
## kart, soixante fois par seconde, huit karts — un dictionnaire enverrait ses
## clés à chaque fois.
##
## AGE dit depuis combien de secondes l'état existe déjà au moment où il part :
## zéro pour la machine qui simule le kart, le temps passé chez l'hôte quand
## celui-ci le relaie. Le destinataire y ajoute le trajet pour savoir de quand
## date ce qu'il reçoit, et donc de combien le prolonger.

const TAILLE := 20

enum {
	GID, PX, PY, PZ, QX, QY, QZ, QW,
	VITESSE, CAP_MARCHE, CAP_CAISSE, ETAT, SENS_GLISSE, CHARGE, TURBO, FORCE_TURBO,
	FIGURES, ETOILE, RETRECI, AGE,
}


## Hors de l'arbre — dans les tests —, global_transform n'existe pas : le
## repère local en tient lieu, puisqu'il n'y a pas de parent.
static func capturer(gid: int, kart: Kart) -> PackedFloat32Array:
	var t := kart.global_transform if kart.is_inside_tree() else kart.transform
	var q := t.basis.get_rotation_quaternion()
	var m := kart.motor
	return PackedFloat32Array([
		gid, t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w,
		m.speed, m.velocity_dir, m.heading, m.state, m.drift_dir, m.drift_charge,
		m.boost_timer, m.boost_multiplier, kart.figures, m.etoile, m.retreci, 0.0,
	])


static func position(d: PackedFloat32Array) -> Vector3:
	return Vector3(d[PX], d[PY], d[PZ])


static func rotation(d: PackedFloat32Array) -> Quaternion:
	return Quaternion(d[QX], d[QY], d[QZ], d[QW]).normalized()


## Pose l'état sur un kart qui n'est pas simulé ici : sa place, et ce que son
## moteur montre. Le moteur n'avance pas — c'est la machine qui possède le
## kart qui le fait tourner.
static func appliquer(d: PackedFloat32Array, kart: Kart) -> void:
	var t := Transform3D(Basis(rotation(d)), position(d))
	if kart.is_inside_tree():
		kart.global_transform = t
	else:
		kart.transform = t
	# Une figure de plus que la dernière vue : le kart distant fait son
	# tonneau ici aussi. Le compteur rattrape un paquet perdu.
	if int(d[FIGURES]) > kart.figures:
		kart.figures = int(d[FIGURES])
		kart.figure.emit()
	var m := kart.motor
	if m == null:
		return
	m.speed = d[VITESSE]
	m.velocity_dir = d[CAP_MARCHE]
	m.heading = d[CAP_CAISSE]
	m.state = int(d[ETAT])
	m.drift_dir = int(d[SENS_GLISSE])
	m.drift_charge = d[CHARGE]
	m.boost_timer = d[TURBO]
	m.boost_multiplier = d[FORCE_TURBO]
	# L'étoile compte aussi pour l'hôte : c'est lui qui décide si une
	# carapace touche, et elle ne touche pas un kart sous étoile.
	m.etoile = d[ETOILE]
	m.retreci = d[RETRECI]


## Découpe un paquet de plusieurs karts en états individuels.
static func decouper(paquet: PackedFloat32Array) -> Array[PackedFloat32Array]:
	var etats: Array[PackedFloat32Array] = []
	var i := 0
	while i + TAILLE <= paquet.size():
		etats.append(paquet.slice(i, i + TAILLE))
		i += TAILLE
	return etats


## Entre deux états : position et rotation interpolées, le reste pris au plus
## proche. Un état de glisse à moitié entre deux valeurs n'a pas de sens.
static func melanger(a: PackedFloat32Array, b: PackedFloat32Array, t: float) -> PackedFloat32Array:
	var r := (a if t < 0.5 else b).duplicate()
	var p := position(a).lerp(position(b), t)
	var q := rotation(a).slerp(rotation(b), t)
	r[PX] = p.x
	r[PY] = p.y
	r[PZ] = p.z
	r[QX] = q.x
	r[QY] = q.y
	r[QZ] = q.z
	r[QW] = q.w
	r[VITESSE] = lerpf(a[VITESSE], b[VITESSE], t)
	return r


## Prolonge un état de `duree` secondes : le kart continue sur sa lancée, et
## continue de tourner s'il tournait — `rotation`, en radians par seconde. Un
## kart prolongé en ligne droite au milieu d'un virage sortirait de la route.
static func prolonger(d: PackedFloat32Array, duree: float, rotation_y: float = 0.0) -> PackedFloat32Array:
	var r := d.duplicate()
	var cap := d[CAP_MARCHE]
	var tourne := rotation_y * duree
	var chemin: Vector3
	if absf(tourne) < 0.001:
		chemin = Vector3(sin(cap), 0.0, -cos(cap)) * duree
	else:
		# L'arc de cercle parcouru à vitesse et rotation constantes : la
		# direction de marche (sin c, -cos c) intégrée sur la durée.
		chemin = Vector3(cos(cap) - cos(cap + tourne), 0.0, sin(cap) - sin(cap + tourne)) / rotation_y
	var p := position(d) + chemin * d[VITESSE]
	r[PX] = p.x
	r[PY] = p.y
	r[PZ] = p.z
	if absf(tourne) >= 0.001:
		# Les caps comptent dans le sens inverse de la rotation autour de Y :
		# un cap qui croît tourne la caisse vers la droite, vers -Y.
		var q := Quaternion(Vector3.UP, -tourne) * rotation(d)
		r[QX] = q.x
		r[QY] = q.y
		r[QZ] = q.z
		r[QW] = q.w
		r[CAP_MARCHE] = cap + tourne
		r[CAP_CAISSE] = d[CAP_CAISSE] + tourne
	return r
