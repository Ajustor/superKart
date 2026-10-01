extends GutTest

## Les mécaniques des coupes Fleur et Éclair : verglas, vent et tapis
## roulants, apesanteur, anneaux de turbo, obstacles mobiles et tunnels.

var track: Track
var karts: Array[Kart] = []
var session: RaceSession


func _anneau(rayon: float = 60.0, points: int = 16) -> Curve3D:
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


func _poser(element: TrackFeature, debut: float, longueur: float = 30.0) -> TrackFeature:
	element.debut = debut
	element.longueur = longueur
	track.add_child(element)
	return element


func _session_a_un_kart() -> Kart:
	session = RaceSession.new()
	session.duree_decompte = 0.0
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	karts.append(k)
	session.demarrer(track, karts)
	return k


func _rouler(moteur: KartMotor, braquage: float, secondes: float) -> void:
	var cmd := KartCommand.new()
	cmd.throttle = 1.0
	cmd.steer = braquage
	for i in int(secondes * 60.0):
		moteur.step(cmd, 1.0 / 60.0)


# --- Verglas ------------------------------------------------------------------------------

func test_sur_la_glace_le_nez_tourne_avant_la_trajectoire() -> void:
	var moteur := KartMotor.new(KartStats.new())
	moteur.speed = 20.0
	moteur.adherence = 0.3
	_rouler(moteur, 1.0, 0.4)
	assert_gt(moteur.heading - moteur.velocity_dir, 0.1, "le kart glisse : la trajectoire suit avec retard")


func test_sur_le_bitume_le_nez_et_la_trajectoire_restent_alignes() -> void:
	var moteur := KartMotor.new(KartStats.new())
	moteur.speed = 20.0
	_rouler(moteur, 1.0, 0.4)
	assert_almost_eq(moteur.heading, moteur.velocity_dir, 0.0001)


func test_en_quittant_la_glace_la_trajectoire_reprend_le_nez() -> void:
	var moteur := KartMotor.new(KartStats.new())
	moteur.speed = 20.0
	moteur.adherence = 0.3
	_rouler(moteur, 1.0, 0.4)
	var nez := moteur.heading
	moteur.adherence = 1.0
	_rouler(moteur, 0.0, 1.0 / 60.0)
	assert_almost_eq(moteur.velocity_dir, nez, 0.001)


func test_sur_la_glace_les_roues_patinent() -> void:
	var sec := KartMotor.new(KartStats.new())
	var glace := KartMotor.new(KartStats.new())
	glace.adherence = 0.3
	_rouler(sec, 0.0, 0.5)
	_rouler(glace, 0.0, 0.5)
	assert_lt(glace.speed, sec.speed * 0.85)


func test_la_remise_en_piste_rend_l_adherence() -> void:
	var moteur := KartMotor.new(KartStats.new())
	moteur.adherence = 0.2
	moteur.reset(0.0)
	assert_eq(moteur.adherence, 1.0)


# --- Vent, courant, tapis -----------------------------------------------------------------

func test_le_vent_pousse_vers_la_droite_de_la_course() -> void:
	var vent := _poser(TrackCourant.new(), 20.0) as TrackCourant
	vent.poussee_laterale = 6.0
	var c := track.track_curve
	var poussee := track.poussee_en(35.0, 0.0)
	assert_almost_eq(poussee.length(), 6.0, 0.01)
	var droite := c.right_at(35.0)
	assert_gt(poussee.normalized().dot(droite), 0.95, "vers la droite")
	assert_eq(poussee.y, 0.0, "à plat")
	assert_eq(track.poussee_en(80.0, 0.0), Vector3.ZERO, "hors de la zone, rien")


func test_un_tapis_roulant_pousse_dans_le_sens_de_la_course() -> void:
	var tapis := _poser(TrackCourant.new(), 20.0) as TrackCourant
	tapis.style = TrackCourant.Style.TAPIS
	tapis.poussee_laterale = 0.0
	tapis.poussee_avant = 5.0
	var poussee := track.poussee_en(35.0, 0.0)
	assert_gt(poussee.dot(track.track_curve.tangent_at(35.0)), 4.9)


