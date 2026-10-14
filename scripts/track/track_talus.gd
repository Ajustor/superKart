class_name TrackTalus
extends RefCounted

## Le talus : une pente douce qui descend d'un bord (la route, une bande
## hors-piste) jusque sous le sol d'à côté. Sans lui, le bord était une
## marche de 13 à 45 cm, un mur qu'on ne voyait pas : on ne remontait pas du
## sol sur la route, ou l'on passait dessous.
##
## Une seule source de géométrie, des triangles, dont la route et les bandes
## font un maillage (on le voit : le kart qui le remonte ne flotte pas
## au-dessus de rien) et une collision.

## Ce qu'il descend au moins, et sur quelle largeur : sa pente, 15°.
const CHUTE := 1.2
const LARGEUR := 4.5
const PENTE := CHUTE / LARGEUR
## Ce qu'il descend au plus : jusqu'au sol le plus bas où l'on roule encore à
## côté de la route. Plus bas, le kart est tombé (RaceSession), remis en
## piste. Un talus de 1,2 m s'arrêtait au-dessus d'un sol plus bas : sous le
## bord haut d'un virage relevé, deux mètres au-dessus de la prairie, on
## roulait sous la route, le toit dans sa dalle.
const CHUTE_MAX := RaceSession.HAUTEUR_DE_CHUTE
## Son pied passe d'autant sous le sol qu'il rejoint : le sol n'est qu'une
## grille de mailles de six mètres, le talus un plan.
const ENFOUI := 0.3
## De section en section, les pieds avancent au moins de ça fois l'axe.
const AVANCE_DES_PIEDS := 0.05
const NOM := "Talus"


## Le bord d'une route ou d'une bande, sommet par sommet : `sommets` (le haut
## du talus) et, pour chacun, sa distance le long du tracé ; `cote`, le côté
## vers lequel il descend (+1 à droite, -1 à gauche). Un bord fermé (le tour
## entier) finit sur son premier sommet.
class Bord:
	var sommets := PackedVector3Array()
	var distances := PackedFloat32Array()
	var cote := 0.0
	## L'écart à l'axe de chaque sommet quand il change (le bord d'une bande
	## qui s'arrête avant de se replier) ; vide, celui passé à le_long.
	var lateraux := PackedFloat32Array()

	func ferme() -> bool:
		return sommets.size() > 2 and sommets[0] == sommets[sommets.size() - 1]


## Le talus posé le long d'un bord : ses triangles, et pour chacun la
## distance le long du tracé où il est (pour le ranger dans son monde).
class Pente:
	var triangles := PackedVector3Array()
	var distances := PackedFloat32Array()

	func ajouter(points: Array, distance: float) -> void:
		for p: Vector3 in points:
			triangles.append(p)
		for i in points.size() / 3:
			distances.append(distance)


## De combien descend le talus en ce point d'un bord à la hauteur `haut` :
## assez pour passer ENFOUI sous le sol réel qu'il rejoint — mesuré à deux
## mètres du bord, et là où tomberait son pied s'il y est plus bas —, au moins
## CHUTE. Zéro s'il n'y a pas de sol (le vide, un trou) ou s'il est plus bas
## que CHUTE_MAX. `ici(x)` : le point à x mètres du bord, vers l'extérieur, à
## la hauteur du bord ; `d` : où l'on est le long du tracé.
static func profondeur(circuit: Track, d: float, haut: float, ici: Callable) -> float:
	var sol := circuit.hauteur_du_sol_reel(ici.call(2.0), d)
	if sol < haut - CHUTE_MAX:
		return 0.0
	var p := clampf(haut - sol + ENFOUI, CHUTE, CHUTE_MAX)
	var au_pied := circuit.hauteur_du_sol_reel(ici.call(p / PENTE), d)
	if au_pied > -INF and au_pied < sol:
		p = clampf(haut - au_pied + ENFOUI, CHUTE, CHUTE_MAX)
	return p


