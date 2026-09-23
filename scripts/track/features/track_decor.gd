@tool
class_name TrackDecor
extends TrackFeature

## Du décor le long du tracé : une rangée de palmiers, de piliers enflammés,
## d'étoiles… Comme les autres éléments, il suit la courbe ; mais il ne se
## touche pas : rien ici n'a de collision, et la course ne le voit pas.
##
## Une rangée pose un objet tous les `espacement` mètres, à `decalage` mètres
## de l'axe, et sur l'autre rive aussi si `symetrique`. Un espacement nul
## pose un objet seul, au milieu : un phare, un repère.
##
## Tous les objets d'une rangée forment une seule MultiMesh : cinquante
## palmiers coûtent un appel de dessin, pas cinquante — ça compte sur mobile.

enum Objet { PALMIER, PHARE, PILIER_DE_FEU, ETOILE, CHAMPIGNON, ROCHER }

@export var objet: Objet = Objet.PALMIER:
	set(valeur):
		objet = valeur
		_modifie()

## Mètres entre deux objets le long du tracé ; zéro pour un objet seul.
@export_range(0.0, 200.0, 0.5) var espacement: float = 20.0:
	set(valeur):
		espacement = maxf(valeur, 0.0)
		_modifie()

@export var symetrique: bool = true:
	set(valeur):
		symetrique = valeur
		_modifie()

## Hauteur au-dessus du sol, en mètres. Les étoiles flottent.
@export_range(-20.0, 60.0, 0.5) var hauteur: float = 0.0:
	set(valeur):
		hauteur = valeur
		_modifie()

@export_range(0.2, 10.0, 0.05) var echelle: float = 1.0:
	set(valeur):
		echelle = valeur
		_modifie()

## Un peu de désordre : taille, orientation et place varient d'un objet à
## l'autre, toujours de la même façon pour une même graine.
@export var graine: int = 1:
	set(valeur):
		graine = valeur
		_modifie()


func _init() -> void:
	decalage = 14.0
	longueur = 100.0


## Les positions et orientations des objets, dans le repère du monde.
func placements(c: TrackCurve) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var poses: Array[Transform3D] = []
	var distances := PackedFloat32Array()
	if espacement <= 0.0:
		distances.append(debut + longueur * 0.5)
	else:
		var n := maxi(int(floor(longueur / espacement)), 0)
		for i in n + 1:
			distances.append(debut + espacement * float(i))
	var cotes := [1.0, -1.0] if symetrique else [1.0]
	for d in distances:
		for cote: float in cotes:
			var jeu := 0.0 if espacement <= 0.0 else rng.randf_range(-0.25, 0.25) * espacement
			var ici := d + jeu
			var lateral := decalage * cote + rng.randf_range(-1.0, 1.0) * (0.0 if espacement <= 0.0 else 1.5)
			var taille := echelle * (1.0 if espacement <= 0.0 else rng.randf_range(0.85, 1.15))
			var envol := hauteur * (1.0 if objet != Objet.ETOILE else rng.randf_range(0.6, 1.4))
			var ou := TrackFeature.point(c, ici, lateral, envol)
			var lacet := rng.randf_range(0.0, TAU) if objet != Objet.PHARE else 0.0
			var base := Basis(Vector3.UP, lacet).scaled(Vector3.ONE * taille)
			poses.append(Transform3D(base, ou))
	return poses


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var maillage := maillage_de(objet)
	var poses := placements(c)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = maillage
	multi.instance_count = poses.size()
	for i in poses.size():
		multi.set_instance_transform(i, poses[i])
	var affichage := MultiMeshInstance3D.new()
	affichage.multimesh = multi
	racine.add_child(affichage)


# --- Les objets -------------------------------------------------------------------
# Chacun est assemblé à partir de formes simples, colorées par sommet, en deux
# surfaces : ce qui est éclairé, et ce qui brille (flammes, étoiles, lanterne).

