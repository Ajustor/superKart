@tool
class_name TrackDecor
extends TrackFeature

## Du décor le long du tracé : une rangée de palmiers, de piliers enflammés,
## d'étoiles… Comme les autres éléments, il suit la courbe.
##
## Il se touche : un kart qui sort de la route bute contre un tronc, un
## rocher, un immeuble, comme contre un mur. Chaque objet a une forme de
## collision simple (un cylindre, une boîte) qui en suit le pied — sous un
## houppier ou un chapeau de champignon, on passe. Les étoiles, qui flottent,
## n'en ont pas.
##
## Une rangée pose un objet tous les `espacement` mètres, à `decalage` mètres
## de l'axe, et sur l'autre rive aussi si `symetrique`. Un espacement nul
## pose un objet seul, au milieu : un phare, un repère.
##
## Tous les objets d'une rangée forment une seule MultiMesh : cinquante
## palmiers coûtent un appel de dessin, pas cinquante — ça compte sur mobile.

enum Objet { PALMIER, PHARE, PILIER_DE_FEU, ETOILE, CHAMPIGNON, ROCHER, SAPIN, LAMPADAIRE, CRISTAL, IMMEUBLE,
	ARBRE, BOTTE_DE_FOIN, MOULIN, BUISSON, CACTUS, STALAGMITE, TOTEM, TONNEAU, CITROUILLE, ENGRENAGE,
	ANTENNE, FANTOME, NUAGE, PYLONE, TOUR_HORLOGE, MAISON, SALOON, ANANAS, TETE_DE_PIERRE, CORAIL,
	ALGUE, MASQUE, ARBRE_CUBE, BLOC, PILIER_OBSIDIENNE, SCULK, CADRE_OBSIDIENNE, LANTERNE,
	ARBRE_AUTOMNE, BONHOMME_DE_NEIGE, PARASOL, FLEUR, PANNEAU_LABO, TOURELLE, CUBE_LESTE, ESCALIER_FLOTTANT,
	FUSEE, PARABOLE, ROCHER_ROUGE,
	TRIBUNE, TENTE, TOUR_BANNIERE, DRAPEAU_DAMIER, PANNEAU_PUB, STANDS, LAMPADAIRE_COURSE }

## Ce qui flotte : on passe dessous ou au travers, sans collision, et sa
## hauteur varie d'un objet à l'autre.
const FLOTTANTS := [Objet.ETOILE, Objet.FANTOME, Objet.NUAGE, Objet.ESCALIER_FLOTTANT]


## Ce qui longe la route au lieu d'être tourné au hasard.
const ALIGNES := [Objet.PANNEAU_LABO]

## Ce qui regarde la route : les tribunes, les tentes, les panneaux du bord de
## piste (le Racing Kit de Kenney, voir KenneyDecor.COURSE).
const FACE_A_LA_ROUTE := [Objet.TRIBUNE, Objet.TENTE, Objet.TOUR_BANNIERE, Objet.DRAPEAU_DAMIER,
	Objet.PANNEAU_PUB, Objet.STANDS, Objet.LAMPADAIRE_COURSE]


static func flotte(quoi: Objet) -> bool:
	return quoi in FLOTTANTS

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

## Ne pose rien sur la route : là où le tracé revient sur lui-même (une
## épingle), une rangée posée au bord d'une branche tomberait sur l'autre.
@export var eviter_la_route: bool = false:
	set(valeur):
		eviter_la_route = valeur
		_modifie()

## Faux : on traverse la rangée. Pour un décor posé là où les karts doivent
## passer, ou qui ne fait que de l'ombre au loin.
@export var solide: bool = true:
	set(valeur):
		solide = valeur
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
			var envol := hauteur * (1.0 if not flotte(objet) else rng.randf_range(0.6, 1.4))
			var ou := TrackFeature.point(c, ici, lateral, envol)
			if eviter_la_route and _sur_la_route(c, ou):
				continue
			# Sur le relief du circuit, s'il en a un : loin de la route, le sol
			# n'est plus à la hauteur du bitume.
			# Un relief limité à une portion ne porte que les décors de cette
			# portion : sur la lune, l'arbre ne descend pas jusqu'à Termina.
			var sol := _terrain_en(wrapf(ici, 0.0, c.length), c.length)
			if sol != null and absf(lateral) > c.half_width:
				ou.y = sol.hauteur_en(ou.x, ou.z) + envol
				# Posé sur le relief, il peut tomber sur une route plus basse :
				# sous des lacets, le sol est celui de la route du dessous.
				# Un sapin de six mètres posé quatre mètres sous une route la
				# percerait : on regarde jusqu'à douze mètres plus bas.
				if eviter_la_route and _sur_la_route(c, ou - Vector3.UP * envol, 12.0):
					continue
			elif absf(lateral) > c.half_width and not flotte(objet):
				ou = _pose_sur_le_sol_plat(c, ici, lateral, ou, envol)
			var lacet := rng.randf_range(0.0, TAU) if objet != Objet.PHARE else 0.0
			# Un pan de mur longe la route, il ne se pose pas en vrac.
			if objet in ALIGNES:
				var avant := c.forward_at(wrapf(ici, 0.0, c.length))
				lacet = atan2(-avant.z, avant.x)
			elif objet in FACE_A_LA_ROUTE:
				# Leur face (+z) vers l'axe de la route.
				var vers_la_route := -c.right_at(wrapf(ici, 0.0, c.length)) * signf(lateral)
				lacet = atan2(vers_la_route.x, vers_la_route.z)
			var base := Basis(Vector3.UP, lacet).scaled(Vector3.ONE * taille)
			poses.append(Transform3D(base, ou))
	return poses


## `dessous` : jusqu'où sous la route un objet compte encore comme dessus.
func _sur_la_route(c: TrackCurve, ou: Vector3, dessous := 4.0) -> bool:
	var d := c.distance_of(ou)
	var proche := c.position_at(d)
	# Trop haut ou trop bas : c'est une autre partie du relief, pas la route.
	if ou.y - proche.y > 4.0 or proche.y - ou.y > dessous:
		return false
	return absf(c.lateral_offset_at(ou, d)) < c.half_width + 4.0


## Sur un sol plat (TrackSol) un peu plus bas que la route : au-delà des
## bas-côtés, l'objet descend jusqu'au sol au lieu de flotter à hauteur de
## bitume — ou remonte, s'il s'enfonçait à l'intérieur d'un virage relevé.
## Pas sur un bas-côté, qui est à hauteur de route ; pas là où le sol est
## percé (une galerie passe dessous) ; pas sous un pont.
func _pose_sur_le_sol_plat(c: TrackCurve, ici: float, lateral: float, ou: Vector3, envol: float) -> Vector3:
	var circuit := piste()
	if circuit == null:
		return ou
	var pied := ou.y - envol
	var plus_haut := -INF
	for element in circuit.elements():
		if element is TrackOffroad and element.contient(ici, lateral, c.length):
			return ou
		if element is TrackSol:
			var sol := element as TrackSol
			var chute := pied - sol.altitude
			if chute > -2.0 and chute <= TrackSol.POSE_MAX and sol.altitude > plus_haut \
					and sol.a_du_sol(Vector2(ou.x, ou.z)):
				plus_haut = sol.altitude
	if plus_haut == -INF:
		return ou
	return Vector3(ou.x, plus_haut + envol, ou.z)


## Le relief sous cette distance : un circuit peut en avoir un par portion,
## un par saison.
func _terrain_en(distance: float, tour: float) -> TrackTerrain:
	var circuit := piste()
	if circuit == null:
		return null
	for element in circuit.elements():
		if element is TrackTerrain and (not element.portion or element.couvre(distance, tour)):
			return element
	return null


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
	if solide:
		var corps := corps_de_collision(poses)
		if corps != null:
			racine.add_child(corps)


## Un seul corps pour toute la rangée, quelques formes par objet. Des
## prismes convexes plutôt que le maillage : ils se testent en un rien de
## temps, et n'accrochent pas le kart sur chaque facette.
func corps_de_collision(poses: Array[Transform3D]) -> StaticBody3D:
	var gabarit := forme_de(objet)
	if gabarit.is_empty() or poses.is_empty():
		return null
	var corps := StaticBody3D.new()
	corps.name = "Collisions"
	corps.collision_layer = Kart.COUCHE_DECOR
	corps.collision_mask = 0
	var prismes := prismes_de(objet)
	for pose in poses:
		var taille := pose.basis.get_scale().x
		var sens := pose.basis.orthonormalized()
		if not prismes.is_empty():
			for prisme: Dictionary in prismes:
				var points := PackedVector3Array()
				for p: Vector2 in prisme.contour:
					points.append(Vector3(p.x, prisme.bas, p.y) * taille)
					points.append(Vector3(p.x, prisme.haut, p.y) * taille)
				var convexe := ConvexPolygonShape3D.new()
				convexe.points = points
				var piece := CollisionShape3D.new()
				piece.shape = convexe
				piece.transform = Transform3D(sens, pose.origin)
				corps.add_child(piece)
			continue
		var forme := CollisionShape3D.new()
		if gabarit.type == "cylindre":
			var cylindre := CylinderShape3D.new()
			cylindre.radius = gabarit.rayon * taille
			cylindre.height = gabarit.hauteur * taille
			forme.shape = cylindre
		else:
			var boite := BoxShape3D.new()
			boite.size = gabarit.taille * taille
			forme.shape = boite
		forme.transform = Transform3D(sens, pose.origin + sens * (gabarit.centre * taille))
		corps.add_child(forme)
	return corps


