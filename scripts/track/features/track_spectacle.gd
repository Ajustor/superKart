@tool
class_name TrackSpectacle
extends TrackFeature

## Ce qui se passe autour de la route pendant la course : un éclair qui frappe
## la tour de l'horloge, des voitures qui volent au-dessus du circuit, un
## train à vapeur qui longe la voie, des méduses, des bulles, une lune qui
## descend un peu plus à chaque tour, un dragon qui tourne dans le ciel.
##
## Rien de tout ça ne se touche : on le regarde. Le mouvement suit l'horloge
## du circuit (Track.horloge), comme les obstacles, et la lune l'avancement
## de la course (Track.avancement) : en réseau, chaque machine voit la même
## scène au même moment.
##
## Placé à `debut` (le milieu de la scène pour un spectacle ponctuel), à
## `decalage` mètres de l'axe et `hauteur` mètres au-dessus de la route. Le
## train et les méduses, eux, s'étalent sur `longueur`.

enum Type {
	## Un éclair qui frappe ce point toutes les `periode` secondes.
	ECLAIR,
	## `nombre` voitures qui tournent sur un cercle de `rayon` mètres.
	VOITURES_VOLANTES,
	## Une locomotive et `nombre` wagons qui vont et viennent sur `longueur`.
	TRAIN,
	## `nombre` méduses qui flottent sur `longueur`, de part et d'autre.
	MEDUSES,
	## Des bulles qui montent du fond, sur `longueur`.
	BULLES,
	## Une lune grimaçante, qui descend de `hauteur` à `rayon` mètres au fil
	## de la course.
	LUNE,
	## Un dragon qui tourne sur un cercle de `rayon` mètres.
	DRAGON,
}

@export var type: Type = Type.ECLAIR:
	set(valeur):
		type = valeur
		_modifie()

@export_range(1, 40) var nombre: int = 4:
	set(valeur):
		nombre = valeur
		_modifie()

@export_range(0.0, 400.0, 0.5) var hauteur: float = 20.0:
	set(valeur):
		hauteur = valeur
		_modifie()

@export_range(1.0, 400.0, 0.5) var rayon: float = 30.0:
	set(valeur):
		rayon = valeur
		_modifie()

## Durée d'un cycle (un éclair, un tour, un aller-retour), en secondes.
@export_range(0.5, 120.0, 0.1) var periode: float = 6.0
@export_range(0.0, 1.0, 0.05) var phase: float = 0.0

@export var couleur: Color = Color(0.7, 0.85, 1.0):
	set(valeur):
		couleur = valeur
		_modifie()

## Durée de l'éclair lui-même, en secondes.
const DUREE_ECLAIR := 0.35

var _pieces: Array[Node3D] = []
var _lumiere: OmniLight3D
var _centre := Transform3D.IDENTITY


func _init() -> void:
	longueur = 1.0
	largeur = 1.0


## Où en est le cycle à cet instant, de 0 à 1.
func cycle(horloge: float) -> float:
	return fposmod(horloge / periode + phase, 1.0)


## L'éclair frappe-t-il à cet instant ?
func eclair_visible(horloge: float) -> bool:
	return cycle(horloge) * periode < DUREE_ECLAIR


## La hauteur de la lune au-dessus de la route, d'après l'avancement de la
## course (0 au départ, 1 à l'arrivée du premier).
func hauteur_de_lune(avancement: float) -> float:
	return lerpf(hauteur, rayon, smoothstep(0.0, 1.0, clampf(avancement, 0.0, 1.0)))


