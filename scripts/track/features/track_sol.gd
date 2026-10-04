@tool
class_name TrackSol
extends TrackFeature

## Le sol plat autour du circuit : une prairie, une banquise, une dalle,
## à l'altitude `altitude`. Contrairement à un grand plan posé à la main, il
## est percé là où la route passe dessous : une galerie qui plonge sous la
## surface ne le traverse pas à mi-hauteur. Sans ça, le kart roulait sous un
## second sol, qu'il voyait et qu'il traversait — sans collision, c'est un
## décor.
##
## Purement décoratif, comme TrackTerrain : rien ne s'y pose.

## Hauteur du sol. Un peu sous la route (-0,4) : la route reste au-dessus.
@export var altitude: float = -0.4:
	set(valeur):
		altitude = valeur
		_modifie()

## Mètres de sol autour du tracé.
@export_range(20.0, 1000.0, 5.0) var marge: float = 300.0:
	set(valeur):
		marge = valeur
		_modifie()

## Faux : le sol s'étend sous tout le circuit. Vrai : seulement à moins de
## `marge` mètres de la portion [debut, debut + longueur] — la prairie d'un
## monde, quand le suivant est un lac de lave ou le vide.
@export var portion: bool = false:
	set(valeur):
		portion = valeur
		_modifie()

## Taille d'une case : les trous se découpent case par case.
@export_range(2.0, 20.0, 0.5) var maille: float = 6.0:
	set(valeur):
		maille = valeur
		_modifie()

@export var couleur: Color = Color(0.4, 0.55, 0.3):
	set(valeur):
		couleur = valeur
		_modifie()

@export_range(0.0, 1.0, 0.05) var rugosite: float = 1.0:
	set(valeur):
		rugosite = valeur
		_modifie()

## Une route qui passe moins profond que ça sous le sol le perce : au-delà,
## le sol est le plafond d'une salle, loin au-dessus des karts.
const PROFONDEUR_PERCEE := 16.0
## Un décor posé à côté de la route descend jusqu'au sol s'il est au plus à
## cette hauteur au-dessus (TrackDecor) : plus haut, la route est un pont, et
## ce qu'on pose à côté reste à sa hauteur.
const POSE_MAX := 6.0
## Pas des échantillons de route.
const PAS := 3.0
## Case de la grille de recherche, en mètres.
const CASE := 24.0


func _init() -> void:
	longueur = 1.0


func _validate_property(property: Dictionary) -> void:
	if property.name in ["decalage", "largeur"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name in ["debut", "longueur"] and not portion:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Les cases où il y a du sol, et le coin de la première.
var _cases := {}
var _origine := Vector2.ZERO
var _cases_pour: TrackCurve


static func _ranger(grille: Dictionary, ici: Vector2) -> void:
	var cle := Vector2i(floori(ici.x / CASE), floori(ici.y / CASE))
	if not grille.has(cle):
		grille[cle] = PackedVector2Array()
	grille[cle].append(ici)


## Un point de la grille de recherche à moins de `rayon` de `ici` ?
static func proche(grille: Dictionary, ici: Vector2, rayon: float) -> bool:
	var cle := Vector2i(floori(ici.x / CASE), floori(ici.y / CASE))
	var portee := ceili(rayon / CASE)
	for dx in range(-portee, portee + 1):
		for dz in range(-portee, portee + 1):
			var points: PackedVector2Array = grille.get(cle + Vector2i(dx, dz), PackedVector2Array())
			for p in points:
				if p.distance_to(ici) < rayon:
					return true
	return false


## Découpe le sol : les cases sous la portion couverte, moins celles qu'une
## route passant dessous perce.
func _calculer(c: TrackCurve) -> void:
	if _cases_pour == c:
		return
	_cases_pour = c
	_cases.clear()
	var dessous := {}
	var portion_couverte := {}
	var mini := Vector2(INF, INF)
	var maxi := Vector2(-INF, -INF)
	var n := maxi(int(c.length / PAS), 8)
	for i in n:
		var d := c.length * float(i) / float(n)
		var p := c.position_at(d)
		var ici := Vector2(p.x, p.z)
		if p.y < altitude - 0.05 and p.y > altitude - PROFONDEUR_PERCEE:
			_ranger(dessous, ici)
		if portion and not couvre(d, c.length):
			continue
		_ranger(portion_couverte, ici)
		mini = mini.min(ici)
		maxi = maxi.max(ici)
	if mini.x == INF:
		return
	mini -= Vector2.ONE * marge
	maxi += Vector2.ONE * marge
	_origine = mini
	var rayon := c.half_width + maille * 0.75 + 1.5
	var nx := ceili((maxi.x - mini.x) / maille)
	var nz := ceili((maxi.y - mini.y) / maille)
	for ix in nx:
		for iz in nz:
			var centre := mini + Vector2(ix + 0.5, iz + 0.5) * maille
			if portion and not proche(portion_couverte, centre, marge):
				continue
			if not dessous.is_empty() and proche(dessous, centre, rayon):
				continue
			_cases[Vector2i(ix, iz)] = true


## Y a-t-il du sol en ce point (x, z) ? Ni hors de l'étendue, ni dans un trou.
func a_du_sol(ici: Vector2) -> bool:
	var c := courbe()
	if c == null:
		return false
	_calculer(c)
	var case := Vector2i(floori((ici.x - _origine.x) / maille), floori((ici.y - _origine.y) / maille))
	return _cases.has(case)


func _modifie() -> void:
	_cases_pour = null
	super()


func _construire(c: TrackCurve, racine: Node3D) -> void:
	_cases_pour = null
	_calculer(c)
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	outil.set_normal(Vector3.UP)
	for case: Vector2i in _cases:
		var x := _origine.x + float(case.x) * maille
		var z := _origine.y + float(case.y) * maille
		var a := Vector3(x, altitude, z)
		var b := Vector3(x + maille, altitude, z)
		var d := Vector3(x, altitude, z + maille)
		var e := Vector3(x + maille, altitude, z + maille)
		for sommet in [a, b, e, a, e, d]:
			outil.set_uv(Vector2(sommet.x, sommet.z) / 8.0)
			outil.add_vertex(sommet)
	var materiau := StandardMaterial3D.new()
	materiau.albedo_color = couleur
	materiau.roughness = rugosite
	# Vu d'en haut seulement, mais le sens des faces n'a pas à compter.
	materiau.cull_mode = BaseMaterial3D.CULL_DISABLED
	var affichage := MeshInstance3D.new()
	affichage.name = "Sol"
	affichage.mesh = outil.commit()
	affichage.material_override = materiau
	racine.add_child(affichage)