## La hauteur de kart : la caisse va de 3 à 73 cm au-dessus du sol. Elle
## heurte un objet là où il est le plus large entre les deux.
const KART_BAS := 0.05
const KART_HAUT := 0.73
## Deux morceaux du modèle plus proches que ça font un seul obstacle.
const MAILLE_DE_FORME := 0.2
## Les sommets d'un prisme, au plus.
const SOMMETS_MAX := 16
## Une enveloppe qui passe plus loin que ça du modèle enjambe un creux (une
## porte, l'ouverture d'un garage) ; en deçà, ce n'est qu'une bosse, et
## l'enveloppe suffit.
const CREUX := 0.1
const COUPES_MAX := 4

static var _prismes: Dictionary = {}


## Les formes de collision d'un objet à l'échelle 1, tirées de son modèle à
## hauteur de kart : des prismes convexes, {contour (x, z), bas, haut}. Vide
## si le modèle n'a rien à cette hauteur (le pylône, qui pend sous la
## route) : son gabarit (forme_de) sert alors tel quel.
##
## Les gabarits faits main ne suivaient pas les modèles Kenney rééchelonnés :
## une tente faisait un bloc de 6 × 4 × 6 m où l'on ne voit que quatre
## montants, un panneau une dalle de 8 m sous un panneau perché, un sapin un
## mètre de trop. Ici, le modèle à hauteur de kart est coupé en morceaux d'un
## seul tenant, et chacun devient l'enveloppe convexe de ce qu'on y voit. Le
## gabarit ne donne plus que la hauteur : ce qui touche le haut de la tranche
## monte jusqu'à son sommet, ce qui touche le bas descend jusqu'à son pied.
static func prismes_de(quoi: Objet) -> Array:
	if _prismes.has(quoi):
		return _prismes[quoi]
	var gabarit := forme_de(quoi)
	var prismes := []
	if not gabarit.is_empty():
		var demi: float = gabarit.hauteur * 0.5 if gabarit.type == "cylindre" else gabarit.taille.y * 0.5
		var pied: float = gabarit.centre.y - demi
		var sommet: float = gabarit.centre.y + demi
		prismes = _morceaux(_triangles(maillage_de(quoi)), KART_BAS, KART_HAUT)
		for m: Dictionary in prismes:
			if m.bas <= KART_BAS + 0.01:
				m.bas = minf(m.bas, pied)
			if m.haut >= KART_HAUT - 0.01:
				m.haut = maxf(m.haut, sommet)
	_prismes[quoi] = prismes
	return prismes


## Les triangles d'un maillage, toutes surfaces.
static func _triangles(maillage: ArrayMesh) -> PackedVector3Array:
	var triangles := PackedVector3Array()
	for s in maillage.get_surface_count():
		var tableaux := maillage.surface_get_arrays(s)
		var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
		var indices = tableaux[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
			for i in indices:
				triangles.append(sommets[i])
		else:
			triangles.append_array(sommets)
	return triangles


## Les morceaux du modèle entre y0 et y1 : leurs contours convexes vus d'en
## haut, et ce qu'ils occupent en hauteur, {contour, bas, haut}.
static func _morceaux(triangles: PackedVector3Array, y0: float, y1: float) -> Array:
	# Chaque triangle coupé à la tranche ; le bord de ce qui reste, en
	# points tous les 5 cm.
	var cases := {}
	for t in range(0, triangles.size(), 3):
		var poly := _couper([triangles[t], triangles[t + 1], triangles[t + 2]], y0, y1)
		for i in poly.size():
			var a: Vector3 = poly[i]
			var b: Vector3 = poly[(i + 1) % poly.size()]
			var n := maxi(ceili(Vector2(a.x - b.x, a.z - b.z).length() / 0.05), 1)
			for k in n:
				var p := a.lerp(b, float(k) / n)
				var cle := Vector2i(floori(p.x / MAILLE_DE_FORME), floori(p.z / MAILLE_DE_FORME))
				if not cases.has(cle):
					cases[cle] = PackedVector3Array()
				cases[cle].append(p)
	if cases.is_empty():
		return []
	var plein := _Coupe.new(cases)
	# Les cases voisines font un morceau.
	var contours := []
	var vues := {}
	for depart: Vector2i in cases:
		if vues.has(depart):
			continue
		vues[depart] = true
		var pile: Array[Vector2i] = [depart]
		var points := PackedVector3Array()
		while not pile.is_empty():
			var c: Vector2i = pile.pop_back()
			points.append_array(cases[c])
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var voisine := c + Vector2i(dx, dz)
					if cases.has(voisine) and not vues.has(voisine):
						vues[voisine] = true
						pile.append(voisine)
		contours.append_array(_convexes(points, plein))
	return contours


## La coupe du modèle à une tranche, sur une grille de 5 cm : pleine là où
## est le modèle, son bord comme son dedans. Le dehors se trouve en
## remplissant depuis les bords de la grille ; ce qu'il n'atteint pas est
## dedans.
class _Coupe:
	const COTE := 0.05
	var origine: Vector2
	var largeur: int
	var hauteur: int
	## 0 : dehors ; 1 : bord ; 2 : dedans.
	var cases := PackedByteArray()

	func _init(points_par_case: Dictionary) -> void:
		var mini := Vector2(INF, INF)
		var maxi := Vector2(-INF, -INF)
		for c in points_par_case:
			for p: Vector3 in points_par_case[c]:
				mini = mini.min(Vector2(p.x, p.z))
				maxi = maxi.max(Vector2(p.x, p.z))
		origine = mini - Vector2.ONE * 2.0 * COTE
		largeur = ceili((maxi.x - origine.x) / COTE) + 3
		hauteur = ceili((maxi.y - origine.y) / COTE) + 3
		cases.resize(largeur * hauteur)
		cases.fill(2)
		for c in points_par_case:
			for p: Vector3 in points_par_case[c]:
				cases[_indice(Vector2(p.x, p.z))] = 1
		# Le dehors, de proche en proche (sans les diagonales : un mur en
		# biais ne laisse pas passer).
		var pile := PackedInt32Array([0])
		cases[0] = 0
		while not pile.is_empty():
			var i := pile[pile.size() - 1]
			pile.remove_at(pile.size() - 1)
			var x := i % largeur
			var z := i / largeur
			for v: Vector2i in [Vector2i(x - 1, z), Vector2i(x + 1, z), Vector2i(x, z - 1), Vector2i(x, z + 1)]:
				if v.x < 0 or v.y < 0 or v.x >= largeur or v.y >= hauteur:
					continue
				var j := v.y * largeur + v.x
				if cases[j] == 2:
					cases[j] = 0
					pile.append(j)

	func _indice(p: Vector2) -> int:
		var x := clampi(floori((p.x - origine.x) / COTE), 0, largeur - 1)
		var z := clampi(floori((p.y - origine.y) / COTE), 0, hauteur - 1)
		return z * largeur + x

	## La coupe dans `zone`, pavée de rectangles : chacun s'étend d'abord en
	## largeur, puis en profondeur tant que la rangée reste pleine.
	func rectangles(zone: Rect2) -> Array[Rect2]:
		var x0 := clampi(floori((zone.position.x - origine.x) / COTE), 0, largeur - 1)
		var z0 := clampi(floori((zone.position.y - origine.y) / COTE), 0, hauteur - 1)
		var x1 := clampi(floori((zone.end.x - origine.x) / COTE), 0, largeur - 1)
		var z1 := clampi(floori((zone.end.y - origine.y) / COTE), 0, hauteur - 1)
		var pris := {}
		var liste: Array[Rect2] = []
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				if cases[z * largeur + x] == 0 or pris.has(z * largeur + x):
					continue
				var fin_x := x
				while fin_x + 1 <= x1 and cases[z * largeur + fin_x + 1] != 0 and not pris.has(z * largeur + fin_x + 1):
					fin_x += 1
				var fin_z := z
				while fin_z + 1 <= z1:
					var pleine := true
					for xx in range(x, fin_x + 1):
						var k := (fin_z + 1) * largeur + xx
						if cases[k] == 0 or pris.has(k):
							pleine = false
							break
					if not pleine:
						break
					fin_z += 1
				for zz in range(z, fin_z + 1):
					for xx in range(x, fin_x + 1):
						pris[zz * largeur + xx] = true
				liste.append(Rect2(origine + Vector2(x, z) * COTE, Vector2(fin_x - x + 1, fin_z - z + 1) * COTE))
		return liste

	## Ce point est-il dans le modèle, ou à moins de `portee` ?
	func pres(p: Vector2, portee: float) -> bool:
		var x := floori((p.x - origine.x) / COTE)
		var z := floori((p.y - origine.y) / COTE)
		var n := ceili(portee / COTE)
		for dx in range(-n, n + 1):
			for dz in range(-n, n + 1):
				var v := Vector2i(x + dx, z + dz)
				if v.x < 0 or v.y < 0 or v.x >= largeur or v.y >= hauteur or cases[v.y * largeur + v.x] == 0:
					continue
				# Le point de la case le plus proche.
				var coin := origine + Vector2(v) * COTE
				var proche := p.clamp(coin, coin + Vector2.ONE * COTE)
				if proche.distance_to(p) <= portee:
					return true
		return false


## Les prismes d'un morceau : son enveloppe convexe, s'il n'a pas de creux.
## Sinon, coupé en deux le long de sa plus grande dimension, et ainsi de
## suite ; au-delà de COUPES_MAX coupes (un bâtiment, sa porte, ses
## fenêtres), la coupe pavée de rectangles, au plus 5 cm au-delà du modèle.
static func _convexes(points: PackedVector3Array, plein: _Coupe, coupes: int = 0) -> Array:
	var plan := PackedVector2Array()
	var bas := INF
	var haut := -INF
	for p in points:
		plan.append(Vector2(p.x, p.z))
		bas = minf(bas, p.y)
		haut = maxf(haut, p.y)
	var enveloppe := _simplifier(Geometry2D.convex_hull(plan))
	if not _enjambe_un_creux(enveloppe, plein):
		return [{contour = enveloppe, bas = bas, haut = haut}]
	var boite := _emprise(plan)
	if coupes >= COUPES_MAX:
		var pieces := []
		for r: Rect2 in plein.rectangles(boite):
			pieces.append({contour = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
				Vector2(r.position.x, r.end.y)]), bas = bas, haut = haut})
		return pieces
	var en_x := boite.size.x >= boite.size.y
	var milieu: float = boite.get_center().x if en_x else boite.get_center().y
	var avant := PackedVector3Array()
	var apres := PackedVector3Array()
	for p in points:
		if (p.x if en_x else p.z) < milieu:
			avant.append(p)
		else:
			apres.append(p)
	# La coupe, là où elle traverse le plein, aux deux moitiés : leurs
	# enveloppes s'y rejoignent, sans déborder dans le vide. Chacune la
	# dépasse d'un centimètre : bord à bord, un rayon passait entre les deux.
	var debut: float = boite.position.y if en_x else boite.position.x
	var fin: float = boite.end.y if en_x else boite.end.x
	var t := debut
	while t <= fin:
		var ici := Vector2(milieu, t) if en_x else Vector2(t, milieu)
		if plein.pres(ici, 0.0):
			var pas := Vector2(0.01, 0.0) if en_x else Vector2(0.0, 0.01)
			for y in [bas, haut]:
				avant.append(Vector3(ici.x + pas.x, y, ici.y + pas.y))
				apres.append(Vector3(ici.x - pas.x, y, ici.y - pas.y))
		t += 0.05
	if avant.size() < 3 or apres.size() < 3:
		return [{contour = enveloppe, bas = bas, haut = haut}]
	return _convexes(avant, plein, coupes + 1) + _convexes(apres, plein, coupes + 1)


