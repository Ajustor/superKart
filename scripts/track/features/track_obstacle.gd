@tool
class_name TrackObstacle
extends TrackFeature

## Un obstacle qui bouge : un marteau qui balance en travers de la route, un
## pilon qui s'abat, un bloc ou un tonneau qui va et vient d'un bord à
## l'autre. Le kart qui se fait prendre part en tête-à-queue, comme sous une
## carapace : tout l'art est de passer au bon moment, ou du bon côté.
##
## Le mouvement suit l'horloge du circuit (Track.horloge), remise à zéro au
## feu vert : en réseau, chaque machine voit le marteau au même endroit.
##
## On ne le heurte pas comme un mur : il n'a pas de collision, seulement une
## zone qui fait tourner le kart qui s'y trouve.

enum Type {
	## Un marteau suspendu à un portique, qui balance en travers.
	PENDULE,
	## Un pilon qui attend en l'air, s'abat, reste un instant au sol et remonte.
	PISTON,
	## Un bloc qui glisse d'un bord à l'autre.
	BLOC,
	## Un tonneau qui roule d'un bord à l'autre.
	TONNEAU,
	## Le gardien d'une cité engloutie : une grande créature aveugle qui
	## arpente la route d'un bord à l'autre, lentement, le torse qui palpite.
	GARDIEN,
}

@export var type: Type = Type.PENDULE:
	set(valeur):
		type = valeur
		_modifie()

## Durée d'un aller-retour (ou d'un coup de pilon), en secondes.
@export_range(0.5, 20.0, 0.1) var periode: float = 3.0

## Décale le cycle de cette fraction : deux marteaux qui alternent.
@export_range(0.0, 1.0, 0.05) var phase: float = 0.0

## Débattement : angle du marteau de part et d'autre de la verticale, en
## degrés ; course du bloc ou du tonneau de part et d'autre de son milieu, en
## mètres. Sans effet sur le pilon.
@export_range(0.0, 80.0, 0.5) var amplitude: float = 55.0

## Hauteur de l'axe du marteau, ou du pilon relevé, au-dessus de la route.
@export_range(3.0, 20.0, 0.5) var hauteur: float = 9.0:
	set(valeur):
		hauteur = valeur
		_modifie()

@export var couleur: Color = Color(0.55, 0.55, 0.6):
	set(valeur):
		couleur = valeur
		_modifie()

## La tête — ce qui frappe — au repos, dans le repère de la route : largeur
## en travers, hauteur, épaisseur le long du tracé.
const TETE := {
	Type.PENDULE: Vector3(2.4, 2.4, 1.4),
	Type.PISTON: Vector3(5.0, 1.6, 4.0),
	Type.BLOC: Vector3(3.0, 2.2, 2.2),
	Type.TONNEAU: Vector3(2.2, 2.2, 2.2),
	Type.GARDIEN: Vector3(3.0, 5.2, 1.8),
}
## Le pilon, relevé puis au sol, prend son élan sur ces fractions du cycle.
const PISTON_CHUTE := 0.55
const PISTON_SOL := 0.62
const PISTON_REMONTE := 0.85
## En dessous, une tête qui descend écrase : au-dessus, on passe dessous.
const HAUTEUR_DANGEREUSE := 2.2

## Le mouvement retourné gauche-droite : posé par le mode miroir.
var retourne: bool = false

var _tete: MeshInstance3D
var _bras: MeshInstance3D
var _zone: Area3D


func _init() -> void:
	longueur = 2.0
	largeur = 18.0


