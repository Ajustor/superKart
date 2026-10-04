extends GutTest

## Murs, tremplins et zones hors-piste posés sur le tracé. Tout se vérifie
## dans le repère du circuit — distance le long de l'axe, écart latéral — sans
## arbre de scènes : la session et les objets reçoivent les positions en
## paramètre, comme partout ailleurs.

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


func _kart() -> Kart:
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	return k


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


func _poser(element: TrackFeature) -> TrackFeature:
	track.add_child(element)
	element.reconstruire()
	return element


func _session(combien: int = 1) -> void:
	session = RaceSession.new()
	session.duree_decompte = 0.0
	for i in combien:
		karts.append(_kart())
	session.demarrer(track, karts)


func _longueur() -> float:
	return track.track_curve.length


## Un point du circuit, à la hauteur d'un kart posé sur la route.
func _point(distance: float, lateral: float = 0.0) -> Vector3:
	return TrackFeature.point(track.track_curve, distance, lateral, 0.4)


# --- Repère du circuit ---------------------------------------------------------

func test_un_element_couvre_sa_portion_de_trace() -> void:
	var zone := TrackOffroad.new()
	zone.debut = 50.0
	zone.longueur = 20.0
	zone.decalage = 3.0
	zone.largeur = 4.0
	assert_true(zone.contient(60.0, 3.0, _longueur()))
	assert_true(zone.contient(60.0, 4.9, _longueur()), "jusqu'au bord de sa largeur")
	assert_false(zone.contient(60.0, 5.5, _longueur()), "mais pas au-delà")
	assert_false(zone.contient(45.0, 3.0, _longueur()), "ni avant son début")
	assert_false(zone.contient(75.0, 3.0, _longueur()), "ni après sa fin")
	zone.free()


func test_un_element_peut_chevaucher_la_ligne_d_arrivee() -> void:
	var zone := TrackOffroad.new()
	zone.debut = _longueur() - 5.0
	zone.longueur = 10.0
	assert_true(zone.couvre(_longueur() - 2.0, _longueur()))
	assert_true(zone.couvre(3.0, _longueur()), "il continue après la ligne")
	assert_false(zone.couvre(8.0, _longueur()))
	zone.free()


func test_les_murs_de_bord_longent_le_bitume() -> void:
	var mur := TrackWall.new()
	mur.marge = 0.0
	mur.epaisseur = 1.0
	mur.cote = TrackWall.Cote.GAUCHE
	assert_eq(mur.lignes(9.0), PackedFloat32Array([-9.5]))
	mur.cote = TrackWall.Cote.DROITE
	assert_eq(mur.lignes(9.0), PackedFloat32Array([9.5]))
	mur.cote = TrackWall.Cote.LES_DEUX
	assert_eq(mur.lignes(9.0).size(), 2)
	mur.cote = TrackWall.Cote.LIBRE
	mur.decalage = 2.0
	assert_eq(mur.lignes(9.0), PackedFloat32Array([2.0]), "un mur libre est là où on le met")
	mur.free()


# --- Construction ----------------------------------------------------------------

func test_un_mur_est_solide() -> void:
	var mur := _poser(TrackWall.new()) as TrackWall
	var corps := mur.find_children("*", "StaticBody3D", true, false)
	assert_eq(corps.size(), 2, "un corps par côté")


func test_un_tremplin_n_a_pas_de_collision() -> void:
	var saut := _poser(TrackJump.new())
	assert_eq(saut.find_children("*", "StaticBody3D", true, false).size(), 0,
		"on roule sur la route, le tremplin n'est qu'une zone peinte")
	assert_gt(saut.find_children("*", "MeshInstance3D", true, false).size(), 0)


func test_une_zone_hors_piste_porte_le_kart() -> void:
	var zone := _poser(TrackOffroad.new())
	assert_eq(zone.find_children("*", "StaticBody3D", true, false).size(), 1,
		"posée à côté de la route, elle doit avoir un sol")