## L'enveloppe passe-t-elle quelque part à plus de CREUX du modèle, dehors ?
## Le long d'une coupe, elle traverse le dedans : ce n'est pas un creux.
static func _enjambe_un_creux(enveloppe: PackedVector2Array, plein: _Coupe) -> bool:
	for i in enveloppe.size():
		var a := enveloppe[i]
		var b := enveloppe[(i + 1) % enveloppe.size()]
		var n := maxi(ceili(a.distance_to(b) / 0.05), 1)
		for k in n:
			if not plein.pres(a.lerp(b, float(k) / n), CREUX):
				return true
	return false


## Le triangle coupé entre les plans y = y0 et y = y1 : un polygone, vide
## s'il est tout entier dehors.
static func _couper(poly: Array, y0: float, y1: float) -> Array:
	for plan: Array in [[y0, 1.0], [y1, -1.0]]:
		var h: float = plan[0]
		var sens: float = plan[1]
		var garde := []
		for i in poly.size():
			var a: Vector3 = poly[i]
			var b: Vector3 = poly[(i + 1) % poly.size()]
			var da := (a.y - h) * sens
			var db := (b.y - h) * sens
			if da >= 0.0:
				garde.append(a)
			if (da >= 0.0) != (db >= 0.0):
				garde.append(a.lerp(b, da / (da - db)))
		poly = garde
		if poly.is_empty():
			return poly
	return poly


## Au plus SOMMETS_MAX sommets : on retire, un à un, celui qui couvre le moins.
## Le contour ne fait que rentrer, de quelques millimètres.
static func _simplifier(contour: PackedVector2Array) -> PackedVector2Array:
	var points := contour
	# convex_hull referme le contour en répétant son premier point.
	if points.size() > 1 and points[0] == points[points.size() - 1]:
		points.remove_at(points.size() - 1)
	while points.size() > SOMMETS_MAX:
		var moindre := 0
		var aire_min := INF
		for i in points.size():
			var a := points[(i - 1 + points.size()) % points.size()]
			var b := points[i]
			var c := points[(i + 1) % points.size()]
			var aire := absf((b - a).cross(c - a))
			if aire < aire_min:
				aire_min = aire
				moindre = i
		points.remove_at(moindre)
	return points


## Le rectangle qui contient ces points.
static func _emprise(contour: PackedVector2Array) -> Rect2:
	var r := Rect2(contour[0], Vector2.ZERO)
	for p in contour:
		r = r.expand(p)
	return r