static var _cache: Dictionary = {}


static func maillage_de(quoi: Objet) -> ArrayMesh:
	if _cache.has(quoi):
		return _cache[quoi]
	var mat := _Assemblage.new()
	var brille := _Assemblage.new()
	match quoi:
		Objet.PALMIER:
			_palmier(mat)
		Objet.PHARE:
			_phare(mat, brille)
		Objet.PILIER_DE_FEU:
			_pilier(mat, brille)
		Objet.ETOILE:
			_etoile(brille)
		Objet.CHAMPIGNON:
			_champignon(mat)
		Objet.ROCHER:
			_rocher(mat)
	var maillage := ArrayMesh.new()
	if not mat.vide():
		mat.dans(maillage, _materiau(false))
	if not brille.vide():
		brille.dans(maillage, _materiau(true))
	_cache[quoi] = maillage
	return maillage


static func _materiau(lumineux: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# Les deux faces : les formes sont assemblées à la main, et une face
	# tournée du mauvais côté ferait un trou. Godot retourne alors la normale
	# des faces arrière, l'éclairage reste juste.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if lumineux:
		# Sans ombre ni éclairage : une flamme ou une étoile ne s'assombrit
		# pas côté nuit.
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.roughness = 0.85
	return m


static func _palmier(m: _Assemblage) -> void:
	var tronc := Color(0.55, 0.38, 0.2)
	# Un tronc qui penche un peu, en quatre tronçons de plus en plus fins.
	var sommet := Vector3.ZERO
	for i in 4:
		var bas := sommet
		sommet = bas + Vector3(0.18, 1.6, 0.0)
		m.cylindre(bas, sommet, 0.32 - 0.05 * i, 0.27 - 0.05 * i, tronc.darkened(0.08 * (i % 2)))
	# Des palmes : de longues feuilles plates qui retombent en arc.
	for i in 7:
		var angle := TAU * float(i) / 7.0
		var vers := Vector3(cos(angle), 0.0, sin(angle))
		var milieu := sommet + vers * 1.6 + Vector3.UP * 0.35
		var bout := sommet + vers * 3.0 - Vector3.UP * 0.7
		var cote := vers.cross(Vector3.UP).normalized() * 0.55
		var vert := Color(0.2, 0.62, 0.22) if i % 2 == 0 else Color(0.26, 0.7, 0.25)
		m.feuille(sommet, milieu, bout, cote, vert)
	for i in 3:
		var angle := TAU * float(i) / 3.0 + 0.4
		m.boule(sommet + Vector3(cos(angle), -0.35, sin(angle)) * 0.35, 0.22, Color(0.4, 0.26, 0.12))


static func _phare(m: _Assemblage, b: _Assemblage) -> void:
	# Une tour à bandes rouges et blanches, une galerie, une lanterne.
	for i in 6:
		var bas := Vector3.UP * (2.5 * i)
		var rayon_bas := 2.4 - 0.18 * i
		m.cylindre(bas, bas + Vector3.UP * 2.5, rayon_bas, rayon_bas - 0.18,
			Color(0.9, 0.15, 0.15) if i % 2 == 0 else Color(0.96, 0.96, 0.94))
	m.cylindre(Vector3.UP * 15.0, Vector3.UP * 15.4, 1.9, 1.9, Color(0.2, 0.2, 0.22))
	b.cylindre(Vector3.UP * 15.4, Vector3.UP * 17.2, 1.1, 1.1, Color(1.0, 0.92, 0.5))
	m.cone(Vector3.UP * 17.2, 1.5, 1.6, Color(0.85, 0.12, 0.12))
	m.cylindre(Vector3.DOWN * 1.0, Vector3.ZERO, 3.2, 3.2, Color(0.6, 0.58, 0.55))


static func _pilier(m: _Assemblage, b: _Assemblage) -> void:
	var pierre := Color(0.32, 0.3, 0.33)
	m.pave(Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 2.2), pierre.darkened(0.2))
	m.pave(Vector3(0, 3.2, 0), Vector3(1.5, 5.2, 1.5), pierre)
	m.pave(Vector3(0, 6.0, 0), Vector3(2.0, 0.5, 2.0), pierre.darkened(0.15))
	# La vasque, et un feu en trois flammes emboîtées.
	m.cylindre(Vector3.UP * 6.25, Vector3.UP * 6.9, 0.7, 1.0, Color(0.18, 0.16, 0.16))
	b.cone(Vector3.UP * 6.8, 0.85, 1.9, Color(1.0, 0.35, 0.05))
	b.cone(Vector3.UP * 6.85, 0.6, 1.5, Color(1.0, 0.65, 0.1))
	b.cone(Vector3.UP * 6.9, 0.35, 1.0, Color(1.0, 0.95, 0.5))


