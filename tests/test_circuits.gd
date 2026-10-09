extends GutTest

## Les circuits du catalogue, et ce qui les habille : route arc-en-ciel,
## bordures, décor, étendue de lave ou d'eau. Chaque circuit publié est
## vérifié ici — roulable, sautable, sans deux portions assez proches pour
## que le classement se trompe de tronçon.

var track: Track
var karts: Array[Kart] = []
var session: RaceSession


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
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)


func after_each() -> void:
	if session != null:
		session.free()
		session = null
	for k in karts:
		k.free()
	karts.clear()
	track.free()
	track = null


# --- Habillage de la route -----------------------------------------------------------

func test_la_route_arc_en_ciel_a_une_bande_par_couleur() -> void:
	var uni := TrackBuilder.build(track.track_curve, 5.0)
	var couleurs := TrackBuilder.build(track.track_curve, 5.0, [], Track.ARC_EN_CIEL)
	var sommets_uni: PackedVector3Array = uni.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tableaux := couleurs.surface_get_arrays(0)
	var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	assert_eq(sommets.size(), sommets_uni.size() * Track.ARC_EN_CIEL.size(), "sept bandes, sept fois plus de triangles")
	var teintes: PackedColorArray = tableaux[Mesh.ARRAY_COLOR]
	assert_eq(teintes.size(), sommets.size(), "chaque sommet porte sa couleur")
	# La bande de gauche d'abord, celle de droite en dernier. Les couleurs de
	# sommet sont rangées sur huit bits : à peu près égales, pas exactement.
	var premiere := teintes[0]
	var derniere := teintes[teintes.size() - 1]
	for i in 3:
		assert_almost_eq(premiere[i], Track.ARC_EN_CIEL[0][i], 0.01)
		assert_almost_eq(derniere[i], Track.ARC_EN_CIEL[6][i], 0.01)


func test_les_bordures_longent_les_deux_rives_et_evitent_les_trous() -> void:
	var trous: Array[Vector2] = [Vector2(100.0, 130.0)]
	var bandes := TrackBuilder.bordures(track.track_curve, trous, 1.0, 3.0, Color.RED, Color.WHITE)
	var sommets: PackedVector3Array = bandes.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(sommets.size(), 0)
	var gauche := 0
	var droite := 0
	for s in sommets:
		var ecart := track.track_curve.lateral_offset(s)
		assert_between(absf(ecart), 7.9, 9.1, "sur le bord du bitume")
		if ecart < 0.0:
			gauche += 1
		else:
			droite += 1
		var d := track.track_curve.distance_of(s)
		assert_false(d > 100.5 and d < 129.5, "pas de bordure au-dessus du vide")
	assert_eq(gauche, droite, "les deux rives")


# --- Décor -------------------------------------------------------------------------------

func _decor(debut: float, longueur: float, espacement: float, symetrique: bool = true) -> TrackDecor:
	var decor := TrackDecor.new()
	decor.debut = debut
	decor.longueur = longueur
	decor.espacement = espacement
	decor.symetrique = symetrique
	decor.decalage = 15.0
	track.add_child(decor)
	return decor


func test_le_decor_pose_une_rangee_de_chaque_cote() -> void:
	var decor := _decor(0.0, 100.0, 20.0)
	var poses := decor.placements(track.track_curve)
	assert_eq(poses.size(), 12, "six par rive : aux deux bouts et tous les vingt mètres")
	for t in poses:
		var ecart := absf(track.track_curve.lateral_offset(t.origin))
		assert_between(ecart, 13.0, 17.0, "à côté de la route, jamais dessus")


func test_un_espacement_nul_pose_un_objet_seul_au_milieu() -> void:
	var decor := _decor(40.0, 20.0, 0.0, false)
	var poses := decor.placements(track.track_curve)
	assert_eq(poses.size(), 1)
	assert_almost_eq(track.track_curve.distance_of(poses[0].origin), 50.0, 0.5)