## Le gabarit d'un objet à l'échelle 1, dans son propre repère : un cylindre
## (rayon, hauteur) ou une boîte (taille), et son centre. Vide pour ce qui
## ne se touche pas.
##
## Il ne donne plus que la hauteur des prismes (prismes_de), sauf pour ce qui
## n'a rien à hauteur de kart.
static func forme_de(quoi: Objet) -> Dictionary:
	match quoi:
		Objet.PALMIER:
			# Le tronc penche de 18 cm par tronçon : on le prend en son milieu.
			return {type = "cylindre", rayon = 0.4, hauteur = 6.4, centre = Vector3(0.36, 3.2, 0.0)}
		Objet.PHARE:
			return {type = "cylindre", rayon = 2.4, hauteur = 17.0, centre = Vector3(0.0, 8.5, 0.0)}
		Objet.PILIER_DE_FEU:
			return {type = "boite", taille = Vector3(2.0, 6.5, 2.0), centre = Vector3(0.0, 3.25, 0.0)}
		Objet.CHAMPIGNON:
			return {type = "cylindre", rayon = 0.9, hauteur = 3.0, centre = Vector3(0.0, 1.5, 0.0)}
		Objet.ROCHER:
			# Un cylindre plutôt qu'une boule : une boule posée à demi dans le
			# sol ferait tremplin.
			return {type = "cylindre", rayon = 1.6, hauteur = 2.2, centre = Vector3(0.0, 0.6, 0.0)}
		Objet.SAPIN:
			# Les branches du bas descendent à un mètre du sol : à hauteur de
			# caisse, on les touche.
			return {type = "cylindre", rayon = 1.3, hauteur = 4.0, centre = Vector3(0.0, 2.0, 0.0)}
		Objet.LAMPADAIRE:
			return {type = "cylindre", rayon = 0.2, hauteur = 6.0, centre = Vector3(0.0, 3.0, 0.0)}
		Objet.CRISTAL:
			return {type = "cylindre", rayon = 1.0, hauteur = 3.0, centre = Vector3(0.0, 1.5, 0.0)}
		Objet.IMMEUBLE:
			return {type = "boite", taille = Vector3(8.0, 18.0, 8.0), centre = Vector3(0.0, 9.0, 0.0)}
		Objet.ARBRE:
			return {type = "cylindre", rayon = 0.45, hauteur = 3.0, centre = Vector3(0.0, 1.5, 0.0)}
		Objet.BOTTE_DE_FOIN:
			return {type = "boite", taille = Vector3(1.6, 1.5, 1.5), centre = Vector3(0.0, 0.75, 0.0)}
		Objet.MOULIN:
			return {type = "cylindre", rayon = 2.8, hauteur = 9.0, centre = Vector3(0.0, 4.5, 0.0)}
		Objet.BUISSON:
			return {type = "boite", taille = Vector3(3.0, 1.2, 1.6), centre = Vector3(0.0, 0.55, 0.0)}
		Objet.CACTUS:
			return {type = "cylindre", rayon = 0.5, hauteur = 4.5, centre = Vector3(0.0, 2.25, 0.0)}
		Objet.STALAGMITE:
			return {type = "cylindre", rayon = 1.1, hauteur = 3.0, centre = Vector3(0.0, 1.5, 0.0)}
		Objet.TOTEM:
			return {type = "boite", taille = Vector3(1.6, 6.0, 1.6), centre = Vector3(0.0, 3.0, 0.0)}
		Objet.TONNEAU:
			return {type = "cylindre", rayon = 0.7, hauteur = 1.6, centre = Vector3(0.0, 0.8, 0.0)}
		Objet.CITROUILLE:
			return {type = "cylindre", rayon = 1.1, hauteur = 1.6, centre = Vector3(0.0, 0.8, 0.0)}
		Objet.ENGRENAGE:
			return {type = "cylindre", rayon = 0.6, hauteur = 4.0, centre = Vector3(0.0, 2.0, 0.0)}
		Objet.ANTENNE:
			return {type = "cylindre", rayon = 0.9, hauteur = 3.0, centre = Vector3(0.0, 1.5, 0.0)}
		Objet.TOUR_HORLOGE:
			return {type = "boite", taille = Vector3(10.0, 12.0, 10.0), centre = Vector3(0.0, 6.0, 0.0)}
		Objet.MAISON:
			return {type = "boite", taille = Vector3(8.0, 4.0, 7.0), centre = Vector3(0.0, 2.0, 0.0)}
		Objet.SALOON:
			return {type = "boite", taille = Vector3(9.0, 5.0, 6.0), centre = Vector3(0.0, 2.5, 0.0)}
		Objet.ANANAS:
			return {type = "cylindre", rayon = 3.0, hauteur = 5.0, centre = Vector3(0.0, 2.5, 0.0)}
		Objet.TETE_DE_PIERRE:
			return {type = "boite", taille = Vector3(3.2, 6.0, 3.2), centre = Vector3(0.0, 3.0, 0.0)}
		Objet.CORAIL:
			return {type = "cylindre", rayon = 0.8, hauteur = 2.0, centre = Vector3(0.0, 1.0, 0.0)}
		Objet.ALGUE:
			return {type = "cylindre", rayon = 0.3, hauteur = 3.0, centre = Vector3(0.0, 1.5, 0.0)}
		Objet.MASQUE:
			return {type = "cylindre", rayon = 0.4, hauteur = 6.0, centre = Vector3(0.0, 3.0, 0.0)}
		Objet.ARBRE_CUBE:
			return {type = "boite", taille = Vector3(1.0, 4.0, 1.0), centre = Vector3(0.0, 2.0, 0.0)}
		Objet.BLOC:
			return {type = "boite", taille = Vector3(2.0, 2.0, 2.0), centre = Vector3(0.0, 1.0, 0.0)}
		Objet.PILIER_OBSIDIENNE:
			return {type = "boite", taille = Vector3(4.0, 30.0, 4.0), centre = Vector3(0.0, 15.0, 0.0)}
		Objet.SCULK:
			return {type = "boite", taille = Vector3(1.6, 1.2, 1.6), centre = Vector3(0.0, 0.6, 0.0)}
		Objet.CADRE_OBSIDIENNE:
			return {type = "boite", taille = Vector3(5.0, 6.0, 1.2), centre = Vector3(0.0, 3.0, 0.0)}
		Objet.LANTERNE:
			return {type = "cylindre", rayon = 0.2, hauteur = 4.0, centre = Vector3(0.0, 2.0, 0.0)}
		Objet.ARBRE_AUTOMNE:
			return {type = "cylindre", rayon = 0.45, hauteur = 3.0, centre = Vector3(0.0, 1.5, 0.0)}
		Objet.BONHOMME_DE_NEIGE:
			return {type = "cylindre", rayon = 1.1, hauteur = 2.4, centre = Vector3(0.0, 1.2, 0.0)}
		Objet.PARASOL:
			return {type = "cylindre", rayon = 0.12, hauteur = 3.0, centre = Vector3(0.0, 1.5, 0.0)}
		Objet.FLEUR:
			return {type = "cylindre", rayon = 0.25, hauteur = 3.0, centre = Vector3(0.0, 1.5, 0.0)}
		Objet.PANNEAU_LABO:
			return {type = "boite", taille = Vector3(6.0, 5.0, 0.6), centre = Vector3(0.0, 2.5, 0.0)}
		Objet.TOURELLE:
			return {type = "cylindre", rayon = 0.6, hauteur = 2.0, centre = Vector3(0.0, 1.0, 0.0)}
		Objet.CUBE_LESTE:
			return {type = "boite", taille = Vector3(1.6, 1.6, 1.6), centre = Vector3(0.0, 0.8, 0.0)}
		Objet.FUSEE:
			return {type = "cylindre", rayon = 2.2, hauteur = 22.0, centre = Vector3(0.0, 11.0, 0.0)}
		Objet.PARABOLE:
			return {type = "cylindre", rayon = 0.5, hauteur = 4.0, centre = Vector3(0.0, 2.0, 0.0)}
		Objet.ROCHER_ROUGE:
			return {type = "cylindre", rayon = 1.6, hauteur = 2.2, centre = Vector3(0.0, 0.6, 0.0)}
		Objet.TRIBUNE, Objet.STANDS:
			return {type = "boite", taille = Vector3(10.0, 8.0, 10.0), centre = Vector3(0.0, 4.0, 0.0)}
		Objet.TENTE:
			return {type = "boite", taille = Vector3(6.0, 4.0, 6.0), centre = Vector3(0.0, 2.0, 0.0)}
		Objet.TOUR_BANNIERE:
			return {type = "boite", taille = Vector3(2.4, 8.0, 2.4), centre = Vector3(0.0, 4.0, 0.0)}
		Objet.PANNEAU_PUB:
			return {type = "boite", taille = Vector3(8.0, 8.0, 1.0), centre = Vector3(0.0, 4.0, 0.0)}
		Objet.DRAPEAU_DAMIER, Objet.LAMPADAIRE_COURSE:
			return {type = "cylindre", rayon = 0.25, hauteur = 6.0, centre = Vector3(0.0, 3.0, 0.0)}
		Objet.PYLONE:
			# Il pend sous la route : personne ne l'atteint, mais il se touche.
			return {type = "cylindre", rayon = 0.6, hauteur = 60.0, centre = Vector3(0.0, -30.3, 0.0)}
	return {}


# --- Les objets -------------------------------------------------------------------
# Chacun est assemblé à partir de formes simples, colorées par sommet, en deux
# surfaces : ce qui est éclairé, et ce qui brille (flammes, étoiles, lanterne).

static var _cache: Dictionary = {}


static func maillage_de(quoi: Objet) -> ArrayMesh:
	if _cache.has(quoi):
		return _cache[quoi]
	if KenneyDecor.COURSE.has(quoi):
		_cache[quoi] = KenneyDecor.maillage_de_course(quoi)
		return _cache[quoi]
	var maillage := _fait_main(quoi)
	# Le modèle Kenney, s'il y en a un, à la taille de l'objet fait main.
	if KenneyDecor.a_un_modele(quoi):
		maillage = KenneyDecor.maillage(quoi, maillage.get_aabb())
	_cache[quoi] = maillage
	return maillage


static func _fait_main(quoi: Objet) -> ArrayMesh:
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
		Objet.SAPIN:
			_sapin(mat)
		Objet.LAMPADAIRE:
			_lampadaire(mat, brille)
		Objet.CRISTAL:
			_cristal(brille)
		Objet.IMMEUBLE:
			_immeuble(mat, brille)
		Objet.ARBRE:
			_arbre(mat)
		Objet.BOTTE_DE_FOIN:
			_botte(mat)
		Objet.MOULIN:
			_moulin(mat)
		Objet.BUISSON:
			_buisson(mat)
		Objet.CACTUS:
			_cactus(mat)
		Objet.STALAGMITE:
			_stalagmite(mat, brille)
		Objet.TOTEM:
			_totem(mat)
		Objet.TONNEAU:
			_tonneau(mat)
		Objet.CITROUILLE:
			_citrouille(mat, brille)
		Objet.ENGRENAGE:
			_engrenage(mat)
		Objet.ANTENNE:
			_antenne(mat, brille)
		Objet.FANTOME:
			_fantome(brille)
		Objet.NUAGE:
			_nuage(mat)
		Objet.PYLONE:
			_pylone(mat)
		Objet.TOUR_HORLOGE:
			_tour_horloge(mat, brille)
		Objet.MAISON:
			_maison(mat, brille)
		Objet.SALOON:
			_saloon(mat, brille)
		Objet.ANANAS:
			_ananas(mat, brille)
		Objet.TETE_DE_PIERRE:
			_tete_de_pierre(mat)
		Objet.CORAIL:
			_corail(mat)
		Objet.ALGUE:
			_algue(mat)
		Objet.MASQUE:
			_masque(mat, brille)
		Objet.ARBRE_CUBE:
			_arbre_cube(mat)
		Objet.BLOC:
			_bloc(mat)
		Objet.PILIER_OBSIDIENNE:
			_pilier_obsidienne(mat, brille)
		Objet.SCULK:
			_sculk(mat, brille)
		Objet.CADRE_OBSIDIENNE:
			_cadre_obsidienne(mat, brille)
		Objet.LANTERNE:
			_lanterne(mat, brille)
		Objet.ARBRE_AUTOMNE:
			_arbre_automne(mat)
		Objet.BONHOMME_DE_NEIGE:
			_bonhomme(mat)
		Objet.PARASOL:
			_parasol(mat)
		Objet.FLEUR:
			_fleur(mat, brille)
		Objet.PANNEAU_LABO:
			_panneau_labo(mat, brille)
		Objet.TOURELLE:
			_tourelle(mat, brille)
		Objet.CUBE_LESTE:
			_cube_leste(mat, brille)
		Objet.ESCALIER_FLOTTANT:
			_escalier_flottant(mat)
		Objet.FUSEE:
			_fusee(mat, brille)
		Objet.PARABOLE:
			_parabole(mat, brille)
		Objet.ROCHER_ROUGE:
			_rocher_rouge(mat)
	var maillage := ArrayMesh.new()
	if not mat.vide():
		mat.dans(maillage, _materiau(false))
	if not brille.vide():
		brille.dans(maillage, _materiau(true))
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