func test_reconstruire_ne_cumule_pas_la_geometrie() -> void:
	var mur := _poser(TrackWall.new())
	mur.reconstruire()
	mur.reconstruire()
	assert_eq(mur.get_children().filter(func(n: Node) -> bool: return n.name == TrackFeature.NOM_GENERE).size(), 1)


func test_la_geometrie_suit_le_relief_du_trace() -> void:
	var zone := TrackOffroad.new()
	zone.debut = 30.0
	_poser(zone)
	var maillage: ArrayMesh = (zone.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var sommets: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for s in sommets:
		var d := track.track_curve.distance_of(s)
		assert_between(d, 29.0, 61.0, "chaque sommet est dans la portion de tracé couverte")


# --- Ce que le circuit sait de ses éléments --------------------------------------

func test_le_circuit_trouve_ses_elements() -> void:
	var saut := TrackJump.new()
	saut.debut = 40.0
	_poser(saut)
	var zone := TrackOffroad.new()
	zone.debut = 100.0
	zone.decalage = 15.0
	_poser(zone)
	var mur := TrackWall.new()
	mur.debut = 200.0
	_poser(mur)

	assert_eq(track.tremplin_en(42.0, 0.0), saut)
	assert_null(track.tremplin_en(80.0, 0.0))
	assert_true(track.en_zone_hors_piste(110.0, 15.0))
	assert_false(track.en_zone_hors_piste(110.0, 0.0))
	assert_true(track.sol_praticable(110.0, 15.0), "la zone crée du sol à côté de la route")
	assert_false(track.sol_praticable(150.0, 15.0), "là où il n'y a rien, rien")
	assert_true(track.sol_praticable(150.0, 5.0), "la route reste praticable")
	assert_eq(track.murs_en(210.0).size(), 2)
	assert_eq(track.murs_en(10.0).size(), 0)


# --- La course : sauts, hors-piste, remise en piste -------------------------------

func test_le_tremplin_fait_decoller_le_kart() -> void:
	var saut := TrackJump.new()
	saut.debut = 40.0
	saut.duree_turbo = 0.8
	_poser(saut)
	_session()
	karts[0].motor.speed = 20.0
	session.avancer(session.entries[0], _point(42.0), 1.0 / 60.0)
	assert_false(karts[0].au_sol, "le kart est en l'air")
	assert_true(session.entries[0].en_vol)
	assert_gt(karts[0].motor.boost_timer, 0.0, "et le tremplin donne son turbo")


func test_le_tremplin_ne_relance_pas_un_kart_deja_en_l_air() -> void:
	var saut := TrackJump.new()
	saut.debut = 40.0
	_poser(saut)
	assert_true(_kart_de_test().sauter(10.0))
	assert_false(karts[0].sauter(10.0), "une zone de quatre mètres ne fait pas quatre sauts")


func _kart_de_test() -> Kart:
	karts.append(_kart())
	return karts[0]


func test_en_vol_on_survole_le_vide_sans_etre_remis_en_piste() -> void:
	_session()
	session.entries[0].en_vol = true
	karts[0].au_sol = false
	karts[0].motor.speed = 20.0
	session.avancer(session.entries[0], _point(60.0, 25.0), 1.0 / 60.0)
	assert_eq(karts[0].motor.speed, 20.0, "au-dessus du décor, en plein saut : on laisse voler")


func test_atterrir_a_cote_remet_en_piste() -> void:
	_session()
	session.entries[0].en_vol = true
	karts[0].au_sol = true   # il vient de toucher le sol, loin de tout
	karts[0].motor.speed = 20.0
	session.avancer(session.entries[0], _point(60.0, 25.0), 1.0 / 60.0)
	assert_eq(karts[0].motor.speed, 0.0, "posé hors de tout sol praticable : remis en piste")


func test_sortir_sans_sauter_remet_toujours_en_piste() -> void:
	_session()
	karts[0].motor.speed = 20.0
	session.avancer(session.entries[0], _point(60.0, 25.0), 1.0 / 60.0)
	assert_eq(karts[0].motor.speed, 0.0, "le comportement d'avant les tremplins ne change pas")


func test_une_zone_a_cote_de_la_route_est_un_raccourci_praticable() -> void:
	var zone := TrackOffroad.new()
	zone.debut = 40.0
	zone.longueur = 40.0
	zone.decalage = 20.0
	zone.largeur = 22.0
	_poser(zone)
	_session()
	karts[0].motor.speed = 15.0
	session.avancer(session.entries[0], _point(60.0, 25.0), 1.0 / 60.0)
	assert_eq(karts[0].motor.speed, 15.0, "sur la zone, on n'est pas perdu")
	assert_true(karts[0].motor.on_offroad, "mais on roule au ralenti")


func test_une_zone_posee_sur_la_route_ralentit() -> void:
	var zone := TrackOffroad.new()
	zone.debut = 40.0
	zone.decalage = 0.0
	zone.largeur = 4.0
	_poser(zone)
	_session()
	session.avancer(session.entries[0], _point(60.0, 1.0), 1.0 / 60.0)
	assert_true(karts[0].motor.on_offroad, "une bande d'herbe au milieu du bitume reste de l'herbe")
	session.avancer(session.entries[0], _point(61.0, 6.0), 1.0 / 60.0)
	assert_false(karts[0].motor.on_offroad, "à côté de la bande, c'est la route")


# --- Le choc contre un mur -------------------------------------------------------

func test_un_mur_pris_de_face_arrete_le_kart() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = 20.0
	m.velocity_dir = 0.0          # plein nord, vers -Z
	m.heurter_mur(Vector3(0, 0, 1))  # le mur fait face au sud
	assert_lt(m.speed, 20.0 * 0.35, "de face, l'essentiel de la vitesse est perdu")


func test_un_mur_frole_ne_coute_presque_rien_et_devie() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = 20.0
	m.velocity_dir = deg_to_rad(10.0)  # presque parallèle à un mur à l'est
	m.heurter_mur(Vector3(-1, 0, 0))
	assert_gt(m.speed, 17.0, "un mur pris à 10° se frotte, il ne freine pas")
	assert_almost_eq(m.velocity_dir, 0.0, 0.001, "la trajectoire se couche le long du mur")


func test_s_eloigner_d_un_mur_ne_coute_rien() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = 20.0
	m.velocity_dir = PI
	m.heurter_mur(Vector3(0, 0, 1))
	assert_eq(m.speed, 20.0)


func test_un_mur_casse_la_glisse() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = 20.0
	m.state = KartMotor.State.DRIFT
	m.drift_dir = 1
	m.heurter_mur(Vector3(0, 0, 1))
	assert_eq(m.state, KartMotor.State.GRIP)


# --- Les carapaces et les murs ----------------------------------------------------

func test_une_carapace_rebondit_sur_un_mur_libre() -> void:
	var mur := TrackWall.new()
	mur.cote = TrackWall.Cote.LIBRE
	mur.decalage = 3.0
	mur.debut = 40.0
	mur.longueur = 60.0
	_poser(mur)
	_session()
	var objets := ItemManager.new()
	objets.preparer(session, PackedFloat32Array())
	var d := 70.0
	var c := objets.lancer_carapace(_point(d, -2.0), track.track_curve.right_at(d), null, null)
	var loin: Array[Vector3] = [_point(200.0, -6.0)]
	for i in 30:
		objets.avancer(loin, 1.0 / 60.0)
		assert_lt(track.track_curve.lateral_offset(c.position), 3.0,
			"image %d : la carapace ne traverse pas le mur" % i)
	objets.free()


# --- Placement à la souris ---------------------------------------------------------
# Le glisser-déposer lui-même n'existe que dans l'éditeur ; ce qui s'y décide
# — ce qu'un point d'arrivée de la poignée veut dire — se teste ici.

func test_deplacer_une_zone_la_recentre_sur_la_poignee() -> void:
	var zone := TrackOffroad.new()
	zone.longueur = 20.0
	zone._appliquer_deplacement(100.0, 12.3, _longueur())
	assert_almost_eq(zone.debut, 90.0, 0.001, "le milieu de la zone suit la poignée")
	assert_almost_eq(zone.decalage, 12.25, 0.001, "l'écart est arrondi au quart de mètre")
	zone.free()


func test_deplacer_un_mur_de_bord_choisit_son_cote() -> void:
	var mur := TrackWall.new()
	mur.cote = TrackWall.Cote.DROITE
	mur._appliquer_deplacement(100.0, -4.0, _longueur())
	assert_eq(mur.cote, TrackWall.Cote.GAUCHE, "glissé à gauche de l'axe, il passe au bord gauche")
	mur.cote = TrackWall.Cote.LIBRE
	mur._appliquer_deplacement(100.0, -4.0, _longueur())
	assert_almost_eq(mur.decalage, -4.0, 0.001, "un mur libre va là où on le lâche")
	mur.free()


# --- Le sol à côté de la route --------------------------------------------------------

func test_au_dela_du_bitume_le_sol_continue_a_plat() -> void:
	# Une route inclinée de 15° : prolonger son plan dresserait le bas-côté.
	var c := _anneau()
	for i in c.point_count:
		c.set_point_tilt(i, deg_to_rad(15.0))
	var penchee := TrackCurve.new(c, 9.0)
	var bord := TrackFeature.point(penchee, 40.0, 9.0, 0.0)
	var loin := TrackFeature.point(penchee, 40.0, 19.0, 0.0)
	assert_almost_eq(loin.y, bord.y, 0.001, "le bas-côté est à la hauteur du bord")
	assert_almost_eq(Vector2(loin.x - bord.x, loin.z - bord.z).length(), 10.0, 0.01,
		"et s'étend bien de dix mètres")


func test_un_element_qui_deborde_du_centre_du_virage_est_signale() -> void:
	# L'anneau fait 50 m de rayon : une zone qui s'étend à 55 m vers l'intérieur
	# se replie sur elle-même, la même vers l'extérieur ne pose aucun problème.
	var a := TrackOffroad.new()
	a.debut = 10.0
	a.decalage = 45.0
	a.largeur = 20.0
	track.add_child(a)
	var b := TrackOffroad.new()
	b.debut = 10.0
	b.decalage = -45.0
	b.largeur = 20.0
	track.add_child(b)
	var depassements := [a.depassement_du_centre(track.track_curve), b.depassement_du_centre(track.track_curve)]
	depassements.sort()
	assert_almost_eq(depassements[0], 0.0, 0.001, "côté extérieur, rien à signaler")
	assert_gt(depassements[1], 4.0, "côté intérieur, cinq mètres de trop")


# --- Trous ---------------------------------------------------------------------------

func _trou(debut: float, longueur: float) -> TrackGap:
	var trou := TrackGap.new()
	trou.debut = debut
	trou.longueur = longueur
	track.add_child(trou)
	return trou


func test_les_troncons_de_route_evitent_les_trous() -> void:
	var t := TrackBuilder.troncons(100.0, [Vector2(20, 30), Vector2(60, 65)] as Array[Vector2])
	assert_eq(t, [Vector2(0, 20), Vector2(30, 60), Vector2(65, 100)] as Array[Vector2])


func test_sans_trou_un_seul_troncon() -> void:
	assert_eq(TrackBuilder.troncons(100.0, [] as Array[Vector2]), [Vector2(0, 100)] as Array[Vector2])


func test_la_route_n_est_pas_construite_au_dessus_du_trou() -> void:
	_trou(100.0, 20.0)
	var maillage := TrackBuilder.build(track.track_curve, 2.0, track.trous())
	var sommets: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for s in sommets:
		var d := track.track_curve.distance_of(s)
		assert_false(d > 100.5 and d < 119.5, "un sommet de route au-dessus du vide, à %.1f m" % d)


func test_un_trou_sur_la_ligne_d_arrivee_se_coupe_en_deux() -> void:
	var trou := _trou(_longueur() - 5.0, 10.0)
	var p := trou.portions(_longueur())
	assert_eq(p.size(), 2)
	assert_almost_eq(p[1].y, 5.0, 0.001)


func test_au_dessus_du_trou_il_n_y_a_pas_de_sol() -> void:
	_trou(100.0, 20.0)
	assert_false(track.sol_praticable(110.0, 0.0), "la route n'existe plus ici")
	assert_true(track.sol_praticable(125.0, 0.0), "elle reprend après")


func test_tomber_dans_le_trou_remet_en_piste_apres() -> void:
	_trou(100.0, 20.0)
	assert_almost_eq(track.point_de_reprise(95.0), 124.0, 0.001,
		"reposé avant le trou, à l'arrêt, il retomberait sans fin")
	assert_almost_eq(track.point_de_reprise(110.0), 124.0, 0.001)
	assert_almost_eq(track.point_de_reprise(200.0), 200.0, 0.001, "loin du trou, rien ne change")


func test_la_session_ne_retient_pas_une_position_au_dessus_du_vide() -> void:
	_trou(100.0, 20.0)
	_session()
	session.avancer(session.entries[0], _point(90.0), 1.0 / 60.0)
	session.avancer(session.entries[0], _point(105.0), 1.0 / 60.0)
	assert_almost_eq(session.entries[0].derniere_en_piste, 90.0, 1.0,
		"la dernière position sûre est avant le trou, pas dedans")


func test_la_chute_dans_le_trou_repose_le_kart_apres() -> void:
	_trou(100.0, 20.0)
	_session()
	session.avancer(session.entries[0], _point(95.0), 1.0 / 60.0)
	var sous_le_vide := _point(108.0) + Vector3.DOWN * (RaceSession.FALL_DEPTH + 2.0)
	session.avancer(session.entries[0], sous_le_vide, 1.0 / 60.0)
	assert_almost_eq(session.entries[0].derniere_en_piste, 124.0, 0.5)


func test_un_trou_sans_elan_est_signale() -> void:
	var trou := _trou(100.0, 20.0)
	assert_false(trou.a_un_elan(track))
	var rampe := TrackRamp.new()
	rampe.debut = 85.0
	rampe.longueur = 12.0
	track.add_child(rampe)
	assert_true(trou.a_un_elan(track), "une rampe qui finit juste avant suffit")


# --- Rampes -------------------------------------------------------------------------

func test_la_rampe_monte_du_pied_au_sommet() -> void:
	var rampe := TrackRamp.new()
	rampe.hauteur = 2.0
	rampe.profil = TrackRamp.Profil.DROIT
	assert_almost_eq(rampe.hauteur_a(0.0), 0.0, 0.001)
	assert_almost_eq(rampe.hauteur_a(0.5), 1.0, 0.001)
	assert_almost_eq(rampe.hauteur_a(1.0), 2.0, 0.001)
	rampe.profil = TrackRamp.Profil.INCURVE
	assert_lt(rampe.hauteur_a(0.5), 1.0, "incurvée : douce au pied")
	rampe.free()


func test_la_rampe_incurvee_sort_plus_raide() -> void:
	var rampe := TrackRamp.new()
	rampe.hauteur = 2.0
	rampe.longueur = 10.0
	rampe.profil = TrackRamp.Profil.DROIT
	var droit := rampe.angle_de_sortie()
	rampe.profil = TrackRamp.Profil.INCURVE
	assert_gt(rampe.angle_de_sortie(), droit * 1.5)
	assert_almost_eq(rampe.vitesse_verticale(20.0), 20.0 * sin(deg_to_rad(rampe.angle_de_sortie())), 0.001)
	rampe.free()


func test_une_rampe_est_solide() -> void:
	var rampe := _poser(TrackRamp.new())
	assert_eq(rampe.find_children("*", "StaticBody3D", true, false).size(), 1)


func test_la_session_donne_son_elan_au_kart_sur_la_rampe() -> void:
	var rampe := TrackRamp.new()
	rampe.debut = 60.0
	rampe.longueur = 10.0
	_poser(rampe)
	_session()
	karts[0].motor.speed = 20.0
	session.avancer(session.entries[0], _point(65.0), 1.0 / 60.0)
	assert_almost_eq(karts[0].elan_de_rampe, rampe.vitesse_verticale(20.0), 0.001)
	session.avancer(session.entries[0], _point(71.5), 1.0 / 60.0)
	assert_gt(karts[0].elan_de_rampe, 0.0, "encore un peu après le sommet : c'est là qu'on le franchit")
	session.avancer(session.entries[0], _point(90.0), 1.0 / 60.0)
	assert_eq(karts[0].elan_de_rampe, 0.0, "et plus du tout ailleurs")


func test_un_decollage_de_rampe_met_le_kart_en_vol() -> void:
	_session()
	karts[0].vient_de_decoller = true
	karts[0].au_sol = false
	session.avancer(session.entries[0], _point(60.0), 1.0 / 60.0)
	assert_true(session.entries[0].en_vol)
	assert_false(karts[0].vient_de_decoller, "l'indicateur est consommé")


# --- Sol plat ------------------------------------------------------------------

func test_le_sol_plat_est_perce_au_dessus_d_une_route_qui_passe_dessous() -> void:
	var sol := TrackSol.new()
	sol.altitude = 3.0
	sol.marge = 40.0
	_poser(sol)
	var p := track.track_curve.position_at(10.0)
	assert_false(sol.a_du_sol(Vector2(p.x, p.z)), "la route passe 3 m dessous : percé")
	assert_true(sol.a_du_sol(Vector2(0.0, 0.0)), "au milieu de l'anneau : du sol")


func test_le_sol_plat_n_est_pas_perce_sous_la_route() -> void:
	var sol := TrackSol.new()
	sol.altitude = -0.4
	_poser(sol)
	var p := track.track_curve.position_at(10.0)
	assert_true(sol.a_du_sol(Vector2(p.x, p.z)))


func test_un_sol_de_portion_ne_couvre_que_sa_portion() -> void:
	var sol := TrackSol.new()
	sol.altitude = -0.4
	sol.portion = true
	sol.debut = 0.0
	sol.longueur = 40.0
	sol.marge = 20.0
	_poser(sol)
	var pres := track.track_curve.position_at(20.0) + track.track_curve.right_at(20.0) * 12.0
	var loin := track.track_curve.position_at(_longueur() * 0.5) + track.track_curve.right_at(_longueur() * 0.5) * 12.0
	assert_true(sol.a_du_sol(Vector2(pres.x, pres.z)))
	assert_false(sol.a_du_sol(Vector2(loin.x, loin.z)))


func test_un_decor_a_cote_de_la_route_se_pose_sur_le_sol_plat() -> void:
	var sol := TrackSol.new()
	sol.altitude = -2.0
	sol.marge = 60.0
	_poser(sol)
	var arbres := TrackDecor.new()
	arbres.objet = TrackDecor.Objet.SAPIN
	arbres.debut = 0.0
	arbres.longueur = 60.0
	arbres.decalage = 20.0
	arbres.espacement = 20.0
	_poser(arbres)
	for pose in arbres.placements(track.track_curve):
		assert_almost_eq(pose.origin.y, -2.0, 0.01, "posé sur le sol, pas à hauteur de route")
