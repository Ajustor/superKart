extends GutTest

## La géométrie des talus (TrackTalus), mesurée comme le kart la sent : par
## des rayons verticaux contre la collision. Le haut d'un talus doit être le
## bord qu'il prolonge, sommet pour sommet ; son pied doit passer sous le sol
## qu'il rejoint ; le long du bord, il ne doit s'arrêter sur aucune marche.
##
## Une lèvre d'un ou deux centimètres arrête un kart de face : c'est l'échelle
## de ces mesures.

const DEMI := 9.0
## Un dévers qui change à chaque point de contrôle, assez peu pour que le
## bord haut reste à moins de 1,2 m du sol à zéro : l'ancien talus y était
## partout, c'est sa couture qu'on mesure.
const DEVERS := [0.0, 7.0, 1.0, 6.0]

var track: Track


func _anneau(rayon: float, points: int = 16, devers: Array = []) -> Curve3D:
	var c := Curve3D.new()
	var pas := TAU / float(points)
	var poignee := rayon * (4.0 / 3.0) * tan(pas / 4.0)
	for i in points:
		var a := pas * float(i)
		var p := Vector3(sin(a) * rayon, 0.0, -cos(a) * rayon)
		var t := Vector3(cos(a), 0.0, sin(a)) * poignee
		c.add_point(p, -t, t)
		if not devers.is_empty():
			c.set_point_tilt(i, deg_to_rad(float(devers[i % devers.size()])))
	c.add_point(c.get_point_position(0), -c.get_point_out(0), c.get_point_out(0))
	if not devers.is_empty():
		c.set_point_tilt(points, deg_to_rad(float(devers[0])))
	return c


## Le circuit et ses éléments, montés dans l'arbre, la physique prête.
func _circuit(courbe: Curve3D, elements: Array) -> void:
	track = Track.new()
	track.half_width = DEMI
	track.curve = courbe
	for e in elements:
		track.add_child(e)
	add_child_autofree(track)
	await wait_physics_frames(2)


func _sol(altitude: float = -0.4) -> TrackSol:
	var s := TrackSol.new()
	s.altitude = altitude
	s.marge = 40.0
	return s


func _bande(decalage: float, largeur: float, debut: float, longueur: float) -> TrackOffroad:
	var b := TrackOffroad.new()
	b.debut = debut
	b.longueur = longueur
	b.decalage = decalage
	b.largeur = largeur
	return b


## La surface la plus haute sous ce point (masque 1), NAN s'il n'y a rien.
func _surface(ici: Vector3) -> float:
	var requete := PhysicsRayQueryParameters3D.create(ici + Vector3.UP * 4.0, ici - Vector3.UP * 8.0, 1)
	var touche := track.get_world_3d().direct_space_state.intersect_ray(requete)
	return (touche.position as Vector3).y if not touche.is_empty() else NAN


## La plus grande marche en travers d'un bord, de `d0` à `d1` : de deux
## centimètres en dedans du bord (`lateral`) à deux centimètres au-delà, la
## surface tous les deux millimètres ; le plus grand saut entre deux mesures.
## Une surface continue ne monte ni ne descend d'un millimètre sur deux ; une
## lèvre, de toute sa hauteur ; une fente, jusqu'au sol. Le bord réel est la
## corde du maillage, à quelques millimètres de la courbe : on le cherche de
## part et d'autre.
##
## Un rayon pile sur la couture de deux corps passe entre les deux : une
## fente de largeur nulle, qu'aucun kart ne sent. Une mesure isolée qui
## s'écarte de ses deux voisines, d'accord entre elles, est remplacée par
## elles (médiane de trois) ; une fente de deux mesures reste une fente.
func _pire_marche(d0: float, d1: float, lateral: float, cote: float) -> Dictionary:
	var c := track.track_curve
	var pire := 0.0
	var ou := ""
	var d := d0
	while d <= d1:
		var hauteurs: Array[float] = []
		for k in 21:
			var h := _surface(TrackFeature.point(c, d, lateral + cote * (-0.02 + 0.002 * float(k)), 0.0))
			hauteurs.append(h if not is_nan(h) else -INF)
		var lisses: Array[float] = [hauteurs[0]]
		for k in range(1, 20):
			var trois: Array[float] = [hauteurs[k - 1], hauteurs[k], hauteurs[k + 1]]
			trois.sort()
			lisses.append(trois[1])
		lisses.append(hauteurs[20])
		for k in range(1, 21):
			var saut := absf(lisses[k] - lisses[k - 1])
			if is_nan(saut):
				saut = INF
			if saut > pire:
				pire = saut
				ou = "%.2f m, à %+.3f m du bord (%.4f puis %.4f)" % [d, -0.02 + 0.002 * float(k),
					lisses[k - 1], lisses[k]]
		d += 0.25
	return {"pire": pire, "ou": ou}


