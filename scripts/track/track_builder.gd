class_name TrackBuilder

## Extrude un ruban de route le long d'un TrackCurve. Le maillage produit sert
## à la fois à l'affichage et, converti en trimesh, à la collision.


## Découpe la courbe en segments d'environ `segment_length` mètres et relie
## chaque section à la suivante par deux triangles (plus, là où le dévers
## change, voir _recouper).
##
## `trous` liste les portions sans route, en couples (début, fin) de distances
## le long du tracé, déjà ramenées dans [0, longueur]. La route s'y arrête net
## et reprend au bout : c'est ce qui fait un vrai saut, par-dessus le vide.
##
## `couleurs`, si on en donne, découpe la chaussée en autant de bandes dans le
## sens de la longueur, chacune de sa couleur (portée par les sommets) : c'est
## ce qui fait une route arc-en-ciel. Sans couleurs, un seul ruban uni.
static func build(track: TrackCurve, segment_length: float = 2.0,
		trous: Array[Vector2] = [], couleurs: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ruban in _rubans(track, segment_length, trous, maxi(couleurs.size(), 1)):
		_poser_le_ruban(outil, track, ruban, couleurs)
	outil.generate_normals()
	return outil.commit()


## Les deux rives de la chaussée, exactement : les sommets du bord gauche et
## du bord droit que build() pose, dans l'ordre de la marche, coupes des
## sections recoupées comprises. Ce qui veut border le bitume au millimètre
## (un talus) les suit, plutôt que de recalculer ses propres points : entre
## deux coupes, le bord du bitume est une corde, pas la courbe.
##
## Un dictionnaire par portion de route d'un seul tenant : `distances`
## (PackedFloat64Array, croissantes : une portion qui franchit la ligne de
## départ continue au-delà de la longueur du tour, que TrackCurve ramène dans
## le tour), `gauche` et `droite` (PackedVector3Array, un point par
## distance). Sans trou, le dernier point est le premier : le tour se referme.
static func rives(track: TrackCurve, segment_length: float = 2.0,
		trous: Array[Vector2] = []) -> Array[Dictionary]:
	var resultat: Array[Dictionary] = []
	for ruban in _rubans(track, segment_length, trous, 1):
		var gauche := PackedVector3Array()
		var droite := PackedVector3Array()
		var distances := PackedFloat64Array()
		var tours := 0.0
		for i in ruban.coupes.size():
			if i > 0 and ruban.coupes[i] + tours < distances[i - 1]:
				tours += track.length
			distances.append(ruban.coupes[i] + tours)
			# La dernière coupe d'un tour fermé est la première, au bit près.
			var j := 0 if ruban.ferme and i == ruban.coupes.size() - 1 else i
			gauche.append(_point_de_coupe(ruban.centres[j], ruban.droites[j], track.half_width, 0, 1))
			droite.append(_point_de_coupe(ruban.centres[j], ruban.droites[j], track.half_width, 1, 1))
		resultat.append({distances = distances, gauche = gauche, droite = droite})
	return resultat


## Des bordures rouges et blanches sur chaque rive, comme sur un vrai circuit
## et sur les routes de Kenney : des blocs de `largeur` mètres posés sur le
## bord de la chaussée, bombés (plus hauts au milieu), qui changent de couleur
## tous les `pas` mètres. Sans collision : elles se voient, elles ne se
## sentent pas.
const BOMBE_DES_BORDURES := 0.07

static func bordures(track: TrackCurve, trous: Array[Vector2], largeur: float, pas: float,
		couleur: Color, couleur_bis: Color) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var demi := track.half_width
	for morceau in troncons(track.length, trous):
		var etendue := morceau.y - morceau.x
		var n := maxi(int(round(etendue / pas)), 1)
		var longueur := etendue / float(n)
		for i in n:
			var d0 := morceau.x + longueur * float(i)
			var d1 := d0 + longueur
			outil.set_color(couleur if i % 2 == 0 else couleur_bis)
			for cote: float in [-1.0, 1.0]:
				var dedans := (demi - largeur) * cote
				var milieu := (demi - largeur * 0.5) * cote
				var dehors := demi * cote
				var a0 := _sur_la_route(track, d0, dedans)
				var m0 := _bord(track, d0, milieu, BOMBE_DES_BORDURES)
				var b0 := _sur_la_route(track, d0, dehors)
				var a1 := _sur_la_route(track, d1, dedans)
				var m1 := _bord(track, d1, milieu, BOMBE_DES_BORDURES)
				var b1 := _sur_la_route(track, d1, dehors)
				# Toujours dans le même sens de rotation, quel que soit le côté :
				# vues d'en haut, les deux rives doivent faire face au ciel.
				if cote < 0.0:
					_quad(outil, m0, m1, a0, a1)
					_quad(outil, b0, b1, m0, m1)
				else:
					_quad(outil, a0, a1, m0, m1)
					_quad(outil, m0, m1, b0, b1)
	outil.generate_normals()
	return outil.commit()


## Les lignes de rive continues, à `ecart` mètres en dedans de chaque bord,
## comme sur les routes de Kenney.
static func lignes_de_rive(track: TrackCurve, trous: Array[Vector2], ecart: float,
		largeur: float = 0.25, pas: float = 2.0) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var demi := track.half_width
	for morceau in troncons(track.length, trous):
		var etendue := morceau.y - morceau.x
		var n := maxi(int(round(etendue / pas)), 1)
		var longueur := etendue / float(n)
		for i in n:
			var d0 := morceau.x + longueur * float(i)
			var d1 := d0 + longueur
			for cote: float in [-1.0, 1.0]:
				var dedans := (demi - ecart - largeur) * cote
				var dehors := (demi - ecart) * cote
				var a0 := _bord(track, d0, dedans, 0.025)
				var b0 := _bord(track, d0, dehors, 0.025)
				var a1 := _bord(track, d1, dedans, 0.025)
				var b1 := _bord(track, d1, dehors, 0.025)
				if cote < 0.0:
					_quad(outil, b0, b1, a0, a1)
				else:
					_quad(outil, a0, a1, b0, b1)
	outil.generate_normals()
	return outil.commit()


## Le dessous de la route : une dalle de `epaisseur` mètres sous la chaussée,
## avec ses deux flancs et un bout à chaque bord de trou. Sans elle, une route
## vue d'en dessous — un pont, un tour d'hélice, une route qui passe au-dessus
## d'une autre — était invisible : le ruban n'a qu'une face. Sans collision ;
## les couleurs de sommet assombrissent le dessous, éclairent les flancs.
static func tablier(track: TrackCurve, trous: Array[Vector2], epaisseur: float = 0.9,
		segment_length: float = 2.0) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var demi := track.half_width
	var sections_totales := maxi(int(track.length / segment_length), 8)
	for morceau in troncons(track.length, trous):
		var etendue := morceau.y - morceau.x
		var n := maxi(int(round(sections_totales * etendue / track.length)), 1)
		var pas := etendue / float(n)
		for i in n:
			var d0 := morceau.x + pas * float(i)
			var d1 := d0 + pas
			var g0 := _bord(track, d0, -demi, 0.0)
			var r0 := _bord(track, d0, demi, 0.0)
			var g1 := _bord(track, d1, -demi, 0.0)
			var r1 := _bord(track, d1, demi, 0.0)
			var gb0 := _bord(track, d0, -demi * 0.92, -epaisseur)
			var rb0 := _bord(track, d0, demi * 0.92, -epaisseur)
			var gb1 := _bord(track, d1, -demi * 0.92, -epaisseur)
			var rb1 := _bord(track, d1, demi * 0.92, -epaisseur)
			# Le dessous, tourné vers le sol.
			outil.set_color(Color(0.55, 0.55, 0.58))
			_quad(outil, gb0, rb0, gb1, rb1)
			# Les flancs, tournés vers l'extérieur.
			outil.set_color(Color(0.8, 0.8, 0.82))
			_quad(outil, g0, gb0, g1, gb1)
			_quad(outil, rb0, r0, rb1, r1)
			if i == 0:
				_quad(outil, g0, r0, gb0, rb0)
			if i == n - 1:
				_quad(outil, r1, g1, rb1, gb1)
	outil.generate_normals()
	return outil.commit()


## La ligne blanche discontinue au milieu de la chaussée : des traits de
## `tiret` mètres, séparés de `vide` mètres, juste au-dessus du bitume.
static func marquage(track: TrackCurve, trous: Array[Vector2], tiret: float = 3.0,
		vide: float = 4.5, largeur: float = 0.22) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for morceau in troncons(track.length, trous):
		var d := morceau.x + vide * 0.5
		while d + tiret <= morceau.y:
			var milieu := d + tiret * 0.5
			var g0 := _bord(track, d, -largeur, 0.025)
			var r0 := _bord(track, d, largeur, 0.025)
			var g1 := _bord(track, milieu, -largeur, 0.025)
			var r1 := _bord(track, milieu, largeur, 0.025)
			var g2 := _bord(track, d + tiret, -largeur, 0.025)
			var r2 := _bord(track, d + tiret, largeur, 0.025)
			_quad(outil, g0, g1, r0, r1)
			_quad(outil, g1, g2, r1, r2)
			d += tiret + vide
	outil.generate_normals()
	return outil.commit()


static func _bord(track: TrackCurve, d: float, lateral: float, hauteur: float) -> Vector3:
	return track.position_at(d) + track.right_at(d) * lateral + track.up_at(d) * hauteur


static func _sur_la_route(track: TrackCurve, d: float, lateral: float) -> Vector3:
	return track.position_at(d) + track.right_at(d) * lateral + track.up_at(d) * 0.02


## Deux triangles, dans l'ordre de la chaussée : gauche puis droite, de la
## section d0 à la section d1.
static func _quad(outil: SurfaceTool, g0: Vector3, g1: Vector3, d0: Vector3, d1: Vector3) -> void:
	outil.add_vertex(g0)
	outil.add_vertex(g1)
	outil.add_vertex(d0)
	outil.add_vertex(d0)
	outil.add_vertex(g1)
	outil.add_vertex(d1)


## Les portions de tracé qui portent de la route : le tour entier, moins les
## trous. Rendues en couples (début, fin), dans l'ordre.
static func troncons(longueur: float, trous: Array[Vector2]) -> Array[Vector2]:
	var tries := trous.duplicate()
	tries.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var morceaux: Array[Vector2] = []
	var curseur := 0.0
	for trou in tries:
		var debut := clampf(trou.x, 0.0, longueur)
		var fin := clampf(trou.y, 0.0, longueur)
		if debut > curseur + 0.01:
			morceaux.append(Vector2(curseur, debut))
		curseur = maxf(curseur, fin)
	if curseur < longueur - 0.01:
		morceaux.append(Vector2(curseur, longueur))
	return morceaux


## L'écart toléré entre le bitume et la courbe, au milieu d'une section.
const ECART_MAX := 0.015
## Les écarts latéraux où on le mesure, en fraction de la demi-largeur.
const MESURES := [-0.98, -0.5, 0.0, 0.5, 0.98]


## Une portion de chaussée d'un seul tenant, découpée : ses coupes en
## travers, et entre deux coupes consécutives une section, en autant de bandes
## dans le sens de la longueur que `bandes` en dit.
class Ruban:
	## Les distances des coupes, le long du tracé.
	var coupes := PackedFloat64Array()
	## Le milieu de la chaussée et son côté droit à chaque coupe, calculés une
	## fois : la section d'avant et celle d'après y posent les mêmes sommets.
	var centres := PackedVector3Array()
	var droites := PackedVector3Array()
	## Les bandes de chaque section : celle de la coupe i à la coupe i + 1.
	var bandes := PackedInt32Array()
	## Le ruban fait le tour sans trou : sa dernière coupe est la première.
	var ferme := false

	func ajouter_coupe(d: float, centre: Vector3, droite: Vector3) -> void:
		coupes.append(d)
		centres.append(centre)
		droites.append(droite)

	## Ajoute à la suite les coupes et les sections de `suite`, dont la
	## première coupe remplace la dernière de celui-ci.
	func prolonger(suite: Ruban) -> void:
		coupes.remove_at(coupes.size() - 1)
		centres.remove_at(centres.size() - 1)
		droites.remove_at(droites.size() - 1)
		coupes.append_array(suite.coupes)
		centres.append_array(suite.centres)
		droites.append_array(suite.droites)
		bandes.append_array(suite.bandes)


## Les rubans de la route, hors des trous, chacun découpé en sections
## (voir _recouper). `n_couleurs` bandes au moins par section.
static func _rubans(track: TrackCurve, segment_length: float, trous: Array[Vector2],
		n_couleurs: int) -> Array[Ruban]:
	var rubans: Array[Ruban] = []
	# Sans trou, le découpage reste exactement celui d'avant : même nombre de
	# sections, au même endroit.
	var sections_totales := maxi(int(track.length / segment_length), 8)
	for morceau in troncons(track.length, trous):
		var etendue := morceau.y - morceau.x
		var sections := maxi(int(round(sections_totales * etendue / track.length)), 1)
		var pas := etendue / float(sections)
		var ruban := Ruban.new()
		ruban.ajouter_coupe(morceau.x, track.position_at(morceau.x), track.right_at(morceau.x))
		for i in sections:
			_recouper(ruban, track, morceau.x + pas * float(i + 1), n_couleurs)
		rubans.append(ruban)
	# La ligne de départ n'est pas un bout de route quand aucun trou ne la
	# coupe : le dernier ruban y rejoint le premier, et leur coupe commune
	# doit porter les mêmes sommets des deux côtés, sans quoi la couture
	# s'ouvre là aussi.
	if rubans.is_empty():
		return rubans
	var premier := rubans[0]
	var dernier: Ruban = rubans.back()
	if premier.coupes[0] > 0.0 or dernier.coupes[dernier.coupes.size() - 1] < track.length - 0.01:
		return rubans
	if rubans.size() == 1:
		premier.ferme = true
		return rubans
	# Le dernier ruban se poursuit dans le premier : leur coupe commune est
	# celle du départ, à zéro.
	dernier.prolonger(premier)
	rubans.pop_back()
	rubans[0] = dernier
	return rubans


## Une section de route, de la dernière coupe du ruban à d1, ajoutée au
## ruban.
##
## Une section dont le dévers change d'un bout à l'autre est un
## quadrilatère tordu : coupé selon une seule diagonale, son milieu passait
## jusqu'à 20 cm sous la courbe, sous un marquage qui flottait. Elle est
## recoupée dans la longueur, en bandes, chacune d'autant moins tordue ; et
## si le milieu reste à plus de ECART_MAX de la courbe (le dévers ne change
## pas d'un pas régulier, la pente s'arrondit), coupée en deux dans le sens
## de la marche. Une section plate garde ses deux triangles.
static func _recouper(ruban: Ruban, track: TrackCurve, d1: float, n_couleurs: int) -> void:
	var largeur := track.half_width * 2.0
	var d0 := ruban.coupes[ruban.coupes.size() - 1]
	var p0 := ruban.centres[ruban.centres.size() - 1]
	var r0 := ruban.droites[ruban.droites.size() - 1]
	var p1 := track.position_at(d1)
	var r1 := track.right_at(d1)
	var torsion := absf(Plane(p0 - r0 * track.half_width, p1 - r1 * track.half_width,
		p0 + r0 * track.half_width).distance_to(p1 + r1 * track.half_width))
	var bandes := maxi(ceili(torsion * 0.25 / ECART_MAX), 1)
	# Les couleurs de l'arc-en-ciel découpent déjà la chaussée : chacune
	# est recoupée de même.
	var par_couleur := ceili(float(bandes) / n_couleurs) if bandes > 1 else 1
	var bords := PackedFloat32Array()
	for k in n_couleurs * par_couleur + 1:
		bords.append(-track.half_width + largeur * float(k) / float(n_couleurs * par_couleur))
	if d1 - d0 > 0.25 and _ecart(track, d0, d1, p0, p1, r0, r1, bords) > ECART_MAX:
		_recouper(ruban, track, (d0 + d1) * 0.5, n_couleurs)
		_recouper(ruban, track, d1, n_couleurs)
		return
	ruban.ajouter_coupe(d1, p1, r1)
	ruban.bandes.append(n_couleurs * par_couleur)


## Les triangles d'un ruban.
##
## Deux sections voisines n'ont pas forcément autant de bandes : une section
## tordue, recoupée, en touche une plate. Chacune posant ses propres sommets,
## ceux des bandes tombaient au milieu de la grande arête d'en face : une
## jonction en T. Les flottants y laissent une fente, que la collision élargit
## en arrondissant ses sommets (au dixième de millimètre pour Godot, à sa
## grille pour Jolt) : un rayon de roue tiré pile sur la couture passait à
## travers la route (22 rayons sur 29 circuits).
## Chaque coupe porte donc les sommets des bandes de ses deux sections, et
## chaque section les reprend tous : le côté d'un triangle qui en enjambe
## plusieurs devient un éventail. Ces sommets sont sur la droite de la
## coupe, l'éventail est dans le plan du triangle : la chaussée ne bouge
## pas d'un cheveu, elle se referme.
static func _poser_le_ruban(outil: SurfaceTool, track: TrackCurve, ruban: Ruban,
		couleurs: PackedColorArray) -> void:
	var n := ruban.bandes.size()
	var points: Array[PackedInt32Array] = []
	var sommets: Array[PackedVector3Array] = []
	for i in n + 1:
		if ruban.ferme and i == n:
			# Les sommets de la ligne de départ, partagés avec la première section.
			points.append(points[0])
			sommets.append(sommets[0])
			continue
		var avant := ruban.bandes[i - 1] if i > 0 else (ruban.bandes[n - 1] if ruban.ferme else 0)
		var apres := ruban.bandes[i] if i < n else 0
		var fractions := _points_de_coupe(avant, apres)
		var coupe := PackedVector3Array()
		for k in range(0, fractions.size(), 2):
			coupe.append(_point_de_coupe(ruban.centres[i], ruban.droites[i], track.half_width,
				fractions[k], fractions[k + 1]))
		points.append(fractions)
		sommets.append(coupe)
	var n_couleurs := maxi(couleurs.size(), 1)
	for i in n:
		var bandes := ruban.bandes[i]
		var depart := sommets[i]
		var arrivee := sommets[i + 1]
		var a := _rangs(points[i], bandes)
		var b := _rangs(points[i + 1], bandes)
		# Dans chaque bande, les deux triangles de _quad : (g0, g1, d0) en
		# éventail depuis g1 sur la coupe de départ, (d0, g1, d1) en
		# éventail depuis d0 sur celle d'arrivée.
		for k in bandes:
			if not couleurs.is_empty():
				outil.set_color(couleurs[k * n_couleurs / bandes])
			var g1 := arrivee[b[k]]
			for j in range(a[k], a[k + 1]):
				_triangle(outil, depart[j], g1, depart[j + 1])
			var d0 := depart[a[k + 1]]
			for j in range(b[k], b[k + 1]):
				_triangle(outil, d0, arrivee[j], arrivee[j + 1])


## Les points d'une coupe entre une section de `avant` bandes et une de
## `apres` (0 : pas de section de ce côté), de gauche à droite, en fractions
## exactes de la largeur : (numérateur, dénominateur) à la suite. Les deux
## découpages fusionnés, chaque point une seule fois.
static func _points_de_coupe(avant: int, apres: int) -> PackedInt32Array:
	var points := PackedInt32Array()
	if avant == 0 or apres == 0:
		var seul := maxi(avant, apres)
		for k in seul + 1:
			points.append_array([k, seul])
		return points
	var i := 0
	var j := 0
	while i <= avant or j <= apres:
		# i / avant comparé à j / apres, en entiers : pas d'arrondi.
		var ecart := i * apres - j * avant if i <= avant and j <= apres else (1 if i > avant else -1)
		if ecart <= 0:
			points.append_array([i, avant])
			i += 1
			if ecart == 0:
				j += 1
		else:
			points.append_array([j, apres])
			j += 1
	return points


## Pour chaque bord de bande d'une section de `bandes` bandes (k / bandes,
## de 0 à bandes), son rang parmi les points de la coupe.
static func _rangs(points: PackedInt32Array, bandes: int) -> PackedInt32Array:
	var rangs := PackedInt32Array()
	var j := 0
	for k in bandes + 1:
		while points[j * 2] * bandes != k * points[j * 2 + 1]:
			j += 1
		rangs.append(j)
	return rangs


## Le point de la coupe (p, r) à la fraction `numerateur / denominateur` de
## la largeur, depuis le bord gauche. La fraction d'abord : 0 et 1 tombent
## pile sur les rives, et deux écritures d'une même fraction sur le même point.
static func _point_de_coupe(p: Vector3, r: Vector3, demi: float, numerateur: int, denominateur: int) -> Vector3:
	return p + r * (-demi + demi * 2.0 * (float(numerateur) / float(denominateur)))


static func _triangle(outil: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	outil.add_vertex(a)
	outil.add_vertex(b)
	outil.add_vertex(c)


## Le plus grand écart vertical, au milieu de la section, entre la courbe et
## ses bandes coupées en triangles (voir _quad). (p0, r0) et (p1, r1) : le
## milieu et le côté droit de la chaussée à d0 et à d1.
static func _ecart(track: TrackCurve, d0: float, d1: float, p0: Vector3, p1: Vector3,
		r0: Vector3, r1: Vector3, bords: PackedFloat32Array) -> float:
	var m := (d0 + d1) * 0.5
	var pm := track.position_at(m)
	var rm := track.right_at(m)
	var pire := 0.0
	for f: float in MESURES:
		var vrai := pm + rm * track.half_width * f
		var depuis := vrai + Vector3.UP * 5.0
		var trouve := false
		for k in bords.size() - 1:
			var a0 := p0 + r0 * bords[k]
			var a1 := p1 + r1 * bords[k]
			var b0 := p0 + r0 * bords[k + 1]
			var b1 := p1 + r1 * bords[k + 1]
			for t: Array in [[a0, a1, b0], [b0, a1, b1]]:
				var touche: Variant = Geometry3D.ray_intersects_triangle(depuis, Vector3.DOWN, t[0], t[1], t[2])
				if touche != null:
					pire = maxf(pire, absf((touche as Vector3).y - vrai.y))
					trouve = true
					break
			if trouve:
				break
	return pire
