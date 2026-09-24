class_name KartBump
extends RefCounted

## Le choc entre deux karts, façon auto-tamponneuses. Les karts ne se
## bloquent plus physiquement l'un l'autre — move_and_slide les traitait
## comme des murs : celui qui poussait perdait 70 % de sa vitesse, celui qui
## était poussé ne bougeait pas, et l'un pouvait monter sur l'autre. Ici, au
## contact :
## - ils s'écartent de ce qui les fait se chevaucher ;
## - ils échangent la vitesse qu'ils avaient l'un vers l'autre, le long de la
##   ligne qui joint leurs centres : on ralentit en poussant, on accélère en
##   étant poussé, et un coup de côté fait dévier.
##
## Tout est à plat, et chaque kart est traité pour lui-même : en réseau,
## chaque machine applique le choc à son propre kart, et l'autre machine fait
## de même de son côté.

## Demi-dimensions de la caisse, en mètres : elle fait 1,1 × 1,7. Le rayon de
## contact d'un kart va de l'une à l'autre selon qu'on le touche de côté ou de
## face — un cercle unique laissait deux karts s'enfoncer de 20 cm l'un dans
## l'autre de face, ou s'arrêter à 20 cm l'un de l'autre de côté.
const DEMI_LARGEUR := 0.55
const DEMI_LONGUEUR := 0.85

## Rayon moyen, pour qui n'a pas d'orientation à fournir.
const RAYON := (DEMI_LARGEUR + DEMI_LONGUEUR) * 0.5

## Part de la vitesse de rapprochement rendue au rebond. Zéro : les karts
## restent collés ; un : ils rebondissent comme des billes.
const RESTITUTION := 0.4

## Au-delà de cet écart vertical, l'un passe au-dessus de l'autre : un kart
## qui saute par-dessus un autre ne le touche pas.
const ECART_VERTICAL := 1.2


## Le rayon d'une caisse tournée vers `cap` (en radians, boussole), dans la
## direction à plat `vers` : sa demi-longueur de face, sa demi-largeur de côté.
static func rayon(cap: float, vers: Vector3) -> float:
	var avant := Vector3(sin(cap), 0.0, -cos(cap))
	var face := absf(avant.dot(vers))
	return lerpf(DEMI_LARGEUR, DEMI_LONGUEUR, face)


## La direction du choc (de `autre` vers `moi`, à plat) et l'enfoncement, ou
## Vector3.ZERO s'il n'y a pas contact. Les caps sont ceux des caisses ; sans
## eux, chaque kart est un cercle de rayon moyen.
static func contact(moi: Vector3, autre: Vector3, cap_moi: float = NAN, cap_autre: float = NAN) -> Vector3:
	if absf(moi.y - autre.y) > ECART_VERTICAL:
		return Vector3.ZERO
	var d := Vector3(moi.x - autre.x, 0.0, moi.z - autre.z)
	var distance := d.length()
	# Deux karts exactement superposés : n'importe quelle direction vaut
	# mieux que pas de direction du tout.
	var n := d / distance if distance > 0.0001 else Vector3.RIGHT
	var portee := (RAYON if is_nan(cap_moi) else rayon(cap_moi, n)) \
		+ (RAYON if is_nan(cap_autre) else rayon(cap_autre, n))
	if distance >= portee:
		return Vector3.ZERO
	return n * (portee - distance)


## La vitesse à plat d'un moteur, dans le repère du monde.
static func vitesse(moteur: KartMotor) -> Vector3:
	return Vector3(sin(moteur.velocity_dir), 0.0, -cos(moteur.velocity_dir)) * moteur.speed


## Applique le choc au moteur de `moi` et rend le déplacement à faire pour
## sortir du chevauchement. `part` est la part de l'écartement qui revient à
## ce kart : la moitié quand les deux sont simulés ici, tout sinon.
static func encaisser(moi: KartMotor, pos_moi: Vector3, autre: KartMotor, pos_autre: Vector3,
		part: float = 0.5) -> Vector3:
	var choc := contact(pos_moi, pos_autre, moi.heading, autre.heading)
	if choc == Vector3.ZERO:
		return Vector3.ZERO
	var n := choc.normalized()
	var v := vitesse(moi)
	var rapprochement := (v - vitesse(autre)).dot(n)
	if rapprochement < 0.0:
		# À masses égales, chacun prend la moitié de l'échange ; sinon, le
		# plus léger en prend davantage.
		var ma := moi.stats.poids if moi.stats != null else 1.0
		var mb := autre.stats.poids if autre.stats != null else 1.0
		var nouvelle := v - n * rapprochement * (1.0 + RESTITUTION) * (mb / maxf(ma + mb, 0.001))
		_poser_vitesse(moi, nouvelle)
	return choc * part


## Remet une vitesse à plat dans le moteur, sans le faire reculer ni changer
## d'état. Une glisse survit à un coup d'épaule : c'est le cap qui bouge.
static func _poser_vitesse(moteur: KartMotor, v: Vector3) -> void:
	var avant := Vector3(sin(moteur.velocity_dir), 0.0, -cos(moteur.velocity_dir))
	var norme := v.length()
	if norme < 0.5:
		moteur.speed = 0.0
		return
	var nouveau_cap := atan2(v.x, -v.z)
	# Un kart poussé par l'arrière ou freiné par l'avant garde son cap ; seul
	# un coup venu de côté le dévie, et jamais au point de le retourner.
	var ecart := wrapf(nouveau_cap - moteur.velocity_dir, -PI, PI)
	ecart = clampf(ecart, -0.6, 0.6)
	moteur.speed = maxf(v.dot(avant), 0.0) if moteur.speed >= 0.0 else moteur.speed
	moteur.velocity_dir += ecart
	moteur.heading += ecart