# --- Le haut du talus est le bord ------------------------------------------------

## Le dévers va et vient à chaque point de contrôle, et avec lui la hauteur
## du bord, donc celle de la bande qui le prolonge à plat. Coupé tous les deux
## mètres quand la bande l'est tous les mètres, le haut du talus passait au
## milieu de la corde, au-dessus ou au-dessous du sommet de la bande : une
## lèvre, assez pour arrêter un kart qui y montait.
func test_le_talus_d_une_bande_prolonge_son_bord() -> void:
	await _circuit(_anneau(50.0, 16, DEVERS), [_sol(0.0), _bande(-(DEMI + 5.5), 11.0, 40.0, 160.0)])
	var m := _pire_marche(45.0, 195.0, -(DEMI + 11.0), -1.0)
	assert_lt(m.pire, 0.003, "marche de %.1f cm au bord de la bande, à %s" % [m.pire * 100.0, m.ou])


## Un dévers qui change à chaque point de contrôle : la route est recoupée
## dans la longueur là où ses sections se tordent (TrackBuilder._section). Le
## talus, coupé sur les seules sections de base, n'avait pas ces sommets : son
## haut passait jusqu'à 1,3 cm sous le bord du bitume, une lèvre qui arrêtait
## le kart qui longeait la rive.
func test_le_talus_de_la_route_suit_son_bord_recoupe() -> void:
	await _circuit(_anneau(50.0, 16, DEVERS), [_sol(0.0)])
	var longueur := track.track_curve.length
	for cote: float in [-1.0, 1.0]:
		var m := _pire_marche(1.0, longueur - 1.0, DEMI * cote, cote)
		assert_lt(m.pire, 0.003, "marche de %.1f cm au bord %+.0f de la route, à %s" % [m.pire * 100.0, cote, m.ou])


# --- Le pied du talus est sous le sol --------------------------------------------

## Un virage relevé de 15° au-dessus d'une prairie : le bord haut est 2,7 m
## au-dessus d'elle. Un talus de 1,2 m n'y descendait pas : il n'y en avait
## pas, et le kart de la prairie passait sous le bord, coincé sous la dalle.
func test_le_talus_descend_jusqu_au_sol_sous_un_bord_releve() -> void:
	await _circuit(_anneau(50.0, 16, [15.0]), [_sol()])
	var c := track.track_curve
	var haut := 1.0 if c.right_at(100.0).y > 0.0 else -1.0
	for d: float in [60.0, 100.0, 140.0, 200.0]:
		var bord := TrackFeature.point(c, d, haut * DEMI, 0.0)
		var sol := -0.4
		assert_gt(bord.y - sol, 2.0, "le bord haut est loin au-dessus de la prairie")
		# À deux mètres du bord : le talus, pas la prairie.
		var ici := TrackFeature.point(c, d, haut * (DEMI + 2.0), 0.0)
		var attendu := bord.y - 2.0 * TrackTalus.CHUTE / TrackTalus.LARGEUR
		assert_almost_eq(_surface(ici), attendu, 0.02, "le talus à 2 m du bord haut (%.0f m)" % d)
		# Et jusqu'au sol : au pied, plus de marche.
		var profil := _profil_en_travers(d, haut, DEMI, DEMI + 16.0)
		assert_lt(profil.saut, 0.1, "en descendant du bord vers la prairie (%.0f m) : %s" % [d, profil.ou])


## La surface en travers, du bord vers l'extérieur, tous les 25 cm : le plus
## grand saut entre deux mesures.
func _profil_en_travers(d: float, cote: float, de: float, a: float) -> Dictionary:
	var c := track.track_curve
	var saut := 0.0
	var ou := ""
	var avant := NAN
	var l := de + 0.05
	while l <= a:
		var h := _surface(TrackFeature.point(c, d, cote * l, 0.0))
		if not is_nan(avant):
			var s := absf(h - avant) if not is_nan(h) else INF
			if s > saut:
				saut = s
				ou = "à %.2f m de l'axe (%.3f puis %.3f)" % [l, avant, h]
		avant = h
		l += 0.25
	return {"saut": saut, "ou": ou}


# --- Le long du talus, aucune marche ---------------------------------------------

