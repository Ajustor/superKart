class_name TrackBuilder

## Extrude un ruban de route le long d'un TrackCurve. Le maillage produit sert
## à la fois à l'affichage et, converti en trimesh, à la collision.


## Découpe la courbe en segments d'environ `segment_length` mètres et relie
## chaque section à la suivante par deux triangles.
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

	var morceaux := troncons(track.length, trous)
	# Sans trou, le découpage reste exactement celui d'avant : même nombre de
	# sections, au même endroit.
	var sections_totales := maxi(int(track.length / segment_length), 8)
	for morceau in morceaux:
		var etendue := morceau.y - morceau.x
		var sections := maxi(int(round(sections_totales * etendue / track.length)), 1)
		var pas := etendue / float(sections)
		for i in sections:
			_section(outil, track, morceau.x + pas * float(i), morceau.x + pas * float(i + 1), couleurs)

	outil.generate_normals()
	return outil.commit()


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
const ECART_MAX := 0.01
## Une bande d'une section tordue fait au plus cette largeur.
const BANDE_MAX := 3.0


static func _section(outil: SurfaceTool, track: TrackCurve, d0: float, d1: float,
		couleurs: PackedColorArray = PackedColorArray()) -> void:
	# Le dévers ne change pas toujours d'un pas régulier : au milieu de la
	# section, le bord peut passer au-dessus ou au-dessous de la corde qui
	# joint ses deux bouts. On la coupe alors en deux, dans le sens de la
	# marche. Seule la hauteur compte : à plat, la corde d'un virage est la
	# même pour toutes les routes.
	if d1 - d0 > 0.25:
		var m := (d0 + d1) * 0.5
		for lateral: float in [-track.half_width, 0.0, track.half_width]:
			var vrai := track.position_at(m) + track.right_at(m) * lateral
			var corde := (track.position_at(d0) + track.right_at(d0) * lateral
				+ track.position_at(d1) + track.right_at(d1) * lateral) * 0.5
			if absf(vrai.y - corde.y) > ECART_MAX:
				_section(outil, track, d0, m, couleurs)
				_section(outil, track, m, d1, couleurs)
				return
	var largeur := track.half_width * 2.0
	var p0 := track.position_at(d0)
	var p1 := track.position_at(d1)
	var r0 := track.right_at(d0)
	var r1 := track.right_at(d1)
	# Une section dont le dévers change d'un bout à l'autre est un
	# quadrilatère tordu : coupé selon une seule diagonale, son milieu
	# passait jusqu'à 20 cm sous la courbe, sous un marquage qui flottait.
	# Recoupée dans la longueur, en bandes, chacune n'est plus tordue que
	# d'autant moins. Une section plate garde ses deux triangles.
	var g0 := p0 - r0 * track.half_width
	var g1 := p1 - r1 * track.half_width
	var dr0 := p0 + r0 * track.half_width
	var dr1 := p1 + r1 * track.half_width
	var plan := Plane(g0, g1, dr0)
	var torsion := absf(plan.distance_to(dr1))
	var bandes := 1
	if torsion * 0.25 > ECART_MAX:
		bandes = maxi(ceili(largeur / BANDE_MAX), ceili(torsion * 0.25 / ECART_MAX))
	# Les couleurs de l'arc-en-ciel découpent déjà la chaussée : chacune
	# est recoupée de même.
	var n := maxi(couleurs.size(), 1)
	var par_couleur := maxi(ceili(float(bandes) / n), 1) if bandes > 1 else 1
	for j in n:
		if not couleurs.is_empty():
			outil.set_color(couleurs[j])
		for k in par_couleur:
			var g := -track.half_width + largeur * float(j * par_couleur + k) / float(n * par_couleur)
			var d := -track.half_width + largeur * float(j * par_couleur + k + 1) / float(n * par_couleur)
			_quad(outil, p0 + r0 * g, p1 + r1 * g, p0 + r0 * d, p1 + r1 * d)