## Le talus le long d'un bord, vers `cote` (+1 à droite, -1 à gauche) depuis
## l'écart `lateral` (ou ceux du bord, Bord.lateraux) : de chaque sommet,
## une pente de 15° jusqu'à sa profondeur (profondeur). Entre deux sommets
## qui en ont un, là où `porte(milieu)` est vrai. Ses sommets hauts sont ceux
## du bord, ni plus ni moins : coupé autrement, sa corde passait au-dessus ou
## au-dessous de celle du bord, une lèvre d'un centimètre qui arrête un kart.
##
## Ses pieds, enfouis, descendent de chaque sommet selon le plat lissé
## (TrackFeature.plat_lisse) : pris de right_at, sommet par sommet sur une
## route recoupée tous les 25 cm, ils allaient et venaient d'un sommet à
## l'autre et le talus se repliait en faces raides. À l'intérieur d'un virage
## serré, pas plus loin que là où ils se croiseraient
## (TrackFeature.portee_sans_repli) : la pente se raidit d'autant, jusqu'à
## 45° ; plus raide, pas de talus — il pendait, retourné, au-dessus du relief.
##
## Au bout d'un tronçon, la pente se referme le long du tracé (_bout) : sans
## elle, le talus finissait en une face de 70 cm où l'on butait en le longeant.
## Aux deux bouts d'un bord ouvert aussi si `fermer_les_bouts` : ceux d'une
## bande, pas ceux de la route, qui s'y arrête au bord d'un trou.
static func le_long(circuit: Track, c: TrackCurve, bord: Bord, lateral: float, cote: float,
		porte: Callable, fermer_les_bouts := false) -> Pente:
	var pente := Pente.new()
	var n := bord.sommets.size()
	if n < 2:
		return pente
	var lateraux := bord.lateraux
	if lateraux.size() != n:
		lateraux = PackedFloat32Array()
		lateraux.resize(n)
		lateraux.fill(lateral)
	var ferme := bord.ferme()
	var plats := PackedVector3Array()
	var axes := PackedVector3Array()
	var profondeurs := PackedFloat32Array()
	var larges := PackedFloat32Array()
	for i in n:
		var d := bord.distances[i]
		var h := bord.sommets[i]
		var plat := TrackFeature.plat_lisse(c, d) * cote
		plats.append(plat)
		axes.append(c.position_at(d))
		var p := profondeur(circuit, d, h.y, func(x: float) -> Vector3: return h + plat * x)
		profondeurs.append(p)
		larges.append(p / PENTE)
	# Pas de pieds croisés : de sommet en sommet, ils avancent encore avec
	# l'axe, si peu que ce soit (enfouis, ils n'ont pas à être roulables : une
	# face trop raide, elle, n'est pas posée, _mur).
	for i in n - 1:
		var ecart := maxf(larges[i], larges[i + 1])
		if ecart <= 0.0:
			continue
		var limite := TrackFeature._limite_sans_repli(axes[i], axes[i + 1], bord.sommets[i], bord.sommets[i + 1],
			plats[i], plats[i + 1], ecart, false, AVANCE_DES_PIEDS)
		larges[i] = minf(larges[i], limite)
		larges[i + 1] = minf(larges[i + 1], limite)
	# Ni au-dessus de la route (Track.talus_libre) : d'une autre portion, ou
	# de celle-ci au creux d'une épingle. Il s'arrête un mètre avant.
	for i in n:
		var large := larges[i]
		if profondeurs[i] <= 0.0 or large <= 0.0:
			continue
		var d := bord.distances[i]
		var serre := signf(c.turn_at(d)) == cote and absf(lateraux[i]) + large > 0.7 * c.radius_at(d)
		if not serre and not circuit.autre_route_pres(bord.sommets[i], large + c.half_width + 2.0, d):
			continue
		var x := 1.0
		while x <= large + 0.5:
			var xx := minf(x, large)
			var ici := bord.sommets[i] + plats[i] * xx
			if not circuit.talus_libre(ici, bord.sommets[i].y - profondeurs[i] * xx / large, d):
				larges[i] = maxf(xx - 1.0, 0.0)
				break
			x += 1.0
	if ferme:
		larges[0] = minf(larges[0], larges[n - 1])
		larges[n - 1] = larges[0]
	var pieds := PackedVector3Array()
	for i in n:
		if larges[i] < profondeurs[i]:
			profondeurs[i] = 0.0
		pieds.append(bord.sommets[i] + plats[i] * larges[i] + Vector3.DOWN * profondeurs[i])
	var pose: Array[bool] = []
	for i in n - 1:
		pose.append(profondeurs[i] > 0.0 and profondeurs[i + 1] > 0.0
			and porte.call((bord.distances[i] + bord.distances[i + 1]) * 0.5)
			and not _mur(bord.sommets[i], bord.sommets[i + 1], pieds[i], pieds[i + 1]))
	for i in n - 1:
		if not pose[i]:
			continue
		var h0 := bord.sommets[i]
		var h1 := bord.sommets[i + 1]
		var b0 := pieds[i]
		var b1 := pieds[i + 1]
		# Tournés vers le ciel, quel que soit le côté.
		if cote > 0.0:
			pente.ajouter([h0, h1, b0, b0, h1, b1], (bord.distances[i] + bord.distances[i + 1]) * 0.5)
		else:
			pente.ajouter([b0, b1, h0, h0, b1, h1], (bord.distances[i] + bord.distances[i + 1]) * 0.5)
		# Les bouts d'un tronçon.
		var premier := i == 0 and not ferme
		var dernier := i == n - 2 and not ferme
		if (premier and fermer_les_bouts) or (not premier and not pose[posmod(i - 1, n - 1)]):
			_bout(pente, c, bord.distances[i], h0, b0, profondeurs[i], lateraux[i], cote, -1.0)
		if (dernier and fermer_les_bouts) or (not dernier and not pose[posmod(i + 1, n - 1)]):
			_bout(pente, c, bord.distances[i + 1], h1, b1, profondeurs[i + 1], lateraux[i + 1], cote, 1.0)
	return pente