func test_les_rafales_vont_et_viennent() -> void:
	var vent := TrackCourant.new()
	vent.periode = 4.0
	var forte := 0.0
	var faible := 1.0
	for i in 40:
		var f := vent.intensite(i * 0.1)
		forte = maxf(forte, f)
		faible = minf(faible, f)
	assert_eq(forte, 1.0)
	assert_eq(faible, 0.0)
	vent.periode = 0.0
	assert_eq(vent.intensite(1.7), 1.0, "sans période, un vent constant")
	vent.free()


# --- Apesanteur et anneaux ------------------------------------------------------------------

func test_l_apesanteur_reduit_la_gravite_dans_sa_zone() -> void:
	var zone := _poser(TrackApesanteur.new(), 50.0, 60.0) as TrackApesanteur
	zone.gravite = 0.4
	assert_eq(track.gravite_en(70.0, 0.0), 0.4)
	assert_eq(track.gravite_en(70.0, 15.0), 0.4, "un kart en l'air peut s'écarter un peu")
	assert_eq(track.gravite_en(130.0, 0.0), 1.0)


func test_on_traverse_l_anneau_par_son_centre() -> void:
	var anneau := _poser(TrackAnneau.new(), 40.0, 1.0) as TrackAnneau
	anneau.hauteur = 5.0
	anneau.rayon = 2.5
	assert_not_null(track.anneau_en(40.5, 0.0, 5.0))
	assert_not_null(track.anneau_en(40.0, 1.5, 4.0), "un peu décentré : dedans quand même")
	assert_null(track.anneau_en(40.0, 0.0, 0.3), "au sol, on passe dessous")
	assert_null(track.anneau_en(45.0, 0.0, 5.0), "trop loin le long du tracé")


# --- La session les applique ------------------------------------------------------------------

func test_la_session_dit_au_kart_ce_que_le_decor_lui_fait() -> void:
	var glace := _poser(TrackVerglas.new(), 40.0) as TrackVerglas
	glace.adherence = 0.25
	var vent := _poser(TrackCourant.new(), 40.0) as TrackCourant
	vent.poussee_laterale = -4.0
	var lune := _poser(TrackApesanteur.new(), 40.0) as TrackApesanteur
	lune.gravite = 0.3
	var k := _session_a_un_kart()
	var ici := TrackFeature.point(track.track_curve, 50.0, 0.0, 0.3)
	session.avancer(session.entries[0], ici, 1.0 / 60.0)
	assert_eq(k.motor.adherence, 0.25)
	assert_almost_eq(k.vent.length(), 4.0, 0.01)
	assert_eq(k.gravite_facteur, 0.3)
	var ailleurs := TrackFeature.point(track.track_curve, 150.0, 0.0, 0.3)
	session.avancer(session.entries[0], ailleurs, 1.0 / 60.0)
	assert_eq(k.motor.adherence, 1.0)
	assert_eq(k.vent, Vector3.ZERO)
	assert_eq(k.gravite_facteur, 1.0)


func test_traverser_un_anneau_donne_un_turbo() -> void:
	var anneau := _poser(TrackAnneau.new(), 50.0, 1.0) as TrackAnneau
	anneau.hauteur = 4.0
	var k := _session_a_un_kart()
	var dans := TrackFeature.point(track.track_curve, 50.0, 0.0, 4.0)
	session.avancer(session.entries[0], dans, 1.0 / 60.0)
	assert_gt(k.motor.boost_timer, 0.0)


func test_l_horloge_du_circuit_repart_au_feu_vert() -> void:
	track.horloge = 42.0
	session = RaceSession.new()
	session.duree_decompte = 1.0
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	karts.append(k)
	session.demarrer(track, karts)
	session.avancer_decompte(1.5)
	assert_eq(track.horloge, 0.0)


# --- Obstacles mobiles ------------------------------------------------------------------------

func test_le_marteau_balance_d_un_bord_a_l_autre() -> void:
	var marteau := _poser(TrackObstacle.new(), 60.0, 2.0) as TrackObstacle
	marteau.periode = 4.0
	marteau.amplitude = 50.0
	var milieu := marteau.pose_de_la_tete(0.0)
	assert_almost_eq(milieu.x, 0.0, 0.01, "au départ du cycle, à la verticale")
	assert_lt(milieu.y, 2.0, "au ras de la route")
	var droite := marteau.pose_de_la_tete(1.0)
	var gauche := marteau.pose_de_la_tete(3.0)
	assert_gt(droite.x, 5.0)
	assert_lt(gauche.x, -5.0)
	assert_true(marteau.touche(0.0, 0.5, 0.0), "un kart sous le marteau se fait prendre")
	assert_false(marteau.touche(-7.0, 0.5, 1.0), "de l'autre côté, on passe")