static func _etoile(b: _Assemblage) -> void:
	b.etoile(Vector3.ZERO, 1.6, 0.7, 0.45, Color(1.0, 0.9, 0.35))


static func _champignon(m: _Assemblage) -> void:
	m.cylindre(Vector3.ZERO, Vector3.UP * 3.0, 0.9, 0.75, Color(0.96, 0.93, 0.85))
	m.dome(Vector3.UP * 2.8, 2.6, 2.0, Color(0.9, 0.12, 0.12))
	# Les pois blancs, posés sur le chapeau.
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var ou := Vector3(cos(angle) * 1.75, 3.9, sin(angle) * 1.75)
		m.boule(ou, 0.5, Color(0.98, 0.98, 0.98))
	m.boule(Vector3.UP * 4.75, 0.6, Color(0.98, 0.98, 0.98))


static func _rocher(m: _Assemblage) -> void:
	m.boule(Vector3(0, 0.6, 0), 1.5, Color(0.5, 0.47, 0.44))
	m.boule(Vector3(1.1, 0.4, 0.5), 0.9, Color(0.45, 0.42, 0.4))
	m.boule(Vector3(-0.7, 0.3, -0.8), 0.8, Color(0.55, 0.52, 0.48))


## Un maillage en construction, fait de formes simples.
class _Assemblage:
	var outil := SurfaceTool.new()
	var _vide := true

	func _init() -> void:
		outil.begin(Mesh.PRIMITIVE_TRIANGLES)

	func vide() -> bool:
		return _vide

	func dans(maillage: ArrayMesh, materiau: Material) -> void:
		outil.generate_normals()
		var arrays := outil.commit_to_arrays()
		maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		maillage.surface_set_material(maillage.get_surface_count() - 1, materiau)

	func triangle(a: Vector3, b: Vector3, c: Vector3, couleur: Color) -> void:
		_vide = false
		outil.set_color(couleur)
		outil.add_vertex(a)
		outil.add_vertex(b)
		outil.add_vertex(c)

	## Un tronc de cône entre deux points, sans couvercle en bas.
	func cylindre(bas: Vector3, haut: Vector3, rayon_bas: float, rayon_haut: float,
			couleur: Color, cotes: int = 10) -> void:
		var axe := (haut - bas).normalized()
		var u := axe.cross(Vector3.FORWARD if absf(axe.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var v := axe.cross(u)
		for i in cotes:
			var a0 := TAU * float(i) / float(cotes)
			var a1 := TAU * float(i + 1) / float(cotes)
			var r0 := u * cos(a0) + v * sin(a0)
			var r1 := u * cos(a1) + v * sin(a1)
			triangle(bas + r0 * rayon_bas, haut + r0 * rayon_haut, bas + r1 * rayon_bas, couleur)
			triangle(bas + r1 * rayon_bas, haut + r0 * rayon_haut, haut + r1 * rayon_haut, couleur)
			triangle(haut, haut + r1 * rayon_haut, haut + r0 * rayon_haut, couleur)

	func cone(base: Vector3, rayon: float, hauteur: float, couleur: Color, cotes: int = 10) -> void:
		var pointe := base + Vector3.UP * hauteur
		for i in cotes:
			var a0 := TAU * float(i) / float(cotes)
			var a1 := TAU * float(i + 1) / float(cotes)
			var p0 := base + Vector3(cos(a0), 0.0, sin(a0)) * rayon
			var p1 := base + Vector3(cos(a1), 0.0, sin(a1)) * rayon
			triangle(p0, pointe, p1, couleur)
			triangle(base, p0, p1, couleur)

	## Une sphère aplatie en `hauteur` : le chapeau d'un champignon.
	func dome(base: Vector3, rayon: float, hauteur: float, couleur: Color) -> void:
		_sphere(base, Vector3(rayon, hauteur, rayon), couleur, 0.0, 12, 6)

	func boule(centre: Vector3, rayon: float, couleur: Color) -> void:
		_sphere(centre, Vector3.ONE * rayon, couleur, -PI * 0.5, 8, 6)

	func _sphere(centre: Vector3, rayons: Vector3, couleur: Color, depuis: float,
			tranches: int, anneaux: int) -> void:
		var pas := (PI * 0.5 - depuis) / float(anneaux)
		for j in anneaux:
			var l0 := depuis + pas * j
			var l1 := l0 + pas
			for i in tranches:
				var a0 := TAU * float(i) / float(tranches)
				var a1 := TAU * float(i + 1) / float(tranches)
				var p00 := centre + _sur(a0, l0) * rayons
				var p10 := centre + _sur(a1, l0) * rayons
				var p01 := centre + _sur(a0, l1) * rayons
				var p11 := centre + _sur(a1, l1) * rayons
				triangle(p00, p01, p10, couleur)
				triangle(p10, p01, p11, couleur)

	static func _sur(lon: float, lat: float) -> Vector3:
		return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))

	func pave(centre: Vector3, taille: Vector3, couleur: Color) -> void:
		var h := taille * 0.5
		var coins := []
		for k in 8:
			coins.append(centre + Vector3(h.x * (1 if k & 1 else -1), h.y * (1 if k & 2 else -1), h.z * (1 if k & 4 else -1)))
		# Six faces, chacune tournée vers l'extérieur.
		for f in [[0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6]]:
			triangle(coins[f[0]], coins[f[1]], coins[f[2]], couleur)
			triangle(coins[f[0]], coins[f[2]], coins[f[3]], couleur)

	## Une palme : deux triangles en arc, du pied au bout, larges au milieu.
	func feuille(pied: Vector3, milieu: Vector3, bout: Vector3, cote: Vector3, couleur: Color) -> void:
		for sens: float in [1.0, -1.0]:
			var bord := milieu + cote * sens
			triangle(pied, bord, milieu, couleur)
			triangle(milieu, bord, bout, couleur)
			# Le revers, pour qu'elle se voie aussi d'en dessous.
			triangle(pied, milieu, bord, couleur.darkened(0.15))
			triangle(milieu, bout, bord, couleur.darkened(0.15))

	## Une étoile à cinq branches, bombée des deux côtés.
	func etoile(centre: Vector3, rayon: float, creux: float, epaisseur: float, couleur: Color) -> void:
		var avant := centre + Vector3.FORWARD * epaisseur
		var arriere := centre + Vector3.BACK * epaisseur
		for i in 10:
			var a0 := PI * 0.5 + TAU * float(i) / 10.0
			var a1 := PI * 0.5 + TAU * float(i + 1) / 10.0
			var r0 := rayon if i % 2 == 0 else creux
			var r1 := rayon if (i + 1) % 2 == 0 else creux
			var p0 := centre + Vector3(cos(a0) * r0, sin(a0) * r0, 0.0)
			var p1 := centre + Vector3(cos(a1) * r1, sin(a1) * r1, 0.0)
			triangle(avant, p1, p0, couleur)
			triangle(arriere, p0, p1, couleur)