## Un quadrilatère de talus serait-il un mur (Kart : une normale à moins de
## 0,6 vers le haut) ? Là où le bord lui-même descend raide en tournant
## serré, mieux vaut pas de talus qu'une face où l'on bute.
const PENTE_MAX := 0.64

static func _mur(h0: Vector3, h1: Vector3, b0: Vector3, b1: Vector3) -> bool:
	# Coupé selon l'une ou l'autre diagonale, selon le côté : les deux.
	for t: Array in [[h0, h1, b0], [b0, h1, b1], [b0, b1, h0], [h0, b1, h1]]:
		var normale := ((t[1] as Vector3) - (t[0] as Vector3)).cross((t[2] as Vector3) - (t[0] as Vector3))
		if normale.length_squared() > 0.000001 and absf(normale.normalized().y) < PENTE_MAX:
			return true
	return false


## La pente qui referme un tronçon de talus au bout `d` : du haut `h` et du
## pied `b` de sa dernière coupe, elle descend le long du tracé, vers `sens`,
## à la même pente, jusqu'à la profondeur `p` au ras du bord. On la descend
## ou on la monte comme le talus ; plus de face.
static func _bout(pente: Pente, c: TrackCurve, d: float, h: Vector3, b: Vector3, p: float,
		lateral: float, cote: float, sens: float) -> void:
	var loin := TrackFeature.point_lisse(c, d + sens * p / PENTE, lateral, 0.0)
	var bord_loin := loin.y
	loin.y = h.y - p
	# Près du centre d'un virage serré, avancer le long du tracé n'éloigne
	# presque plus : la pente serait un mur. Et là où le bord monte plus vite
	# qu'elle ne descend, au creux d'une épingle qui grimpe, elle finirait
	# au-dessus de la chaussée. Pas de pente.
	if _mur(h, loin, b, b) or loin.y > bord_loin - ENFOUI:
		return
	if (cote > 0.0) == (sens > 0.0):
		pente.ajouter([h, loin, b], d)
	else:
		pente.ajouter([h, b, loin], d)


## Le talus en travers d'un bout de bande, à `d` : de `de_lateral` à
## `a_lateral`, en descendant le long du tracé vers `sens` (-1 avant le bout,
## vers le départ ; +1 après), à 15°, jusqu'à sa profondeur (profondeur). Par
## tranches d'un mètre en travers ; son haut est le bout de la bande
## (TrackFeature.point_lisse, comme elle).
static func en_travers(circuit: Track, c: TrackCurve, d: float, de_lateral: float, a_lateral: float,
		sens: float) -> PackedVector3Array:
	var triangles := PackedVector3Array()
	var n := maxi(ceili(absf(a_lateral - de_lateral)), 1)
	var hauts := PackedVector3Array()
	var pieds := PackedVector3Array()
	var profondeurs := PackedFloat32Array()
	for i in n + 1:
		var l := lerpf(de_lateral, a_lateral, float(i) / float(n))
		var h := TrackFeature.point_lisse(c, d, l, 0.0)
		var ici := func(x: float) -> Vector3:
			var q := TrackFeature.point_lisse(c, d + sens * x, l, 0.0)
			return Vector3(q.x, h.y, q.z)
		var p := profondeur(circuit, d, h.y, ici)
		hauts.append(h)
		profondeurs.append(p)
		pieds.append((ici.call(p / PENTE) as Vector3) + Vector3.DOWN * p)
	for i in n:
		if profondeurs[i] <= 0.0 or profondeurs[i + 1] <= 0.0 or _mur(hauts[i], hauts[i + 1], pieds[i], pieds[i + 1]):
			continue
		triangles.append_array([hauts[i], pieds[i], hauts[i + 1], hauts[i + 1], pieds[i], pieds[i + 1]])
	return triangles