static func _sapin(m: _Assemblage) -> void:
	m.cylindre(Vector3.ZERO, Vector3.UP * 1.2, 0.3, 0.25, Color(0.4, 0.26, 0.15))
	# Trois étages de branches, chacun coiffé de neige.
	for i in 3:
		var base := Vector3.UP * (1.0 + 1.3 * i)
		var rayon := 2.1 - 0.55 * i
		m.cone(base, rayon, 2.0, Color(0.12, 0.38, 0.2).darkened(0.08 * i))
		m.cone(base + Vector3.UP * 1.3, rayon * 0.38, 0.75, Color(0.95, 0.97, 1.0))


static func _lampadaire(m: _Assemblage, b: _Assemblage) -> void:
	var metal := Color(0.2, 0.22, 0.26)
	m.cylindre(Vector3.ZERO, Vector3.UP * 6.0, 0.14, 0.1, metal)
	m.cylindre(Vector3.UP * 6.0, Vector3(1.2, 6.3, 0.0), 0.08, 0.08, metal)
	m.pave(Vector3(1.3, 6.2, 0.0), Vector3(0.7, 0.2, 0.4), metal)
	b.pave(Vector3(1.3, 6.05, 0.0), Vector3(0.6, 0.12, 0.34), Color(1.0, 0.85, 0.45))


static func _cristal(b: _Assemblage) -> void:
	# Une grappe de prismes lumineux qui pointent en éventail.
	var teintes := [Color(0.4, 0.9, 1.0), Color(0.7, 0.45, 1.0), Color(0.4, 1.0, 0.75)]
	for i in 5:
		var angle := TAU * float(i) / 5.0
		var pied := Vector3(cos(angle), 0.0, sin(angle)) * 0.5
		var pointe := pied * 2.2 + Vector3.UP * (2.2 + 0.4 * (i % 3))
		b.cylindre(pied, pointe, 0.35, 0.02, teintes[i % 3], 6)
	b.cylindre(Vector3.ZERO, Vector3.UP * 3.2, 0.45, 0.02, teintes[0], 6)


static func _immeuble(m: _Assemblage, b: _Assemblage) -> void:
	# Une tour sombre, ses fenêtres allumées en bandes.
	m.pave(Vector3(0, 9.0, 0), Vector3(8.0, 18.0, 8.0), Color(0.12, 0.13, 0.2))
	var teintes := [Color(1.0, 0.8, 0.35), Color(0.4, 0.85, 1.0), Color(1.0, 0.4, 0.75)]
	for etage in 7:
		var y := 2.5 + etage * 2.3
		var teinte: Color = teintes[etage % 3]
		for face in 4:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, face * PI * 0.5)
			var cote := dir.cross(Vector3.UP)
			b.pave(Vector3(0, y, 0) + dir * 4.02, (Vector3(6.0, 0.9, 0.0) if absf(dir.x) < 0.5 else Vector3(0.0, 0.9, 6.0)) + Vector3(0.05, 0, 0.05), teinte)


static func _arbre(m: _Assemblage) -> void:
	# Un feuillu des collines : un tronc, et un houppier en boules serrées.
	m.cylindre(Vector3.ZERO, Vector3.UP * 2.6, 0.35, 0.25, Color(0.42, 0.28, 0.16))
	var vert := Color(0.2, 0.5, 0.18)
	m.boule(Vector3(0, 3.6, 0), 1.9, vert)
	m.boule(Vector3(1.1, 3.1, 0.4), 1.3, vert.lightened(0.08))
	m.boule(Vector3(-1.0, 3.2, -0.5), 1.35, vert.darkened(0.08))
	m.boule(Vector3(0.2, 4.6, -0.3), 1.2, vert.lightened(0.12))


static func _botte(m: _Assemblage) -> void:
	# Une botte ronde, couchée, et ses deux sangles.
	var paille := Color(0.9, 0.76, 0.35)
	m.cylindre(Vector3(-0.8, 0.75, 0), Vector3(0.8, 0.75, 0), 0.75, 0.75, paille, 12)
	m.cylindre(Vector3(-0.8, 0.75, 0), Vector3(-0.79, 0.75, 0), 0.72, 0.1, paille.darkened(0.15), 12)
	m.cylindre(Vector3(0.8, 0.75, 0), Vector3(0.79, 0.75, 0), 0.72, 0.1, paille.darkened(0.15), 12)
	for x in [-0.35, 0.35]:
		m.cylindre(Vector3(x - 0.04, 0.75, 0), Vector3(x + 0.04, 0.75, 0), 0.77, 0.77, Color(0.75, 0.2, 0.15), 12)


static func _moulin(m: _Assemblage) -> void:
	# Une tour blanche au toit rouge, et quatre ailes face au vent.
	var pierre := Color(0.93, 0.9, 0.84)
	m.cylindre(Vector3.ZERO, Vector3.UP * 9.0, 2.8, 2.1, pierre, 12)
	m.cone(Vector3.UP * 9.0, 2.5, 2.6, Color(0.72, 0.2, 0.15), 12)
	m.pave(Vector3(0, 1.1, 2.55), Vector3(1.1, 2.2, 0.3), Color(0.35, 0.22, 0.12))
	var moyeu := Vector3(0, 8.6, 2.5)
	m.boule(moyeu, 0.45, Color(0.3, 0.2, 0.12))
	for i in 4:
		var angle := PI * 0.5 * i
		var dir := Vector3(cos(angle), sin(angle), 0.0)
		var cote := Vector3(-dir.y, dir.x, 0.0)
		var bout := moyeu + dir * 7.0 + Vector3(0, 0, 0.1)
		m.cylindre(moyeu, bout, 0.12, 0.08, Color(0.4, 0.28, 0.16), 6)
		m.pave(moyeu + dir * 4.3 + cote * 0.55 + Vector3(0, 0, 0.15),
			Vector3(absf(dir.x) * 4.6 + absf(cote.x) * 1.0, absf(dir.y) * 4.6 + absf(cote.y) * 1.0, 0.06),
			Color(0.96, 0.94, 0.88))


static func _buisson(m: _Assemblage) -> void:
	# Un buisson bas : serrés en rangée, ils font une haie qui marque le bord
	# du terrain praticable sans cacher la route.
	var vert := Color(0.18, 0.42, 0.16)
	m.boule(Vector3(0, 0.55, 0), 0.95, vert)
	m.boule(Vector3(0.9, 0.45, 0.2), 0.75, vert.lightened(0.07))
	m.boule(Vector3(-0.9, 0.45, -0.2), 0.75, vert.darkened(0.06))


static func _cactus(m: _Assemblage) -> void:
	# Un saguaro : un fût et deux bras qui se redressent.
	var vert := Color(0.25, 0.55, 0.28)
	m.cylindre(Vector3.ZERO, Vector3.UP * 4.5, 0.5, 0.42, vert, 8)
	m.boule(Vector3.UP * 4.5, 0.42, vert)
	for cote: float in [1.0, -1.0]:
		var depart := Vector3(0.0, 1.8 + 0.6 * (1.0 if cote > 0.0 else 0.0), 0.0)
		var coude := depart + Vector3(1.2 * cote, 0.2, 0.0)
		m.cylindre(depart, coude, 0.3, 0.3, vert.darkened(0.05), 8)
		m.cylindre(coude, coude + Vector3.UP * 1.6, 0.3, 0.26, vert.darkened(0.05), 8)
		m.boule(coude + Vector3.UP * 1.6, 0.26, vert.darkened(0.05))
		m.boule(coude, 0.3, vert.darkened(0.05))


static func _stalagmite(m: _Assemblage, b: _Assemblage) -> void:
	# Des cônes de roche ou de glace, et une pointe qui luit.
	var roche := Color(0.62, 0.72, 0.85)
	m.cylindre(Vector3.ZERO, Vector3.UP * 3.0, 1.1, 0.05, roche, 8)
	m.cylindre(Vector3(0.9, 0, 0.3), Vector3(1.0, 1.8, 0.3), 0.6, 0.03, roche.darkened(0.1), 8)
	m.cylindre(Vector3(-0.7, 0, -0.5), Vector3(-0.8, 1.3, -0.5), 0.5, 0.03, roche.lightened(0.1), 8)
	b.cylindre(Vector3.UP * 2.2, Vector3.UP * 3.05, 0.3, 0.02, Color(0.6, 0.9, 1.0), 6)