func _validate_property(property: Dictionary) -> void:
	if property.name in ["longueur", "largeur"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Où en est le cycle à cet instant, de 0 à 1.
func cycle(horloge: float) -> float:
	return fposmod(horloge / periode + phase, 1.0)


## La tête dans le repère de la route, à cet instant : écart à l'axe, hauteur
## au-dessus de la chaussée, et son roulis (pendule, tonneau), en radians.
func pose_de_la_tete(horloge: float) -> Vector3:
	var t := cycle(horloge)
	var demi := (TETE[type] as Vector3).y * 0.5
	var sens := -1.0 if retourne else 1.0
	match type:
		Type.PENDULE:
			var angle := deg_to_rad(amplitude) * sin(t * TAU) * sens
			var bras := hauteur - demi - 0.3
			return Vector3(decalage + sin(angle) * bras, hauteur - cos(angle) * bras, angle)
		Type.PISTON:
			var bas := demi + 0.05
			var haut := hauteur
			var y := haut
			if t >= PISTON_CHUTE and t < PISTON_SOL:
				var f := (t - PISTON_CHUTE) / (PISTON_SOL - PISTON_CHUTE)
				y = lerpf(haut, bas, f * f)
			elif t >= PISTON_SOL and t < PISTON_REMONTE:
				y = bas
			elif t >= PISTON_REMONTE:
				y = lerpf(bas, haut, (t - PISTON_REMONTE) / (1.0 - PISTON_REMONTE))
			return Vector3(decalage, y, 0.0)
		Type.GARDIEN:
			# Il marche : un pas qui balance, et il s'arrête un instant à chaque
			# bord avant de repartir.
			var x := amplitude * sin(t * TAU) * sens
			var pas := 0.15 * absf(sin(t * TAU * 6.0))
			return Vector3(decalage + x, demi + 0.05 + pas, 0.08 * sin(t * TAU * 6.0))
		_:
			var x := amplitude * sin(t * TAU) * sens
			# Un tonneau roule : il tourne d'autant qu'il avance.
			var roulis := -x / demi if type == Type.TONNEAU else 0.0
			return Vector3(decalage + x, demi + 0.05, roulis)


## La tête frappe-t-elle à cet instant ? Toujours, sauf le pilon relevé.
func dangereux(horloge: float) -> bool:
	return pose_de_la_tete(horloge).y - (TETE[type] as Vector3).y * 0.5 < HAUTEUR_DANGEREUSE


## Un point (écart à l'axe, hauteur au-dessus de la route) est-il dans la
## tête à cet instant ? Pour les tests et l'IA : en jeu, c'est la zone qui
## décide.
func touche(lateral: float, haut: float, horloge: float) -> bool:
	var pose := pose_de_la_tete(horloge)
	var taille: Vector3 = TETE[type]
	return dangereux(horloge) and absf(lateral - pose.x) <= taille.x * 0.5 + 0.6 \
		and absf(haut - pose.y) <= taille.y * 0.5 + 0.5


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var d := debut + longueur * 0.5
	var taille: Vector3 = TETE[type]
	var metal := StandardMaterial3D.new()
	metal.albedo_color = couleur
	metal.metallic = 0.5
	metal.roughness = 0.45
	var sombre := StandardMaterial3D.new()
	sombre.albedo_color = couleur.darkened(0.55)
	sombre.roughness = 0.7

	_tete = MeshInstance3D.new()
	if type == Type.GARDIEN:
		_habiller_le_gardien(taille)
	elif type == Type.TONNEAU:
		var futs := CylinderMesh.new()
		futs.top_radius = taille.y * 0.5
		futs.bottom_radius = taille.y * 0.5
		futs.height = taille.z
		_tete.mesh = futs
		var bois := StandardMaterial3D.new()
		bois.albedo_color = Color(0.55, 0.33, 0.15)
		bois.roughness = 0.8
		_tete.material_override = bois
	else:
		var boite := BoxMesh.new()
		boite.size = taille
		_tete.mesh = boite
		_tete.material_override = metal
	racine.add_child(_tete)

	var demi := c.half_width
	match type:
		Type.PENDULE:
			_bras = MeshInstance3D.new()
			var tige := BoxMesh.new()
			tige.size = Vector3(0.35, hauteur - taille.y * 0.5, 0.35)
			_bras.mesh = tige
			_bras.material_override = sombre
			racine.add_child(_bras)
			_portique(c, d, demi, hauteur + 0.6, sombre, racine)
		Type.PISTON:
			# Le fût du pilon, au-dessus de sa course.
			var fut := MeshInstance3D.new()
			var boite := BoxMesh.new()
			boite.size = Vector3(taille.x + 0.8, 2.0, taille.z + 0.8)
			fut.mesh = boite
			fut.material_override = sombre
			var repere := c.basis_at(d)
			fut.transform = Transform3D(repere, TrackFeature.point(c, d, decalage, hauteur + taille.y * 0.5 + 1.0))
			racine.add_child(fut)
			_portique(c, d, demi, hauteur + taille.y * 0.5 + 2.0, sombre, racine)
		Type.GARDIEN:
			pass
		_:
			# Des glissières sur les deux rives, d'où part le bloc.
			for cote in [-1.0, 1.0]:
				var but := MeshInstance3D.new()
				var boite := BoxMesh.new()
				boite.size = Vector3(0.6, 1.2, taille.z + 1.0)
				but.mesh = boite
				but.material_override = sombre
				but.transform = Transform3D(c.basis_at(d), TrackFeature.point(c, d, cote * (demi + 0.8), 0.6))
				racine.add_child(but)

	if not Engine.is_editor_hint():
		_zone = Area3D.new()
		_zone.collision_layer = 0
		_zone.collision_mask = Kart.COUCHE_KARTS
		_zone.monitorable = false
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = taille + Vector3(0.4, 0.2, 0.6)
		forme.shape = boite
		_zone.add_child(forme)
		racine.add_child(_zone)
	_placer(0.0)


## Le gardien : un corps sombre, une tête sans yeux couronnée de deux cornes,
## et au milieu du torse une lueur qui bat comme un cœur.
func _habiller_le_gardien(taille: Vector3) -> void:
	var corps := BoxMesh.new()
	corps.size = Vector3(taille.x, taille.y * 0.62, taille.z)
	_tete.mesh = corps
	var peau := StandardMaterial3D.new()
	peau.albedo_color = Color(0.05, 0.17, 0.2)
	peau.roughness = 0.9
	_tete.material_override = peau
	var lueur := StandardMaterial3D.new()
	lueur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lueur.albedo_color = Color(0.3, 0.95, 1.0)
	var tete := MeshInstance3D.new()
	var boite := BoxMesh.new()
	boite.size = Vector3(taille.x * 0.8, taille.y * 0.3, taille.z * 0.9)
	tete.mesh = boite
	tete.material_override = peau
	tete.position = Vector3(0, taille.y * 0.46, 0)
	_tete.add_child(tete)
	for cote in [-1.0, 1.0]:
		var corne := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.bottom_radius = 0.35
		cone.top_radius = 0.05
		cone.height = 1.8
		corne.mesh = cone
		corne.material_override = lueur
		corne.position = Vector3(cote * taille.x * 0.42, taille.y * 0.7, 0)
		corne.rotation_degrees = Vector3(0, 0, -cote * 25.0)
		_tete.add_child(corne)
		var bras := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.6, taille.y * 0.55, 0.6)
		bras.mesh = b
		bras.material_override = peau
		bras.position = Vector3(cote * (taille.x * 0.5 + 0.35), -taille.y * 0.05, 0)
		_tete.add_child(bras)
		var jambe := MeshInstance3D.new()
		var j := BoxMesh.new()
		j.size = Vector3(0.8, taille.y * 0.3, 0.8)
		jambe.mesh = j
		jambe.material_override = peau
		jambe.position = Vector3(cote * taille.x * 0.25, -taille.y * 0.42, 0)
		_tete.add_child(jambe)
	var coeur := MeshInstance3D.new()
	coeur.name = "Coeur"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	coeur.mesh = sphere
	coeur.material_override = lueur
	coeur.position = Vector3(0, taille.y * 0.1, -taille.z * 0.5)
	_tete.add_child(coeur)


