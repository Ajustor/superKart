extends GutTest

var track: TrackCurve


func _anneau(rayon: float = 50.0, points: int = 16) -> Curve3D:
	var c := Curve3D.new()
	var pas := TAU / float(points)
	var poignee := rayon * (4.0 / 3.0) * tan(pas / 4.0)
	for i in points:
		var a := pas * float(i)
		var p := Vector3(sin(a) * rayon, 0.0, -cos(a) * rayon)
		var t := Vector3(cos(a), 0.0, sin(a)) * poignee
		c.add_point(p, -t, t)
	c.add_point(c.get_point_position(0), -c.get_point_out(0), c.get_point_out(0))
	return c


func before_each() -> void:
	track = TrackCurve.new(_anneau(), 8.0)


func test_les_normales_pointent_vers_le_haut() -> void:
	var maillage := TrackBuilder.build(track, 5.0)
	var normales: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_gt(normales.size(), 0, "le maillage doit porter des normales")
	for n in normales:
		assert_gt(n.y, 0.9,
			"une normale vers le bas trahit un ordre de sommets inversé")


func test_chaque_section_donne_deux_triangles() -> void:
	var maillage := TrackBuilder.build(track, 10.0)
	var sommets: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sections := maxi(int(track.length / 10.0), 8)
	assert_eq(sommets.size(), sections * 6,
		"deux triangles de trois sommets par section")


func test_le_ruban_couvre_toute_la_largeur() -> void:
	var maillage := TrackBuilder.build(track, 5.0)
	var sommets: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ecart_max := 0.0
	for v in sommets:
		ecart_max = maxf(ecart_max, absf(track.lateral_offset(v)))
	assert_almost_eq(ecart_max, track.half_width, 0.3,
		"les bords du ruban tombent sur la demi-largeur")


## Une ligne droite de 60 m dont le dévers passe de 11° à 6° en 10 m, puis
## revient : les sections du milieu sont des quadrilatères tordus.
func _devers_qui_change() -> TrackCurve:
	var c := Curve3D.new()
	var tilts := [11.0, 6.0, 11.0, 6.0, 11.0, 6.0, 11.0]
	for i in tilts.size():
		c.add_point(Vector3(0.0, 0.0, -10.0 * i))
		c.set_point_tilt(i, deg_to_rad(tilts[i]))
	return TrackCurve.new(c, 9.0)


## La hauteur du maillage sous ce point, par un rayon vertical contre ses
## triangles ; INF s'il n'y en a pas.
static func _hauteur_du_maillage(triangles: PackedVector3Array, ici: Vector3) -> float:
	for t in range(0, triangles.size(), 3):
		var touche: Variant = Geometry3D.ray_intersects_triangle(ici + Vector3.UP * 5.0, Vector3.DOWN,
			triangles[t], triangles[t + 1], triangles[t + 2])
		if touche != null:
			return (touche as Vector3).y
	return INF


func test_le_bitume_suit_la_courbe_quand_le_devers_change() -> void:
	var c := _devers_qui_change()
	var maillage := TrackBuilder.build(c, 2.0)
	var faces := maillage.get_faces()
	var sections := maxi(int(c.length / 2.0), 8)
	var pire := 0.0
	var ou := ""
	for i in sections - 1:
		var milieu := c.length * (float(i) + 0.5) / float(sections)
		# Aux deux bouts, la courbe ouverte prend sa tangente à l'autre bout.
		if milieu < 4.0 or milieu > c.length - 4.0:
			continue
		for lateral in [-9.0, -4.5, 0.0, 4.5, 9.0]:
			# Un rien en dedans des bords : un rayon pile sur l'arête du ruban
			# peut le manquer.
			var l: float = clampf(lateral, -8.95, 8.95)
			var attendu := c.position_at(milieu) + c.right_at(milieu) * l
			var h := _hauteur_du_maillage(faces, attendu)
			var ecart := absf(h - attendu.y)
			if ecart > pire:
				pire = ecart
				ou = "%.1f m, %+.1f" % [milieu, l]
	assert_lt(pire, 0.02, "le bitume s'écarte de %.1f cm de la courbe (%s)" % [pire * 100.0, ou])


## L'anneau, relevé de 15° au départ seulement : les sections de part et
## d'autre de la ligne de départ se tordent et sont recoupées, leurs voisines
## restent plates, avec leurs deux triangles.
func _anneau_releve_au_depart() -> TrackCurve:
	var c := _anneau()
	c.set_point_tilt(0, deg_to_rad(15.0))
	c.set_point_tilt(c.point_count - 1, deg_to_rad(15.0))
	return TrackCurve.new(c, 8.0)


## Les sommets du maillage, trois par triangle, tels que build() les a posés.
## Pas get_faces() : il les arrondit au dixième de millimètre (c'est aussi ce
## que reçoit la collision, par create_trimesh_shape).
static func _triangles(maillage: ArrayMesh) -> PackedVector3Array:
	return maillage.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