func test_le_decor_se_touche() -> void:
	var decor := _decor(0.0, 100.0, 20.0)
	decor.reconstruire()
	var corps := decor.find_children("*", "StaticBody3D", true, false)
	assert_eq(corps.size(), 1, "un seul corps pour toute la rangée")
	var formes := corps[0].find_children("*", "CollisionShape3D", true, false)
	assert_eq(formes.size(), decor.placements(track.track_curve).size(), "une forme par palmier")
	assert_eq((corps[0] as StaticBody3D).collision_layer, Kart.COUCHE_DECOR,
		"sur la couche que les karts heurtent")
	assert_eq(decor.find_children("*", "MultiMeshInstance3D", true, false).size(), 1,
		"toute la rangée en un seul appel de dessin")


func test_la_forme_suit_l_objet_et_sa_taille() -> void:
	var decor := _decor(40.0, 20.0, 0.0, false)
	decor.objet = TrackDecor.Objet.MOULIN
	decor.echelle = 2.0
	decor.reconstruire()
	var pose := decor.placements(track.track_curve)[0]
	var forme := decor.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
	# Un prisme tiré du modèle à hauteur de kart (TrackDecor.prismes_de),
	# monté jusqu'au sommet du gabarit (9 m pour le moulin).
	var prisme := forme.shape as ConvexPolygonShape3D
	assert_not_null(prisme)
	var a_l_unite: Dictionary = TrackDecor.prismes_de(TrackDecor.Objet.MOULIN)[0]
	var bas := INF
	var haut := -INF
	var large := 0.0
	for p in prisme.points:
		bas = minf(bas, p.y)
		haut = maxf(haut, p.y)
		large = maxf(large, Vector2(p.x, p.z).length())
	var large_a_l_unite := 0.0
	for p: Vector2 in a_l_unite.contour:
		large_a_l_unite = maxf(large_a_l_unite, p.length())
	assert_almost_eq(large, large_a_l_unite * 2.0, 0.01, "l'emprise suit l'échelle")
	assert_almost_eq(bas, 0.0, 0.01, "posée sur le sol, pas enfoncée")
	assert_almost_eq(haut, 9.0 * 2.0, 0.01, "jusqu'au sommet, à l'échelle")
	assert_almost_eq(forme.transform.origin, pose.origin, Vector3.ONE * 0.01)
	assert_almost_eq(forme.transform.basis.get_scale().x, 1.0, 0.001,
		"la forme n'est pas mise à l'échelle : ses dimensions le sont")


func test_ce_qui_flotte_ne_se_touche_pas() -> void:
	var decor := _decor(0.0, 100.0, 20.0)
	decor.objet = TrackDecor.Objet.ETOILE
	decor.reconstruire()
	assert_eq(decor.find_children("*", "CollisionObject3D", true, false).size(), 0)


func test_un_decor_non_solide_se_traverse() -> void:
	var decor := _decor(0.0, 100.0, 20.0)
	decor.solide = false
	decor.reconstruire()
	assert_eq(decor.find_children("*", "CollisionObject3D", true, false).size(), 0)