static func _mat(couleur_: Color, lumineux := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur_
	m.roughness = 0.6
	if lumineux:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _boite(taille: Vector3, materiau: Material, ou := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	m.mesh = b
	m.material_override = materiau
	m.position = ou
	return m


static func _boule(rayon_: float, materiau: Material, ou := Vector3.ZERO, echelle := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rayon_
	s.height = rayon_ * 2.0
	s.radial_segments = 16
	s.rings = 8
	m.mesh = s
	m.material_override = materiau
	m.position = ou
	m.scale = echelle
	return m


static func _cylindre(r_bas: float, r_haut: float, h: float, materiau: Material, ou := Vector3.ZERO,
		angles := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r_bas
	c.top_radius = r_haut
	c.height = h
	c.radial_segments = 12
	m.mesh = c
	m.material_override = materiau
	m.position = ou
	m.rotation_degrees = angles
	return m


func _construire(c: TrackCurve, racine: Node3D) -> void:
	_pieces.clear()
	_lumiere = null
	var d := debut
	_centre = Transform3D(c.basis_at(d), TrackFeature.point(c, d, decalage, 0.0))
	match type:
		Type.ECLAIR:
			_eclair(racine)
		Type.VOITURES_VOLANTES:
			for i in nombre:
				var voiture := _voiture(Color.from_hsv(float(i) / float(nombre), 0.6, 0.95))
				racine.add_child(voiture)
				_pieces.append(voiture)
		Type.TRAIN:
			for i in nombre + 1:
				var piece := _locomotive() if i == 0 else _wagon(i)
				racine.add_child(piece)
				_pieces.append(piece)
		Type.MEDUSES:
			for i in nombre:
				var meduse := _meduse(Color.from_hsv(0.85 + 0.1 * sin(float(i)), 0.45, 1.0))
				racine.add_child(meduse)
				_pieces.append(meduse)
		Type.BULLES:
			var n := maxi(int(longueur / 35.0), 1)
			for i in n:
				var bulles := _bulles()
				var ici := debut + longueur * (float(i) + 0.5) / float(n)
				var cote := 1.0 if i % 2 == 0 else -1.0
				bulles.transform = Transform3D(Basis.IDENTITY,
					TrackFeature.point(c, ici, cote * (c.half_width + 6.0 + decalage), 0.0))
				racine.add_child(bulles)
		Type.LUNE:
			var lune := _lune()
			racine.add_child(lune)
			_pieces.append(lune)
		Type.DRAGON:
			var dragon := _dragon()
			racine.add_child(dragon)
			_pieces.append(dragon)
	_placer(0.0, 0.0)


func _process(_delta: float) -> void:
	var p := piste()
	if p == null:
		return
	if Engine.is_editor_hint():
		_placer(Time.get_ticks_msec() / 1000.0, 0.3)
	else:
		_placer(p.horloge, p.avancement())


func _placer(horloge: float, avancement: float) -> void:
	var c := courbe()
	if c == null or _pieces.is_empty() and _lumiere == null:
		return
	var t := cycle(horloge)
	match type:
		Type.ECLAIR:
			var visible := eclair_visible(horloge)
			for piece in _pieces:
				# Il vacille : deux éclats dans la même frappe.
				piece.visible = visible and fmod(horloge * 30.0, 1.0) < 0.75
			if _lumiere != null:
				_lumiere.light_energy = 12.0 if visible else 0.0
		Type.VOITURES_VOLANTES:
			for i in _pieces.size():
				var a := (t + float(i) / float(_pieces.size())) * TAU
				var ici := Vector3(cos(a) * rayon, hauteur + 2.0 * sin(a * 3.0 + float(i)), sin(a) * rayon)
				var cap := Basis(Vector3.UP, -a)
				_pieces[i].transform = Transform3D(cap, _centre.origin + ici)
		Type.TRAIN:
			# Aller et retour, en douceur aux deux bouts.
			var s := (0.5 - 0.5 * cos(t * TAU)) * longueur
			var sens := 1.0 if t < 0.5 else -1.0
			for i in _pieces.size():
				var dd := debut + s - float(i) * 9.0 * sens
				var repere := c.basis_at(dd)
				if sens < 0.0:
					repere = repere.rotated(repere.y, PI)
				_pieces[i].transform = Transform3D(repere,
					TrackFeature.point(c, dd, decalage, 0.0))
		Type.MEDUSES:
			for i in _pieces.size():
				var f := (float(i) + 0.5) / float(_pieces.size())
				var dd := debut + longueur * f
				var cote := 1.0 if i % 2 == 0 else -1.0
				var lateral := cote * (c.half_width + 3.0 + decalage + 4.0 * fposmod(float(i) * 0.37, 1.0))
				var flotte := hauteur + 3.0 * sin(horloge * 0.7 + float(i) * 1.7)
				var pulse := 1.0 + 0.12 * sin(horloge * 3.0 + float(i))
				_pieces[i].transform = Transform3D(Basis.IDENTITY.scaled(Vector3(pulse, 1.0 / pulse, pulse)),
					TrackFeature.point(c, dd, lateral, flotte))
		Type.LUNE:
			var h := hauteur_de_lune(avancement)
			var tourne := Basis(Vector3.UP, sin(horloge * 0.1) * 0.3)
			_pieces[0].transform = Transform3D(tourne, _centre.origin + Vector3.UP * h)
		Type.DRAGON:
			var a := t * TAU
			var ici := Vector3(cos(a) * rayon, hauteur + 6.0 * sin(a * 2.0), sin(a) * rayon)
			var cap := Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.35)
			_pieces[0].transform = Transform3D(cap, _centre.origin + ici)
			var battement := sin(horloge * 4.0) * 0.6
			for aile in _pieces[0].get_children():
				if aile.name.begins_with("Aile"):
					var cote := -1.0 if aile.name.ends_with("G") else 1.0
					aile.rotation.z = cote * battement


# --- Les figurants ---------------------------------------------------------------

func _eclair(racine: Node3D) -> void:
	var lumineux := _mat(Color(0.85, 0.92, 1.0), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Un trait en zigzag du ciel jusqu'au point frappé.
	var haut := hauteur + 70.0
	var y := haut
	var x := 0.0
	while y > hauteur:
		var y2 := maxf(y - rng.randf_range(5.0, 10.0), hauteur)
		var x2 := 0.0 if y2 <= hauteur else x + rng.randf_range(-4.0, 4.0)
		var bas := _centre.origin + Vector3(x2, y2, 0.0)
		var milieu := _centre.origin + Vector3((x + x2) * 0.5, (y + y2) * 0.5, 0.0)
		var longueur_trait := Vector2(x2 - x, y2 - y).length()
		var trait := _cylindre(0.25, 0.25, longueur_trait, lumineux)
		trait.transform = Transform3D(Basis(Vector3.BACK, atan2(x2 - x, y - y2)), milieu)
		racine.add_child(trait)
		_pieces.append(trait)
		x = x2
		y = y2
		if bas.y <= hauteur:
			break
	_lumiere = OmniLight3D.new()
	_lumiere.light_color = Color(0.75, 0.85, 1.0)
	_lumiere.omni_range = 120.0
	_lumiere.light_energy = 0.0
	_lumiere.position = _centre.origin + Vector3.UP * (hauteur + 10.0)
	racine.add_child(_lumiere)


func _voiture(teinte: Color) -> Node3D:
	var voiture := Node3D.new()
	voiture.add_child(_boite(Vector3(2.2, 0.8, 4.2), _mat(teinte)))
	voiture.add_child(_boite(Vector3(1.8, 0.7, 2.0), _mat(Color(0.2, 0.25, 0.35)), Vector3(0, 0.7, 0.3)))
	# Pas de roues : des réacteurs qui luisent dessous.
	for x in [-0.8, 0.8]:
		for z in [-1.4, 1.4]:
			voiture.add_child(_cylindre(0.4, 0.3, 0.3, _mat(Color(0.4, 0.9, 1.0), true), Vector3(x, -0.5, z)))
	return voiture


func _locomotive() -> Node3D:
	var loco := Node3D.new()
	var noir := _mat(Color(0.12, 0.12, 0.14))
	var rouge := _mat(Color(0.7, 0.15, 0.1))
	loco.add_child(_cylindre(1.3, 1.3, 6.0, noir, Vector3(0, 2.2, -1.0), Vector3(90, 0, 0)))
	loco.add_child(_boite(Vector3(2.8, 3.2, 2.6), rouge, Vector3(0, 2.6, 2.6)))
	loco.add_child(_boite(Vector3(3.0, 0.3, 3.0), noir, Vector3(0, 4.3, 2.6)))
	loco.add_child(_cylindre(0.45, 0.8, 1.8, noir, Vector3(0, 4.2, -2.8)))
	loco.add_child(_boite(Vector3(2.6, 0.5, 8.5), noir, Vector3(0, 0.8, 0.3)))
	# Le chasse-pierres, à l'avant.
	loco.add_child(_boite(Vector3(2.6, 1.2, 0.6), rouge, Vector3(0, 0.9, -4.3)))
	for z in [-2.8, -0.8, 1.2, 3.2]:
		for x in [-1.3, 1.3]:
			loco.add_child(_cylindre(0.75, 0.75, 0.3, rouge, Vector3(x, 0.75, z), Vector3(0, 0, 90)))
	if not Engine.is_editor_hint():
		var fumee := CPUParticles3D.new()
		fumee.amount = 24
		fumee.lifetime = 2.5
		fumee.direction = Vector3.UP
		fumee.spread = 15.0
		fumee.initial_velocity_min = 3.0
		fumee.initial_velocity_max = 5.0
		fumee.gravity = Vector3(0, 0.5, 0)
		fumee.scale_amount_min = 1.0
		fumee.scale_amount_max = 2.5
		var bouffee := SphereMesh.new()
		bouffee.radius = 0.6
		bouffee.height = 1.2
		bouffee.material = _mat(Color(0.85, 0.85, 0.85))
		fumee.mesh = bouffee
		fumee.position = Vector3(0, 5.2, -2.8)
		loco.add_child(fumee)
	return loco


func _wagon(i: int) -> Node3D:
	var wagon := Node3D.new()
	var bois := _mat(Color(0.5, 0.3, 0.15) if i % 2 == 1 else Color(0.35, 0.45, 0.25))
	wagon.add_child(_boite(Vector3(2.8, 2.6, 7.5), bois, Vector3(0, 2.2, 0)))
	wagon.add_child(_boite(Vector3(3.1, 0.25, 7.8), _mat(Color(0.2, 0.2, 0.2)), Vector3(0, 3.6, 0)))
	for z in [-2.5, 2.5]:
		for x in [-1.3, 1.3]:
			wagon.add_child(_cylindre(0.55, 0.55, 0.3, _mat(Color(0.15, 0.15, 0.15)), Vector3(x, 0.55, z), Vector3(0, 0, 90)))
	return wagon


func _meduse(teinte: Color) -> Node3D:
	var meduse := Node3D.new()
	var corps := _mat(teinte, true)
	corps.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	corps.albedo_color.a = 0.75
	meduse.add_child(_boule(1.2, corps, Vector3.ZERO, Vector3(1.0, 0.7, 1.0)))
	for k in 5:
		var a := TAU * float(k) / 5.0
		meduse.add_child(_cylindre(0.08, 0.03, 3.0, corps, Vector3(cos(a) * 0.6, -1.8, sin(a) * 0.6)))
	return meduse


func _bulles() -> Node3D:
	var bulles := CPUParticles3D.new()
	if Engine.is_editor_hint():
		return bulles
	bulles.amount = 30
	bulles.lifetime = 6.0
	bulles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bulles.emission_box_extents = Vector3(8.0, 0.5, 8.0)
	bulles.direction = Vector3.UP
	bulles.spread = 8.0
	bulles.gravity = Vector3(0, 2.0, 0)
	bulles.initial_velocity_min = 1.0
	bulles.initial_velocity_max = 2.5
	bulles.scale_amount_min = 0.3
	bulles.scale_amount_max = 1.0
	var bulle := SphereMesh.new()
	bulle.radius = 0.35
	bulle.height = 0.7
	var verre := _mat(Color(0.85, 0.95, 1.0, 0.5), true)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bulle.material = verre
	bulles.mesh = bulle
	return bulles


## Une lune ronde et grêlée, deux yeux exorbités et une grimace pleine de dents.
func _lune() -> Node3D:
	var lune := Node3D.new()
	var R := 40.0
	lune.add_child(_boule(R, _mat(Color(0.82, 0.74, 0.55))))
	var sombre := _mat(Color(0.35, 0.25, 0.15))
	for k in 7:
		var a := float(k) * 2.3
		lune.add_child(_boule(R * 0.12, sombre, Vector3(cos(a) * R * 0.6, sin(a * 1.3) * R * 0.5 + R * 0.2,
			R * 0.78), Vector3(1, 1, 0.3)))
	var oeil := _mat(Color(1.0, 0.95, 0.75), true)
	var pupille := _mat(Color(0.9, 0.35, 0.05), true)
	for x in [-0.32, 0.32]:
		lune.add_child(_boule(R * 0.2, oeil, Vector3(x * R, R * 0.25, R * 0.85)))
		lune.add_child(_boule(R * 0.08, pupille, Vector3(x * R, R * 0.25, R * 1.03)))
	lune.add_child(_boite(Vector3(R * 1.0, R * 0.12, R * 0.3), sombre, Vector3(0, -R * 0.32, R * 0.86)))
	var dent := _mat(Color(0.95, 0.92, 0.8))
	for k in 8:
		lune.add_child(_boite(Vector3(R * 0.09, R * 0.1, R * 0.12), dent,
			Vector3(-R * 0.42 + float(k) * R * 0.12, -R * 0.28, R * 0.97)))
	# Elle rougit à l'approche.
	if not Engine.is_editor_hint():
		var lueur := OmniLight3D.new()
		lueur.light_color = Color(1.0, 0.45, 0.2)
		lueur.omni_range = R * 4.0
		lueur.light_energy = 1.5
		lune.add_child(lueur)
	return lune


## Un dragon noir aux yeux violets : un corps, une queue, deux grandes ailes.
func _dragon() -> Node3D:
	var dragon := Node3D.new()
	var noir := _mat(Color(0.08, 0.06, 0.1))
	dragon.add_child(_boule(3.0, noir, Vector3.ZERO, Vector3(0.8, 0.7, 2.2)))
	dragon.add_child(_boule(1.6, noir, Vector3(0, 1.0, -7.5), Vector3(0.8, 0.7, 1.4)))
	dragon.add_child(_cylindre(1.2, 0.2, 10.0, noir, Vector3(0, 0, 9.0), Vector3(90, 0, 0)))
	var yeux := _mat(Color(0.8, 0.3, 1.0), true)
	for x in [-0.6, 0.6]:
		dragon.add_child(_boule(0.35, yeux, Vector3(x, 1.4, -8.6)))
	for cote in [-1.0, 1.0]:
		var aile := Node3D.new()
		aile.name = "AileG" if cote < 0.0 else "AileD"
		aile.add_child(_boite(Vector3(12.0, 0.3, 6.0), noir, Vector3(cote * 6.5, 0, 0)))
		dragon.add_child(aile)
	return dragon