## Les bords de la route, tels que sa collision les a (TrackBuilder.build) :
## de chaque côté (-1 puis +1), et pour chaque tronçon entre deux trous
## (`morceaux`), les sommets de son arête dans l'ordre du tracé, avec leur
## distance.
##
## Lus sur le maillage plutôt que recalculés : la route recoupe ses sections
## là où elles se tordent, et le talus coupé sur les seules sections de base
## passait jusqu'à 1,3 cm sous le bitume entre deux d'entre elles. Quoi que
## fasse le découpage, l'arête du talus est celle de la route. Si le maillage
## ne se laisse pas lire, les sections de base, comme avant.
static func bords_de_la_route(maillage: Mesh, c: TrackCurve, morceaux: Array[Vector2],
		segment_length: float) -> Array[Bord]:
	var faces := maillage.get_faces()
	# Les sommets, numérotés ; les arêtes, comptées : celles d'un seul
	# triangle sont au bord du ruban.
	var numeros := {}
	var points := PackedVector3Array()
	var aretes := {}
	for t in range(0, faces.size(), 3):
		var ids := PackedInt64Array([0, 0, 0])
		for k in 3:
			var v := faces[t + k]
			var id: int = numeros.get(v, -1)
			if id < 0:
				id = points.size()
				numeros[v] = id
				points.append(v)
			ids[k] = id
		for k in 3:
			var a := ids[k]
			var b := ids[(k + 1) % 3]
			var cle := (mini(a, b) << 32) | maxi(a, b)
			aretes[cle] = int(aretes.get(cle, 0)) + 1
	var voisins := {}
	for cle: int in aretes:
		if aretes[cle] != 1:
			continue
		for paire: Array in [[cle >> 32, cle & 0xFFFFFFFF], [cle & 0xFFFFFFFF, cle >> 32]]:
			var a: int = paire[0]
			if not voisins.has(a):
				voisins[a] = PackedInt64Array()
			var liste: PackedInt64Array = voisins[a]
			liste.append(paire[1])
			voisins[a] = liste
	# Les sections de base de la route, aux mêmes distances qu'elle
	# (TrackBuilder.build) : des repères le long de l'arête.
	var sections_totales := maxi(int(c.length / segment_length), 8)
	var bords: Array[Bord] = []
	for cote: float in [-1.0, 1.0]:
		for morceau in morceaux:
			var etendue := morceau.y - morceau.x
			var n := maxi(int(round(sections_totales * etendue / c.length)), 1)
			var pas := etendue / float(n)
			# En double précision : arrondies, elles ne tombaient plus sur les
			# sommets de la route.
			var stations := PackedFloat64Array()
			for i in n + 1:
				stations.append(morceau.x + pas * float(i))
			var bord := _suivre(c, numeros, points, voisins, stations, cote)
			if bord.sommets.size() < 2:
				bord = _bord_des_sections(c, stations, cote)
			bord.cote = cote
			bords.append(bord)
	return bords


## Le bord d'un côté de la route, sur ses seules sections de base.
static func _bord_des_sections(c: TrackCurve, stations: PackedFloat64Array, cote: float) -> Bord:
	var bord := Bord.new()
	for d in stations:
		bord.sommets.append(TrackFeature.point(c, d, c.half_width * cote, 0.0))
		bord.distances.append(d)
	return bord