## Un décor solide ne doit jamais mordre sur la route : un tronc au bord du
## bitume arrêterait net un kart qui ne fait que prendre la corde.
func test_aucun_decor_solide_ne_mord_sur_la_route() -> void:
	for info in TrackCatalog.PISTES + TrackCatalog.ARENES:
		var piste := info.scene.instantiate() as Track
		add_child_autofree(piste)
		var c := piste.track_curve
		for e in piste.elements():
			if not (e is TrackDecor) or not e.solide:
				continue
			var g := TrackDecor.forme_de(e.objet)
			if g.is_empty():
				continue
			# Les formes réelles : les prismes tirés du modèle, ou le gabarit
			# pour ce qui n'a rien à hauteur de kart. Chacune : son centre (dans
			# le repère de l'objet), le rayon qui dépasse le plus quelle que
			# soit l'orientation, son bas et son haut.
			var formes := []
			for prisme: Dictionary in TrackDecor.prismes_de(e.objet):
				var rayon_prisme := 0.0
				for p: Vector2 in prisme.contour:
					rayon_prisme = maxf(rayon_prisme, p.length())
				formes.append([Vector3.ZERO, rayon_prisme, prisme.bas, prisme.haut])
			if formes.is_empty():
				var hauteur: float = g.hauteur if g.type == "cylindre" else g.taille.y
				var rayon: float = g.rayon if g.type == "cylindre" else Vector2(g.taille.x, g.taille.z).length() * 0.5
				formes.append([g.centre, rayon, g.centre.y - hauteur * 0.5, g.centre.y + hauteur * 0.5])
			for pose: Transform3D in e.placements(c):
				var t := pose.basis.get_scale().x
				for f: Array in formes:
					var centre: Vector3 = pose.origin + pose.basis.orthonormalized() * ((f[0] as Vector3) * t)
					var d := c.distance_of(centre)
					var route := c.position_at(d)
					# Au-dessus des karts, ou sous la route (un autre étage) :
					# sans conséquence.
					if pose.origin.y + f[2] * t > route.y + 2.5 or pose.origin.y + f[3] * t < route.y - 0.5:
						continue
					var marge := absf(c.lateral_offset_at(centre, d)) - f[1] * t - c.half_width
					assert_gt(marge, 0.0, "%s, %s à %.0f m : mord de %.2f m sur la route" % [info.id, e.name, d, -marge])


func test_chaque_objet_qui_se_touche_a_une_forme_de_collision() -> void:
	for objet in TrackDecor.Objet.values():
		var forme := TrackDecor.forme_de(objet)
		if TrackDecor.flotte(objet):
			assert_true(forme.is_empty(), "ce qui flotte se traverse")
		else:
			assert_false(forme.is_empty(), "objet %s" % TrackDecor.Objet.keys()[objet])


func test_chaque_objet_de_decor_a_une_forme() -> void:
	for objet in TrackDecor.Objet.values():
		var maillage := TrackDecor.maillage_de(objet)
		assert_gt(maillage.get_surface_count(), 0, "objet %d" % objet)


# --- Lave et eau ---------------------------------------------------------------------------

func test_passer_sous_le_liquide_remet_en_piste_sans_attendre_la_chute() -> void:
	track.altitude_du_liquide = -2.0
	session = RaceSession.new()
	session.duree_decompte = 0.0
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	karts.append(k)
	session.demarrer(track, karts)
	k.motor.speed = 20.0
	var dans_la_lave := TrackFeature.point(track.track_curve, 60.0, 0.0, -3.0)
	assert_lt(-3.0, RaceSession.FALL_DEPTH, "bien moins bas qu'une vraie chute")
	session.avancer(session.entries[0], dans_la_lave, 1.0 / 60.0)
	assert_eq(k.motor.speed, 0.0, "remis en piste dès qu'il touche la lave")


# --- Le catalogue -----------------------------------------------------------------------

func _monter(info: TrackInfo) -> Track:
	var piste: Track = info.scene.instantiate()
	add_child_autofree(piste)
	return piste


func test_chaque_circuit_est_roulable() -> void:
	for info in TrackCatalog.PISTES:
		var piste := _monter(info)
		var serres := piste.track_curve.tight_spots(piste.min_drivable_radius, piste.segment_length) \
			.filter(func(s: Array) -> bool: return not piste.hors_course(s[0]) and not _plonge(piste, s[0]))
		assert_eq(serres.size(), 0, "%s : aucun virage plus serré que le braquage du kart" % info.id)


func test_chaque_trou_a_de_quoi_sauter() -> void:
	for info in TrackCatalog.PISTES:
		var piste := _monter(info)
		for element in piste.elements():
			if element is TrackGap and not element.chute_voulue:
				assert_true(element.a_un_elan(piste), "%s : %s a une rampe juste avant" % [info.id, element.name])