static func _totem(m: _Assemblage) -> void:
	# Trois têtes de pierre empilées, peintes, et des ailes au sommet.
	var teintes := [Color(0.55, 0.42, 0.28), Color(0.4, 0.55, 0.35), Color(0.6, 0.35, 0.25)]
	for i in 3:
		var y := 1.0 + 2.0 * i
		m.pave(Vector3(0, y, 0), Vector3(1.5, 1.9, 1.5), teintes[i])
		m.pave(Vector3(0, y + 0.3, 0.78), Vector3(1.1, 0.25, 0.1), Color(0.95, 0.9, 0.7))
		m.pave(Vector3(0, y - 0.35, 0.78), Vector3(0.7, 0.3, 0.1), Color(0.15, 0.1, 0.08))
	m.pave(Vector3(0, 6.2, 0), Vector3(3.6, 0.3, 0.6), Color(0.8, 0.25, 0.2))


static func _tonneau(m: _Assemblage) -> void:
	var bois := Color(0.55, 0.33, 0.15)
	m.cylindre(Vector3.ZERO, Vector3.UP * 0.8, 0.62, 0.72, bois, 12)
	m.cylindre(Vector3.UP * 0.8, Vector3.UP * 1.6, 0.72, 0.62, bois, 12)
	for y in [0.15, 0.8, 1.45]:
		m.cylindre(Vector3.UP * (y - 0.05), Vector3.UP * (y + 0.05), 0.74, 0.74, Color(0.3, 0.3, 0.32), 12)


static func _citrouille(m: _Assemblage, b: _Assemblage) -> void:
	# Des quartiers orange, une tige, et un visage qui s'allume la nuit.
	var orange := Color(0.95, 0.5, 0.08)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		m.boule(Vector3(cos(angle) * 0.45, 0.75, sin(angle) * 0.45), 0.75, orange.darkened(0.06 * (i % 2)))
	m.cylindre(Vector3.UP * 1.4, Vector3(0.1, 1.85, 0.0), 0.12, 0.08, Color(0.3, 0.45, 0.15), 6)
	var lueur := Color(1.0, 0.85, 0.3)
	b.pave(Vector3(-0.35, 0.95, 1.12), Vector3(0.25, 0.22, 0.05), lueur)
	b.pave(Vector3(0.35, 0.95, 1.12), Vector3(0.25, 0.22, 0.05), lueur)
	b.pave(Vector3(0.0, 0.55, 1.14), Vector3(0.8, 0.16, 0.05), lueur)


static func _engrenage(m: _Assemblage) -> void:
	# Une roue dentée géante, debout sur son axe.
	var acier := Color(0.55, 0.52, 0.48)
	var centre := Vector3.UP * 4.0
	m.cylindre(Vector3.ZERO, centre, 0.5, 0.4, Color(0.3, 0.3, 0.32), 8)
	m.cylindre(centre + Vector3.BACK * -0.35, centre + Vector3.BACK * 0.35, 3.0, 3.0, acier, 16)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var dir := Vector3(cos(angle), sin(angle), 0.0)
		m.pave(centre + dir * 3.3, Vector3(0.7, 0.7, 0.6).abs(), acier.darkened(0.1))
	m.cylindre(centre + Vector3.BACK * -0.45, centre + Vector3.BACK * 0.45, 0.8, 0.8, Color(0.75, 0.6, 0.2), 8)


static func _antenne(m: _Assemblage, b: _Assemblage) -> void:
	# Une parabole sur un module, et un feu rouge au bout du mât.
	var blanc := Color(0.85, 0.87, 0.9)
	m.pave(Vector3(0, 1.0, 0), Vector3(1.8, 2.0, 1.8), blanc.darkened(0.15))
	m.cylindre(Vector3.UP * 2.0, Vector3.UP * 7.0, 0.12, 0.08, Color(0.5, 0.5, 0.55), 6)
	m.cylindre(Vector3(0, 4.0, 0), Vector3(0, 5.2, 1.0), 0.15, 2.2, blanc, 14)
	b.boule(Vector3.UP * 7.1, 0.22, Color(1.0, 0.2, 0.15))


static func _fantome(b: _Assemblage) -> void:
	# Un drap qui flotte, deux yeux sombres : il ne s'éclaire pas, il luit.
	var drap := Color(0.85, 0.92, 1.0)
	b.boule(Vector3.UP * 1.2, 0.9, drap)
	b.cylindre(Vector3.UP * 1.2, Vector3.ZERO, 0.9, 1.05, drap, 10)
	b.boule(Vector3(-0.3, 1.4, 0.8), 0.15, Color(0.05, 0.05, 0.1))
	b.boule(Vector3(0.3, 1.4, 0.8), 0.15, Color(0.05, 0.05, 0.1))


static func _nuage(m: _Assemblage) -> void:
	var blanc := Color(0.96, 0.97, 1.0)
	m.boule(Vector3.ZERO, 2.4, blanc)
	m.boule(Vector3(2.4, -0.4, 0.3), 1.8, blanc.darkened(0.04))
	m.boule(Vector3(-2.3, -0.5, -0.2), 1.7, blanc.darkened(0.06))
	m.boule(Vector3(0.6, 1.3, 0.2), 1.6, blanc)


static func _pylone(m: _Assemblage) -> void:
	# Le pilier qui porte une route en l'air : posé au bord, il descend
	# soixante mètres sous elle, jusqu'au sol, en bandes rouges et blanches.
	for i in 12:
		var haut := Vector3.DOWN * (0.3 + 5.0 * i)
		m.cylindre(haut + Vector3.DOWN * 5.0, haut, 0.6, 0.6,
			Color(0.85, 0.15, 0.15) if i % 2 == 0 else Color(0.95, 0.95, 0.95), 8)
	m.pave(Vector3(0, -0.25, 0), Vector3(1.6, 0.3, 1.6), Color(0.3, 0.3, 0.33))


## La tour de l'horloge du palais de justice : un bâtiment à colonnes, une
## tour carrée, quatre cadrans qui luisent et un toit en pointe.
static func _tour_horloge(m: _Assemblage, b: _Assemblage) -> void:
	var pierre := Color(0.85, 0.8, 0.7)
	m.pave(Vector3(0, 5.0, 0), Vector3(10.0, 10.0, 10.0), pierre)
	m.pave(Vector3(0, 10.4, 0), Vector3(10.8, 0.8, 10.8), Color(0.7, 0.66, 0.58))
	for x in [-3.6, -1.2, 1.2, 3.6]:
		m.cylindre(Vector3(x, 0, -5.4), Vector3(x, 9.0, -5.4), 0.45, 0.4, Color(0.95, 0.93, 0.88), 8)
	m.pave(Vector3(0, 16.0, 0), Vector3(5.0, 10.0, 5.0), pierre)
	for face in 4:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, face * PI * 0.5)
		b.cylindre(Vector3(0, 17.5, 0) + dir * 2.5, Vector3(0, 17.5, 0) + dir * 2.65, 1.8, 1.8, Color(1.0, 0.97, 0.85), 16)
		m.cylindre(Vector3(0, 17.5, 0) + dir * 2.66, Vector3(0, 18.9, 0) + dir * 2.66, 0.12, 0.08, Color(0.1, 0.1, 0.1), 4)
		m.cylindre(Vector3(0, 17.5, 0) + dir * 2.66, Vector3(0, 17.5, 0) + dir * 2.66 + dir.cross(Vector3.UP) * 1.0, 0.1, 0.06, Color(0.1, 0.1, 0.1), 4)
	m.cone(Vector3(0, 21.0, 0), 3.6, 4.5, Color(0.35, 0.45, 0.4), 4)


## Une maison des années cinquante : murs pastel, toit en pointe, fenêtres
## allumées.
static func _maison(m: _Assemblage, b: _Assemblage) -> void:
	m.pave(Vector3(0, 2.0, 0), Vector3(8.0, 4.0, 7.0), Color(0.95, 0.85, 0.75))
	m.cone(Vector3(0, 4.0, 0), 6.2, 3.0, Color(0.55, 0.25, 0.2), 4)
	m.pave(Vector3(0, 1.2, -3.52), Vector3(1.2, 2.4, 0.05), Color(0.4, 0.25, 0.15))
	for x in [-2.6, 2.6]:
		b.pave(Vector3(x, 2.4, -3.52), Vector3(1.4, 1.1, 0.05), Color(1.0, 0.85, 0.5))