## L'arête d'un côté d'un tronçon de route : du sommet de sa première
## section à celui de sa dernière, d'arête de bord en arête de bord, tout
## droit. Chaque sommet d'une section de base prend sa distance ; ceux d'entre
## deux (la route recoupée), la leur au prorata de la corde. Vide si le
## chemin se perd.
static func _suivre(c: TrackCurve, numeros: Dictionary, points: PackedVector3Array, voisins: Dictionary,
		stations: PackedFloat64Array, cote: float) -> Bord:
	var demi := c.half_width * cote
	var premier := stations[0]
	var dernier := stations[stations.size() - 1]
	var depart := _sommet_proche(numeros, points, voisins, c.position_at(premier) + c.right_at(premier) * demi)
	var arrivee := _sommet_proche(numeros, points, voisins, c.position_at(dernier) + c.right_at(dernier) * demi)
	if depart < 0 or arrivee < 0:
		return Bord.new()
	var chemin := PackedInt64Array([depart])
	var precedent := -1
	var ici := depart
	var direction := c.forward_at(premier)
	while chemin.size() <= points.size():
		var suivant := -1
		var meilleur := 0.0
		for v: int in (voisins.get(ici, PackedInt64Array()) as PackedInt64Array):
			if v == precedent:
				continue
			var cosinus := (points[v] - points[ici]).normalized().dot(direction)
			if cosinus > meilleur:
				meilleur = cosinus
				suivant = v
		if suivant < 0:
			return Bord.new()
		direction = (points[suivant] - points[ici]).normalized()
		precedent = ici
		ici = suivant
		chemin.append(ici)
		if ici == arrivee:
			break
	if ici != arrivee:
		return Bord.new()
	# Les distances : aux sommets des sections de base la leur — reconnus à un
	# millimètre près, dans l'ordre du chemin : get_faces arrondit les sommets
	# au dixième de millimètre —, aux deux bouts celles du tronçon, entre deux
	# au prorata de la corde.
	var distances := PackedFloat64Array()
	distances.resize(chemin.size())
	distances.fill(NAN)
	var j := 1
	for k in range(1, chemin.size() - 1):
		var v := points[chemin[k]]
		for essai in 2:
			if j + essai >= stations.size() - 1:
				break
			var d := stations[j + essai]
			if v.distance_squared_to(c.position_at(d) + c.right_at(d) * demi) < 0.000001:
				distances[k] = d
				j += essai + 1
				break
	distances[0] = premier
	distances[chemin.size() - 1] = dernier
	var a := 0
	while a < chemin.size() - 1:
		var b := a + 1
		var longueur := points[chemin[a]].distance_to(points[chemin[b]])
		while is_nan(distances[b]):
			longueur += points[chemin[b]].distance_to(points[chemin[b + 1]])
			b += 1
		var parcouru := 0.0
		for k in range(a + 1, b):
			parcouru += points[chemin[k - 1]].distance_to(points[chemin[k]])
			# Puis là où la coupe de la route passe par le sommet : sa
			# droite est perpendiculaire à l'axe.
			var d := lerpf(distances[a], distances[b], parcouru / longueur)
			for essai in 3:
				d += (points[chemin[k]] - c.position_at(d)).dot(c.forward_at(d))
			distances[k] = clampf(d, distances[a], distances[b])
		a = b
	var bord := Bord.new()
	for k in chemin.size():
		bord.sommets.append(points[chemin[k]])
		bord.distances.append(distances[k])
	return bord


## Le sommet du bord du maillage (`voisins` : ceux d'une arête de bord) en
## ce point, à un millimètre près : get_faces arrondit les sommets au dixième
## de millimètre. -1 s'il n'y en a pas.
static func _sommet_proche(numeros: Dictionary, points: PackedVector3Array, voisins: Dictionary,
		ici: Vector3) -> int:
	var id: int = numeros.get(ici, -1)
	if id >= 0:
		return id
	var meilleur := 0.000001
	for k: int in voisins:
		var e := points[k].distance_squared_to(ici)
		if e < meilleur:
			meilleur = e
			id = k
	return id


## Le talus posé : visible avec `materiau`, et solide (les deux faces), sur la
## couche du décor. Sans triangle, rien.
static func poser(racine: Node3D, triangles: PackedVector3Array, materiau: Material,
		calque: int = 1) -> Node3D:
	if triangles.is_empty():
		return null
	var talus := Node3D.new()
	talus.name = NOM
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in triangles:
		outil.add_vertex(p)
	outil.generate_normals()
	var affichage := MeshInstance3D.new()
	affichage.mesh = outil.commit()
	affichage.material_override = materiau
	affichage.layers = calque
	talus.add_child(affichage)
	var forme := ConcavePolygonShape3D.new()
	forme.backface_collision = true
	forme.set_faces(triangles)
	var corps := StaticBody3D.new()
	corps.collision_layer = Kart.COUCHE_DECOR
	var collision := CollisionShape3D.new()
	collision.shape = forme
	corps.add_child(collision)
	talus.add_child(corps)
	racine.add_child(talus)
	return talus