func test_le_pilon_ne_frappe_qu_une_fois_au_sol() -> void:
	var pilon := _poser(TrackObstacle.new(), 60.0, 2.0) as TrackObstacle
	pilon.type = TrackObstacle.Type.PISTON
	pilon.periode = 2.0
	assert_false(pilon.dangereux(0.0), "relevé : on passe dessous")
	assert_true(pilon.dangereux(2.0 * 0.7), "au sol : on se fait écraser")
	assert_false(pilon.dangereux(2.0 * 0.98), "remonté")


func test_le_tonneau_roule_en_travers() -> void:
	var tonneau := _poser(TrackObstacle.new(), 60.0, 2.0) as TrackObstacle
	tonneau.type = TrackObstacle.Type.TONNEAU
	tonneau.amplitude = 6.0
	tonneau.periode = 4.0
	assert_almost_eq(tonneau.pose_de_la_tete(1.0).x, 6.0, 0.01)
	assert_ne(tonneau.pose_de_la_tete(1.0).z, 0.0, "il tourne en roulant")
	assert_true(tonneau.dangereux(1.0), "toujours au sol")


func test_un_obstacle_suit_l_horloge() -> void:
	var a := _poser(TrackObstacle.new(), 60.0, 2.0) as TrackObstacle
	var b := _poser(TrackObstacle.new(), 90.0, 2.0) as TrackObstacle
	b.phase = 0.5
	assert_almost_eq(a.pose_de_la_tete(0.0).x, b.pose_de_la_tete(a.periode * 0.5).x, 0.01,
		"décalés d'une demi-période")


func test_l_obstacle_se_construit_avec_sa_zone() -> void:
	var marteau := _poser(TrackObstacle.new(), 60.0, 2.0) as TrackObstacle
	marteau.reconstruire()
	var zones := marteau.find_children("*", "Area3D", true, false)
	assert_eq(zones.size(), 1)
	assert_eq((zones[0] as Area3D).collision_mask, Kart.COUCHE_KARTS, "elle cherche les karts")


# --- Tunnels ------------------------------------------------------------------------------------

func test_le_tunnel_a_ses_deux_parois_comme_murs() -> void:
	var tunnel := _poser(TrackTunnel.new(), 100.0, 60.0) as TrackTunnel
	assert_eq(track.murs_en(130.0).size(), 2, "les carapaces rebondissent sur ses parois")
	assert_true(tunnel.sous_la_voute(130.0, track.track_curve.length))
	assert_false(tunnel.sous_la_voute(200.0, track.track_curve.length))


func test_la_voute_passe_au_dessus_des_karts_et_le_massif_au_dessus_de_la_voute() -> void:
	var tunnel := _poser(TrackTunnel.new(), 100.0, 60.0) as TrackTunnel
	var dedans := tunnel.coupe_interieure(track.track_curve)
	var dehors := tunnel.coupe_exterieure(track.track_curve)
	assert_eq(dedans.size(), dehors.size())
	var sommet := 0.0
	for p in dedans:
		sommet = maxf(sommet, p.y)
		if p.y < 4.0:
			assert_true(absf(p.x) >= track.half_width, "à hauteur de kart, la voûte ne mord pas sur la route")
	assert_gt(sommet, 5.0, "de la place pour sauter dessous")
	for i in dedans.size():
		assert_true(absf(dehors[i].x) >= absf(dedans[i].x) and dehors[i].y >= dedans[i].y,
			"le massif enveloppe la voûte")


func test_le_tunnel_se_construit() -> void:
	var tunnel := _poser(TrackTunnel.new(), 100.0, 60.0) as TrackTunnel
	tunnel.reconstruire()
	assert_eq(tunnel.find_children("*", "StaticBody3D", true, false).size(), 2, "deux parois solides")
	assert_eq(tunnel.find_children("*", "MultiMeshInstance3D", true, false).size(), 1, "les lampes")