## Les arêtes portées par un seul triangle ailleurs que sur le pourtour du
## ruban : ses rives et, s'il y a des trous, ses bouts au bord du vide. Toute
## autre est une jonction en T (un sommet posé sur l'arête d'un voisin sans en
## être un sommet) ou une couture dont les deux côtés ne tombent pas sur les
## mêmes sommets. Rendue : [nombre, un exemple].
static func _aretes_ouvertes(faces: PackedVector3Array, c: TrackCurve,
		trous: Array[Vector2] = []) -> Array:
	var portees := {}
	for t in range(0, faces.size(), 3):
		for k in 3:
			var a := faces[t + k]
			var b := faces[t + (k + 1) % 3]
			var cle := [a, b] if a < b else [b, a]
			portees[cle] = portees.get(cle, 0) + 1
	var ouvertes := 0
	var exemple := ""
	for cle: Array in portees:
		if portees[cle] != 1:
			continue
		var sur_la_rive := true
		var au_bord_d_un_trou := true
		for s: Vector3 in cle:
			var d := c.distance_of(s)
			sur_la_rive = sur_la_rive and absf(c.lateral_offset_at(s, d)) > c.half_width - 0.01
			var pres := false
			for trou in trous:
				pres = pres or absf(d - trou.x) < 0.05 or absf(d - trou.y) < 0.05
			au_bord_d_un_trou = au_bord_d_un_trou and pres
		if not (sur_la_rive or au_bord_d_un_trou):
			ouvertes += 1
			var d := c.distance_of(cle[0])
			exemple = "%.2f m, de %+.2f à %+.2f" % [d, c.lateral_offset_at(cle[0], d), c.lateral_offset_at(cle[1], d)]
	return [ouvertes, exemple]


## Là où une section recoupée en bandes touche une section plate, les
## sommets des bandes tombaient au milieu de la grande arête d'en face : une
## jonction en T. Les flottants y laissent une fente, que la collision
## élargit en arrondissant ses sommets : un rayon de roue tiré pile sur la
## couture passait à travers la route. Chaque arête du dedans doit être
## partagée par deux triangles, ligne de départ comprise.
func test_le_bitume_n_a_pas_de_fente_entre_sections_recoupees_et_plates() -> void:
	var c := _anneau_releve_au_depart()
	var uni := _aretes_ouvertes(_triangles(TrackBuilder.build(c, 5.0)), c)
	assert_eq(uni[0], 0, "%d arêtes du bitume sans voisin (%s)" % uni)
	var couleurs := _aretes_ouvertes(_triangles(TrackBuilder.build(c, 5.0, [], Track.ARC_EN_CIEL)), c)
	assert_eq(couleurs[0], 0, "arc-en-ciel : %d arêtes sans voisin (%s)" % couleurs)


## Un trou loin du départ coupe le tour en deux tronçons, dont le second
## rejoint le premier à la ligne de départ : la couture y tient aussi.
func test_le_bitume_n_a_pas_de_fente_a_la_ligne_de_depart_avec_un_trou() -> void:
	var c := _anneau_releve_au_depart()
	var trous: Array[Vector2] = [Vector2(100.0, 120.0)]
	var ouvertes := _aretes_ouvertes(_triangles(TrackBuilder.build(c, 5.0, trous)), c, trous)
	assert_eq(ouvertes[0], 0, "%d arêtes du bitume sans voisin (%s)" % ouvertes)


## Le recoupage reste là où il sert : la section tordue est bien recoupée,
## sans quoi le test des fentes passerait pour rien.
func test_l_anneau_releve_est_recoupe_au_depart() -> void:
	var c := _anneau_releve_au_depart()
	var sommets: PackedVector3Array = TrackBuilder.build(c, 5.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sections := maxi(int(c.length / 5.0), 8)
	assert_gt(sommets.size(), sections * 6, "les sections tordues sont recoupées")


## Les rives rendues sont, au bit près, les sommets du bord du bitume : un
## talus qui les suit ne laisse ni marche ni fente. Toutes, coupes des
## sections recoupées comprises, et rien d'autre ; dans l'ordre de la marche,
## d'un seul tenant par-dessus la ligne de départ quand un trou coupe le tour.
func test_les_rives_sont_les_sommets_du_bord_du_bitume() -> void:
	var c := _anneau_releve_au_depart()
	var trous: Array[Vector2] = [Vector2(100.0, 120.0)]
	var du_bord := {}
	for s in _triangles(TrackBuilder.build(c, 5.0, trous)):
		if absf(c.lateral_offset(s)) > c.half_width - 0.01:
			du_bord[s] = true
	var rives := TrackBuilder.rives(c, 5.0, trous)
	assert_eq(rives.size(), 1, "un seul tronçon, de 120 m à 100 m en passant par le départ")
	var distances: PackedFloat64Array = rives[0].distances
	assert_almost_eq(distances[0], 120.0, 0.001)
	assert_almost_eq(distances[distances.size() - 1], c.length + 100.0, 0.001)
	var a_rebours := 0
	for i in range(1, distances.size()):
		if distances[i] <= distances[i - 1]:
			a_rebours += 1
	assert_eq(a_rebours, 0, "dans l'ordre de la marche")
	var vues := {}
	var etrangers := 0
	for cote: String in ["gauche", "droite"]:
		var points: PackedVector3Array = rives[0][cote]
		assert_eq(points.size(), distances.size(), "un point par distance")
		for s in points:
			vues[s] = true
			if not du_bord.has(s):
				etrangers += 1
	assert_eq(etrangers, 0, "des points de rive qui ne sont pas des sommets du bitume")
	assert_eq(vues.size(), du_bord.size(), "chaque sommet du bord est sur une rive")
	# Sans trou, un seul tour, qui se referme sur son premier point.
	var tour: Dictionary = TrackBuilder.rives(c, 5.0)[0]
	var gauche: PackedVector3Array = tour.gauche
	assert_eq(gauche[gauche.size() - 1], gauche[0], "le tour se referme")
	assert_almost_eq((tour.distances as PackedFloat64Array)[gauche.size() - 1], c.length, 0.01)