## Un saloon du Far West : façade de planches surmontée d'un fronton,
## auvent sur poteaux et lanterne.
static func _saloon(m: _Assemblage, b: _Assemblage) -> void:
	var bois := Color(0.55, 0.35, 0.18)
	m.pave(Vector3(0, 2.5, 0), Vector3(9.0, 5.0, 6.0), bois)
	m.pave(Vector3(0, 6.0, -2.9), Vector3(9.0, 2.2, 0.3), bois.darkened(0.15))
	m.pave(Vector3(0, 3.4, -4.2), Vector3(9.0, 0.25, 2.5), bois.darkened(0.3))
	for x in [-4.2, -1.4, 1.4, 4.2]:
		m.cylindre(Vector3(x, 0, -5.3), Vector3(x, 3.3, -5.3), 0.15, 0.15, bois.darkened(0.2), 6)
	m.pave(Vector3(0, 6.0, -3.1), Vector3(5.0, 1.0, 0.1), Color(0.9, 0.85, 0.6))
	b.boule(Vector3(2.5, 2.8, -3.2), 0.3, Color(1.0, 0.75, 0.3))


## Une maison-ananas sous la mer : un fruit géant creusé d'une porte et de
## hublots, ses feuilles pour toit.
static func _ananas(m: _Assemblage, b: _Assemblage) -> void:
	m.cylindre(Vector3.ZERO, Vector3(0, 5.0, 0), 3.0, 2.4, Color(0.95, 0.65, 0.15), 12)
	m.dome(Vector3(0, 5.0, 0), 2.4, 1.2, Color(0.95, 0.65, 0.15))
	for k in 12:
		var a := TAU * float(k) / 12.0
		for j in 3:
			m.boule(Vector3(cos(a) * (2.95 - j * 0.2), 1.0 + j * 1.6, sin(a) * (2.95 - j * 0.2)), 0.25, Color(0.7, 0.45, 0.1))
	for k in 7:
		var a := TAU * float(k) / 7.0
		var dehors := Vector3(cos(a), 0, sin(a))
		m.feuille(Vector3(0, 5.8, 0), Vector3(0, 7.5, 0) + dehors * 1.2, Vector3(0, 8.3, 0) + dehors * 2.6,
			dehors.cross(Vector3.UP) * 0.5, Color(0.2, 0.6, 0.2))
	m.pave(Vector3(0, 1.0, -2.95), Vector3(1.2, 2.0, 0.2), Color(0.35, 0.3, 0.45))
	for x in [-1.4, 1.4]:
		b.cylindre(Vector3(x, 3.3, -2.6), Vector3(x, 3.3, -2.95), 0.5, 0.5, Color(0.6, 0.85, 1.0), 10)


## Une maison taillée dans une tête de pierre : front lourd, long nez.
static func _tete_de_pierre(m: _Assemblage) -> void:
	var pierre := Color(0.45, 0.55, 0.65)
	m.pave(Vector3(0, 3.0, 0), Vector3(3.2, 6.0, 3.2), pierre)
	m.pave(Vector3(0, 4.4, -1.75), Vector3(2.8, 0.6, 0.4), pierre.darkened(0.2))
	m.pave(Vector3(0, 3.2, -2.0), Vector3(0.8, 2.2, 0.9), pierre.lightened(0.05))
	m.pave(Vector3(0, 1.3, -1.65), Vector3(1.6, 0.4, 0.2), pierre.darkened(0.35))


## Une touffe de corail : des branches qui montent en s'écartant.
static func _corail(m: _Assemblage) -> void:
	var teintes := [Color(1.0, 0.45, 0.55), Color(1.0, 0.6, 0.3), Color(0.85, 0.35, 0.9)]
	for k in 6:
		var a := TAU * float(k) / 6.0
		var bout := Vector3(cos(a) * 1.4, 2.0 + 0.6 * (k % 3), sin(a) * 1.4)
		m.cylindre(Vector3.ZERO, bout, 0.3, 0.12, teintes[k % 3], 6)
		m.boule(bout, 0.25, teintes[k % 3])


## Une algue qui ondule : des tronçons décalés, de plus en plus fins.
static func _algue(m: _Assemblage) -> void:
	var bas := Vector3.ZERO
	for k in 6:
		var haut := Vector3(0.35 * sin(float(k) * 1.3), bas.y + 1.1, 0.25 * cos(float(k) * 1.1))
		m.cylindre(bas, haut, 0.28 - k * 0.035, 0.24 - k * 0.035, Color(0.2, 0.55 + 0.05 * k, 0.3), 6)
		bas = haut


## Un masque géant au bout d'une perche : un cœur violet hérissé de pointes,
## deux yeux qui luisent.
static func _masque(m: _Assemblage, b: _Assemblage) -> void:
	m.cylindre(Vector3.ZERO, Vector3(0, 6.0, 0), 0.2, 0.15, Color(0.35, 0.25, 0.15), 6)
	var violet := Color(0.45, 0.15, 0.55)
	m.boule(Vector3(-0.8, 7.0, 0), 1.2, violet)
	m.boule(Vector3(0.8, 7.0, 0), 1.2, violet)
	m.cone(Vector3(0, 6.6, 0), 1.4, -2.2, violet, 8)
	for k in 8:
		var a := PI * float(k) / 7.0
		var pied := Vector3(cos(a) * 1.8, 7.0 + sin(a) * 1.4, 0)
		m.cylindre(pied, pied + Vector3(cos(a), sin(a), 0) * 1.4, 0.25, 0.02, Color(0.95, 0.8, 0.3), 5)
	for x in [-0.7, 0.7]:
		b.boule(Vector3(x, 7.2, -1.05), 0.32, Color(1.0, 0.85, 0.2))


## Un arbre en cubes : un tronc carré, un feuillage en deux pavés.
static func _arbre_cube(m: _Assemblage) -> void:
	m.pave(Vector3(0, 2.5, 0), Vector3(1.0, 5.0, 1.0), Color(0.45, 0.32, 0.18))
	m.pave(Vector3(0, 5.5, 0), Vector3(5.0, 2.0, 5.0), Color(0.25, 0.55, 0.2))
	m.pave(Vector3(0, 7.0, 0), Vector3(3.0, 1.0, 3.0), Color(0.28, 0.6, 0.22))


## Un bloc de terre coiffé d'herbe.
static func _bloc(m: _Assemblage) -> void:
	m.pave(Vector3(0, 0.8, 0), Vector3(2.0, 1.6, 2.0), Color(0.5, 0.35, 0.2))
	m.pave(Vector3(0, 1.8, 0), Vector3(2.02, 0.4, 2.02), Color(0.35, 0.65, 0.25))


## Un pilier d'obsidienne de la dimension du néant, un cristal en flammes à
## son sommet.
static func _pilier_obsidienne(m: _Assemblage, b: _Assemblage) -> void:
	m.pave(Vector3(0, 15.0, 0), Vector3(4.0, 30.0, 4.0), Color(0.1, 0.06, 0.16))
	b.boule(Vector3(0, 31.5, 0), 1.2, Color(1.0, 0.55, 0.9))
	b.cylindre(Vector3(0, 30.0, 0), Vector3(0, 33.0, 0), 0.08, 0.08, Color(1.0, 0.8, 1.0), 4)


## Un amas de sculk : une plaque sombre, une bouche qui hurle cerclée d'os,
## des points qui luisent.
static func _sculk(m: _Assemblage, b: _Assemblage) -> void:
	m.pave(Vector3(0, 0.1, 0), Vector3(3.2, 0.2, 3.2), Color(0.05, 0.1, 0.16))
	m.pave(Vector3(0, 0.6, 0), Vector3(1.6, 1.0, 1.6), Color(0.08, 0.14, 0.2))
	m.pave(Vector3(0, 1.15, 0), Vector3(1.7, 0.15, 1.7), Color(0.85, 0.85, 0.75))
	for k in 6:
		var a := float(k) * 1.9
		b.boule(Vector3(cos(a) * 1.3, 0.25, sin(a) * 1.3), 0.12, Color(0.3, 0.95, 1.0))


## Le cadre d'un portail vers le monde d'en bas : de l'obsidienne autour
## d'un voile violet.
static func _cadre_obsidienne(m: _Assemblage, b: _Assemblage) -> void:
	var obsidienne := Color(0.1, 0.06, 0.16)
	m.pave(Vector3(-2.0, 3.0, 0), Vector3(1.0, 6.0, 1.0), obsidienne)
	m.pave(Vector3(2.0, 3.0, 0), Vector3(1.0, 6.0, 1.0), obsidienne)
	m.pave(Vector3(0, 0.5, 0), Vector3(5.0, 1.0, 1.0), obsidienne)
	m.pave(Vector3(0, 5.5, 0), Vector3(5.0, 1.0, 1.0), obsidienne)
	b.pave(Vector3(0, 3.0, 0), Vector3(3.0, 4.0, 0.2), Color(0.65, 0.25, 1.0))


## Une lanterne de fête au bout d'une perche.
static func _lanterne(m: _Assemblage, b: _Assemblage) -> void:
	m.cylindre(Vector3.ZERO, Vector3(0, 4.0, 0), 0.12, 0.1, Color(0.3, 0.2, 0.1), 6)
	b.boule(Vector3(0, 4.3, 0), 0.5, Color(1.0, 0.55, 0.25))