## Un dévers qui va et vient de 0 à 15° : au bord haut, la prairie est tantôt
## 40 cm, tantôt 2,7 m plus bas. Le talus de 1,2 m s'arrêtait là où elle
## descendait trop, et reprenait plus loin : à un mètre du bord, une face de
## 70 cm au bout de chaque tronçon.
func test_le_long_du_talus_le_sol_ne_fait_pas_de_marche() -> void:
	await _circuit(_anneau(50.0, 16, [0.0, 8.0, 15.0, 8.0]), [_sol()])
	var c := track.track_curve
	for cote: float in [-1.0, 1.0]:
		for ecart: float in [1.0, 3.0]:
			var pire := 0.0
			var ou := ""
			var avant := NAN
			var d := 1.0
			while d < c.length - 1.0:
				var h := _surface(TrackFeature.point(c, d, cote * (DEMI + ecart), 0.0))
				if not is_nan(avant):
					var s := absf(h - avant) if not is_nan(h) else INF
					if s > pire:
						pire = s
						ou = "%.2f m (%.3f puis %.3f)" % [d, avant, h]
				avant = h
				d += 0.25
			assert_lt(pire, 0.12, "à %.0f m du bord %+.0f, une marche à %s" % [ecart, cote, ou])


# --- Ni les bandes ni les talus ne se replient -----------------------------------

## Les facettes de collision sous `noeud` raides à plus de 53° (le seuil d'un
## mur pour le kart) ou retournées, et où le long du tracé.
func _facettes_raides(piste: Track, noeud: Node) -> PackedStringArray:
	var c := piste.track_curve
	var raides := PackedStringArray()
	for f: CollisionShape3D in noeud.find_children("*", "CollisionShape3D", true, false):
		if not f.shape is ConcavePolygonShape3D:
			continue
		var faces := (f.shape as ConcavePolygonShape3D).get_faces()
		for t in range(0, faces.size(), 3):
			var n := (faces[t + 1] - faces[t]).cross(faces[t + 2] - faces[t])
			if n.length_squared() < 1e-10:
				continue
			if absf(n.normalized().y) < 0.6:
				var m := (faces[t] + faces[t + 1] + faces[t + 2]) / 3.0
				var d := c.distance_of(m)
				raides.append("%.0f%s" % [d, "D" if c.lateral_offset_at(m, d) > 0.0 else "G"])
	return raides


## Dans l'épingle du Jardin des champignons, la route grimpe en tournant sur
## vingt mètres de rayon. La bande de droite, prolongée à plat sur sept mètres
## vers le centre, s'y repliait en feuillets et en faces raides où le kart
## butait (390 et 410 m) ; dans l'épingle du Circuit, la bande d'après passait
## le centre du virage et son talus pendait au-dessus du relief (427 m). Le
## talus de la route, lui, se repliait en bas des sections recoupées.
func test_dans_les_virages_serres_ni_bande_ni_talus_ne_se_replie() -> void:
	for info in TrackCatalog.PISTES:
		var piste: Track = info.scene.instantiate()
		add_child(piste)
		var noeuds: Array[Node] = []
		for e in piste.elements():
			if e is TrackOffroad:
				noeuds.append(e)
		if piste.has_node(Track.NOM_TALUS):
			noeuds.append(piste.get_node(Track.NOM_TALUS))
		for noeud in noeuds:
			var raides := _facettes_raides(piste, noeud)
			assert_eq(raides.size(), 0, "%s, %s : %d facettes raides (%s)" % [info.id, noeud.name,
				raides.size(), ", ".join(raides.slice(0, 10))])
		remove_child(piste)
		piste.free()


## Les bords de la route lus sur sa collision : chaque sommet, à sa distance
## le long du tracé, est le bord de la route (à un millimètre, l'arrondi de
## get_faces). Repérés au prorata d'un tronçon entier, ils s'en écartaient de
## dix-sept mètres dans un virage : le pied du talus partait de travers, en
## feuillets superposés.
func test_les_bords_de_la_route_sont_a_leur_distance() -> void:
	var c := TrackCurve.new(_anneau(50.0, 16, DEVERS), DEMI)
	var trous: Array[Vector2] = [Vector2(100.0, 112.0)]
	var route := TrackBuilder.build(c, 2.0, trous)
	var bords := TrackTalus.bords_de_la_route(route, c, TrackBuilder.troncons(c.length, trous), 2.0)
	assert_eq(bords.size(), 4, "deux côtés, deux tronçons de part et d'autre du trou")
	var pire := 0.0
	var sommets := 0
	for bord in bords:
		sommets += bord.sommets.size()
		for k in bord.sommets.size():
			var attendu := TrackFeature.point(c, bord.distances[k], DEMI * bord.cote, 0.0)
			pire = maxf(pire, bord.sommets[k].distance_to(attendu))
	assert_gt(sommets, int(c.length / 2.0) * 2, "au moins les sections de base, des deux côtés")
	assert_lt(pire, 0.001, "un sommet à %.3f m du bord, à sa distance" % pire)