func test_la_grille_et_les_objets_sont_sur_la_route() -> void:
	for info in TrackCatalog.PISTES:
		var piste := _monter(info)
		var longueur := piste.track_curve.length
		# La grille de huit karts s'étend sur une trentaine de mètres avant la ligne.
		var d := -35.0
		while d <= 0.0:
			assert_null(piste.trou_en(wrapf(d, 0.0, longueur)), "%s : grille au-dessus du vide à %.0f m" % [info.id, d])
			d += 1.0
		for rangee in piste.rangees_objets:
			assert_null(piste.trou_en(rangee * longueur), "%s : boîtes au-dessus du vide" % info.id)


func test_le_liquide_reste_sous_la_route() -> void:
	for info in TrackCatalog.PISTES:
		var piste := _monter(info)
		var c := piste.track_curve
		var plus_bas := INF
		var d := 0.0
		while d < c.length:
			plus_bas = minf(plus_bas, c.position_at(d).y)
			d += 5.0
		assert_lt(piste.altitude_du_liquide, plus_bas - 1.0,
			"%s : la lave ou l'eau ne doit pas noyer la route" % info.id)


## Un sol plat posé à la main traversait les galeries de la Grotte Glacée à
## mi-hauteur : on roulait sous un second sol, sans collision. Aucun plan ne
## doit passer au-dessus de la route à hauteur de kart, et un TrackSol doit
## être percé partout où la route passe dessous.
func test_aucun_sol_ne_passe_au_dessus_de_la_route() -> void:
	for info in TrackCatalog.PISTES + TrackCatalog.ARENES:
		var piste := _monter(info)
		var c := piste.track_curve
		var sols: Array[TrackSol] = []
		for e in piste.elements():
			if e is TrackSol:
				sols.append(e)
		var d := 0.0
		while d < c.length:
			var p := c.position_at(d)
			if piste.trou_en(d) == null:
				for n in piste.get_children():
					if n is MeshInstance3D and n.mesh is PlaneMesh:
						var loc: Vector3 = n.transform.affine_inverse() * p
						var taille: Vector2 = n.mesh.size
						var ecart: float = n.transform.origin.y - p.y
						if absf(loc.x) < taille.x * 0.5 and absf(loc.z) < taille.y * 0.5:
							assert_false(ecart > 0.05 and ecart < 9.0,
								"%s : %s passe %.1f m au-dessus de la route à %.0f m" % [info.id, n.name, ecart, d])
				for sol in sols:
					if sol.altitude - p.y > 0.05 and sol.altitude - p.y < 9.0:
						assert_false(sol.a_du_sol(Vector2(p.x, p.z)),
							"%s : %s n'est pas percé au-dessus de la route à %.0f m" % [info.id, sol.name, d])
			d += 8.0


## Le classement cherche le point du tracé le plus proche du kart. Deux
## portions éloignées le long du tracé mais proches dans l'espace — un pont
## trop bas, deux lignes droites côte à côte — le feraient sauter de l'une à
## l'autre : un kart gagnerait ou perdrait un demi-tour d'un coup.
func test_deux_portions_du_trace_ne_se_confondent_pas() -> void:
	for info in TrackCatalog.PISTES:
		var piste := _monter(info)
		var c := piste.track_curve
		var pire := INF
		var d := 0.0
		while d < c.length:
			var p := c.position_at(d)
			var e := 0.0
			while e < c.length:
				# La boucle qu'on ne court pas, après l'arrivée d'une course
				# linéaire, n'a pas de route : rien à confondre... sauf si elle
				# frôle une portion courue, où un kart s'y projetterait.
				var hors := piste.hors_course(d) and piste.hors_course(e)
				if not hors and absf(wrapf(e - d, -c.length * 0.5, c.length * 0.5)) > 80.0:
					pire = minf(pire, p.distance_to(c.position_at(e)))
				e += 5.0
			d += 5.0
		assert_gt(pire, piste.half_width * 2.0, "%s : %.1f m entre deux portions" % [info.id, pire])


## Dans un trou où l'on tombe exprès (un portail à plat), le tracé plonge à
## pic : aucune route, rien à braquer.
func _plonge(piste: Track, d: float) -> bool:
	var trou := piste.trou_en(wrapf(d, 0.0, piste.track_curve.length))
	return trou != null and trou.chute_voulue