## Un feuillu d'automne : le houppier roux, quelques feuilles déjà tombées.
static func _arbre_automne(m: _Assemblage) -> void:
	m.cylindre(Vector3.ZERO, Vector3.UP * 2.6, 0.35, 0.25, Color(0.4, 0.26, 0.15))
	var roux := Color(0.9, 0.42, 0.12)
	m.boule(Vector3(0, 3.6, 0), 1.9, roux)
	m.boule(Vector3(1.1, 3.1, 0.4), 1.3, Color(0.95, 0.65, 0.15))
	m.boule(Vector3(-1.0, 3.2, -0.5), 1.35, roux.darkened(0.15))
	m.boule(Vector3(0.2, 4.6, -0.3), 1.2, Color(0.8, 0.25, 0.1))
	for k in 5:
		var a := float(k) * 1.3
		m.pave(Vector3(cos(a) * 1.8, 0.03, sin(a) * 1.6), Vector3(0.5, 0.05, 0.35), Color(0.9, 0.5, 0.15))


## Trois boules de neige, un nez carotte, un chapeau.
static func _bonhomme(m: _Assemblage) -> void:
	var neige := Color(0.95, 0.97, 1.0)
	m.boule(Vector3(0, 0.75, 0), 0.95, neige)
	m.boule(Vector3(0, 1.9, 0), 0.65, neige)
	m.boule(Vector3(0, 2.75, 0), 0.45, neige)
	m.cone(Vector3(0, 2.78, 0.4), 0.09, 0.45, Color(1.0, 0.5, 0.1), 6)
	m.cylindre(Vector3(0, 3.1, 0), Vector3(0, 3.5, 0), 0.32, 0.3, Color(0.1, 0.1, 0.12), 10)
	m.cylindre(Vector3(0, 3.1, 0), Vector3(0, 3.14, 0), 0.5, 0.5, Color(0.1, 0.1, 0.12), 12)
	m.cylindre(Vector3(0, 2.32, 0), Vector3(0, 2.45, 0), 0.52, 0.5, Color(0.85, 0.15, 0.15), 10)


## Un parasol rayé planté dans le sable.
static func _parasol(m: _Assemblage) -> void:
	m.cylindre(Vector3.ZERO, Vector3.UP * 2.9, 0.06, 0.06, Color(0.9, 0.9, 0.88), 6)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var b := TAU * float(k + 1) / 8.0
		var couleur := Color(0.95, 0.25, 0.3) if k % 2 == 0 else Color(0.98, 0.96, 0.9)
		m.triangle(Vector3(0, 3.2, 0), Vector3(cos(a) * 1.7, 2.6, sin(a) * 1.7),
			Vector3(cos(b) * 1.7, 2.6, sin(b) * 1.7), couleur)


## Une fleur géante du printemps : une tige, des pétales, un cœur qui luit.
static func _fleur(m: _Assemblage, b: _Assemblage) -> void:
	m.cylindre(Vector3.ZERO, Vector3.UP * 2.6, 0.15, 0.1, Color(0.3, 0.65, 0.25), 6)
	m.feuille(Vector3(0, 0.8, 0), Vector3(0.5, 1.1, 0), Vector3(0.9, 1.5, 0), Vector3(0, 0, 0.25), Color(0.35, 0.7, 0.3))
	var petale := Color(1.0, 0.55, 0.75)
	for k in 6:
		var a := TAU * float(k) / 6.0
		m.boule(Vector3(cos(a) * 0.55, 2.85, sin(a) * 0.55), 0.38, petale)
	b.boule(Vector3(0, 2.9, 0), 0.32, Color(1.0, 0.9, 0.3))


## Un pan de mur du laboratoire : des dalles blanches, un liseré qui luit.
static func _panneau_labo(m: _Assemblage, b: _Assemblage) -> void:
	for i in 3:
		for j in 2:
			m.pave(Vector3(-2.0 + 2.0 * i, 1.25 + 2.5 * j, 0), Vector3(1.94, 2.44, 0.5),
				Color(0.93, 0.94, 0.95) if (i + j) % 2 == 0 else Color(0.86, 0.87, 0.89))
	m.pave(Vector3(0, 5.1, 0), Vector3(6.1, 0.2, 0.6), Color(0.35, 0.37, 0.4))
	b.pave(Vector3(0, 0.2, 0.28), Vector3(6.0, 0.12, 0.05), Color(0.3, 0.75, 1.0))


## Une tourelle de garde : une capsule blanche sur trois pieds, un œil rouge.
static func _tourelle(m: _Assemblage, b: _Assemblage) -> void:
	for k in 3:
		var a := TAU * float(k) / 3.0
		m.cylindre(Vector3(cos(a) * 0.7, 0, sin(a) * 0.7), Vector3(0, 0.9, 0), 0.06, 0.06, Color(0.3, 0.3, 0.32), 5)
	m.cylindre(Vector3(0, 0.9, 0), Vector3(0, 1.8, 0), 0.45, 0.45, Color(0.95, 0.95, 0.96), 12)
	m.dome(Vector3(0, 1.8, 0), 0.45, 0.4, Color(0.95, 0.95, 0.96))
	m.boule(Vector3(0, 0.9, 0), 0.45, Color(0.95, 0.95, 0.96))
	b.boule(Vector3(0, 1.5, 0.42), 0.1, Color(1.0, 0.1, 0.1))


## Un cube lesté du labo : gris, coins renforcés, un rond lumineux sur chaque
## face.
static func _cube_leste(m: _Assemblage, b: _Assemblage) -> void:
	m.pave(Vector3(0, 0.8, 0), Vector3(1.5, 1.5, 1.5), Color(0.6, 0.62, 0.65))
	for x in [-0.7, 0.7]:
		for z in [-0.7, 0.7]:
			m.pave(Vector3(x, 0.8, z), Vector3(0.25, 1.6, 0.25), Color(0.4, 0.42, 0.45))
	for face in [Vector3(0.77, 0.8, 0), Vector3(-0.77, 0.8, 0), Vector3(0, 0.8, 0.77), Vector3(0, 0.8, -0.77)]:
		var mince := Vector3(0.04 if face.x != 0.0 else 0.6, 0.6, 0.04 if face.z != 0.0 else 0.6)
		b.pave(face, mince, Color(0.4, 0.8, 1.0))


## Un bout d'escalier qui flotte dans le rêve, sans début ni fin.
static func _escalier_flottant(m: _Assemblage) -> void:
	var pierre := Color(0.86, 0.8, 0.92)
	for k in 6:
		m.pave(Vector3(0, 0.4 * k, -0.8 * k), Vector3(3.0, 0.4, 0.8), pierre.darkened(0.04 * k))
	m.pave(Vector3(1.6, 1.2, -2.0), Vector3(0.2, 2.8, 5.0), Color(0.7, 0.62, 0.8))


## Une fusée sur son pas de tir : un fuseau blanc, une coiffe rouge, quatre
## ailerons, et la tour de lancement à côté.
static func _fusee(m: _Assemblage, b: _Assemblage) -> void:
	var blanc := Color(0.95, 0.95, 0.97)
	m.cylindre(Vector3(0, 2.0, 0), Vector3(0, 16.0, 0), 1.5, 1.5, blanc, 14)
	m.cone(Vector3(0, 16.0, 0), 1.5, 5.0, Color(0.85, 0.15, 0.15), 14)
	for k in 4:
		var a := TAU * float(k) / 4.0
		m.pave(Vector3(cos(a) * 1.8, 3.0, sin(a) * 1.8), Vector3(0.2 + absf(cos(a)) * 1.2, 4.0, 0.2 + absf(sin(a)) * 1.2),
			Color(0.85, 0.15, 0.15))
	m.cylindre(Vector3(0, 0, 0), Vector3(0, 2.0, 0), 1.2, 1.5, Color(0.3, 0.3, 0.33), 14)
	b.boule(Vector3(0, 11.0, 1.48), 0.45, Color(0.4, 0.8, 1.0))
	m.pave(Vector3(4.0, 10.0, 0), Vector3(1.2, 20.0, 1.2), Color(0.55, 0.55, 0.6))
	m.pave(Vector3(2.8, 12.0, 0), Vector3(2.4, 0.4, 0.4), Color(0.55, 0.55, 0.6))


## Une antenne parabolique tournée vers le ciel.
static func _parabole(m: _Assemblage, b: _Assemblage) -> void:
	m.cylindre(Vector3.ZERO, Vector3.UP * 3.0, 0.3, 0.2, Color(0.6, 0.6, 0.63), 8)
	m.cylindre(Vector3(0, 3.0, 0), Vector3(0, 3.8, 0.9), 2.4, 0.3, Color(0.93, 0.93, 0.95), 16)
	b.boule(Vector3(0, 4.3, 0.6), 0.15, Color(1.0, 0.3, 0.2))


## Un rocher de la planète rouge.
static func _rocher_rouge(m: _Assemblage) -> void:
	m.boule(Vector3(0, 0.6, 0), 1.5, Color(0.72, 0.32, 0.18))
	m.boule(Vector3(1.1, 0.4, 0.5), 0.9, Color(0.62, 0.27, 0.15))
	m.boule(Vector3(-0.7, 0.3, -0.8), 0.8, Color(0.8, 0.4, 0.22))


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