## Deux piliers et une traverse au-dessus de la route.
func _portique(c: TrackCurve, d: float, demi: float, haut: float, materiau: Material, racine: Node3D) -> void:
	var repere := c.basis_at(d)
	for cote in [-1.0, 1.0]:
		var pilier := MeshInstance3D.new()
		var boite := BoxMesh.new()
		boite.size = Vector3(0.8, haut, 0.8)
		pilier.mesh = boite
		pilier.material_override = materiau
		pilier.transform = Transform3D(repere, TrackFeature.point(c, d, cote * (demi + 1.0), haut * 0.5))
		racine.add_child(pilier)
	var traverse := MeshInstance3D.new()
	var poutre := BoxMesh.new()
	poutre.size = Vector3(demi * 2.0 + 2.8, 0.7, 0.8)
	traverse.mesh = poutre
	traverse.material_override = materiau
	traverse.transform = Transform3D(repere, TrackFeature.point(c, d, 0.0, haut))
	racine.add_child(traverse)


func _physics_process(_delta: float) -> void:
	if _tete == null or Engine.is_editor_hint():
		return
	var p := piste()
	var horloge := p.horloge if p != null else 0.0
	_placer(horloge)
	if _zone != null and dangereux(horloge):
		for corps in _zone.get_overlapping_bodies():
			var kart := corps as Kart
			# Un kart piloté sur une autre machine y subit le choc lui-même.
			if kart != null and kart.simule:
				kart.motor.stun()


func _placer(horloge: float) -> void:
	var c := courbe()
	if c == null:
		return
	var d := debut + longueur * 0.5
	var repere := c.basis_at(d)
	var pose := pose_de_la_tete(horloge)
	var centre := c.position_at(d) + repere.x * pose.x + repere.y * pose.y
	var roulis := Basis(Vector3.BACK, pose.z)
	if type == Type.TONNEAU:
		# Le cylindre est debout : couché le long du tracé, il roule en travers.
		roulis = roulis * Basis(Vector3.RIGHT, PI * 0.5)
	var pose_tete := Transform3D(repere * roulis, centre)
	_tete.global_transform = pose_tete
	if type == Type.GARDIEN:
		var coeur := _tete.get_node_or_null("Coeur") as Node3D
		if coeur != null:
			coeur.scale = Vector3.ONE * (1.0 + 0.35 * maxf(sin(horloge * 5.0), 0.0))
	if _zone != null:
		_zone.global_transform = pose_tete
	if _bras != null:
		var pivot := c.position_at(d) + repere.x * decalage + repere.y * hauteur
		_bras.global_transform = Transform3D(repere * Basis(Vector3.BACK, pose.z), (pivot + centre) * 0.5)
