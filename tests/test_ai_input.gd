extends GutTest

## L'IA ne touche jamais à l'arbre de scènes : la session lui donne sa position
## et sa distance, elle rend un KartCommand. Elle se teste donc comme
## KartMotor, en posant un kart quelque part et en lisant ce qu'elle décide.

var piste: TrackCurve
var kart: Kart
var ia: AIInput


## Un anneau parcouru dans le sens des lacets croissants.
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
	piste = TrackCurve.new(_anneau(), 9.0)
	kart = Kart.new()
	kart.stats = KartStats.new()
	kart.motor = KartMotor.new(kart.stats)
	ia = AIInput.new()
	ia.kart = kart
	ia.track = piste


func after_each() -> void:
	ia.free()
	kart.free()


## Pose l'IA à la distance donnée, sur la ligne de course, cap donné.
func _poser(distance: float, cap: float) -> void:
	ia.distance = distance
	ia.position = piste.racing_line_at(distance)
	kart.motor.heading = cap
	kart.motor.velocity_dir = cap
	kart.motor.speed = 15.0


func test_elle_met_les_gaz() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_almost_eq(cmd.throttle, 1.0, 0.001,
		"la difficulté ne se règle pas en bridant la vitesse")
	assert_almost_eq(cmd.brake, 0.0, 0.001)


func test_dans_l_axe_elle_ne_braque_presque_pas() -> void:
	# Sur un anneau, viser devant soi demande toujours un peu de braquage :
	# on tolère un quart de butée, pas plus.
	_poser(0.0, piste.yaw_at(0.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_lt(absf(cmd.steer), 0.25,
		"dans l'axe d'un virage large, elle ne doit pas tirer à fond")


func test_desaxee_vers_la_gauche_elle_braque_a_droite() -> void:
	# Cap tourné de 30° vers la gauche : la cible est à droite du kart, donc
	# le braquage doit être positif (convention boussole).
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(30.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_gt(cmd.steer, 0.5, "un écart de 30° doit produire un braquage franc à droite")


func test_desaxee_vers_la_droite_elle_braque_a_gauche() -> void:
	_poser(0.0, piste.yaw_at(0.0) + deg_to_rad(30.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_lt(cmd.steer, -0.5, "et symétriquement à gauche")


func test_le_braquage_est_borne() -> void:
	_poser(0.0, piste.yaw_at(0.0) + deg_to_rad(170.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_between(cmd.steer, -1.0, 1.0,
		"même à contresens, la commande reste dans les bornes du joueur")


func test_elle_vise_plus_loin_quand_elle_va_vite() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	kart.motor.speed = 5.0
	var court := ia.point_vise()
	kart.motor.speed = 20.0
	var loin := ia.point_vise()
	var d_court := piste.distance_of(court)
	var d_loin := piste.distance_of(loin)
	assert_gt(d_loin, d_court,
		"viser à durée constante veut dire viser plus loin quand on va plus vite")


func test_a_l_arret_elle_vise_quand_meme_devant() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	kart.motor.speed = 0.0
	var vise := ia.point_vise()
	var d := piste.distance_of(vise)
	assert_gt(d, 1.0,
		"sans plancher, un kart à l'arrêt viserait ses propres roues et ne partirait jamais")


func test_elle_ne_derape_pas_en_ligne_droite() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_false(cmd.drift, "déraper tout droit ne charge rien et ralentit")


func test_elle_declenche_la_glisse_sur_un_gros_ecart() -> void:
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_true(cmd.drift, "un virage franc se prend en dérapage")


func test_elle_ne_derape_pas_trop_lentement() -> void:
	# En dessous de min_drift_speed le moteur refuse la glisse : insister ne
	# ferait que garder la gâchette enfoncée pour rien.
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	kart.motor.speed = kart.stats.min_drift_speed - 1.0
	var cmd := ia.poll(1.0 / 60.0)
	assert_false(cmd.drift, "trop lente pour glisser, elle n'essaie pas")


func test_elle_tient_la_glisse_jusqu_au_palier_vise() -> void:
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	ia.drift_release_tier = 2
	kart.motor.state = KartMotor.State.DRIFT
	kart.motor.drift_dir = 1
	# Charge correspondant au palier 1 : elle en veut un de plus.
	kart.motor.drift_charge = kart.stats.drift_tiers[0]
	assert_eq(kart.motor.tier_for_charge(kart.motor.drift_charge), 1,
		"prémisse du test : on est bien au palier 1")

	var cmd := ia.poll(1.0 / 60.0)
	assert_true(cmd.drift, "elle ne lâche pas un palier trop tôt")


func test_elle_lache_la_glisse_au_palier_vise() -> void:
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	ia.drift_release_tier = 2
	kart.motor.state = KartMotor.State.DRIFT
	kart.motor.drift_dir = 1
	kart.motor.drift_charge = kart.stats.drift_tiers[1]
	assert_eq(kart.motor.tier_for_charge(kart.motor.drift_charge), 2,
		"prémisse du test : on est bien au palier 2")

	var cmd := ia.poll(1.0 / 60.0)
	assert_false(cmd.drift, "palier atteint, elle encaisse son turbo")


func test_elle_lache_la_glisse_quand_la_route_se_redresse() -> void:
	# Cap redevenu aligné : garder la glisse ferait sortir le kart de la piste.
	_poser(0.0, piste.yaw_at(0.0))
	ia.drift_release_tier = 3
	kart.motor.state = KartMotor.State.DRIFT
	kart.motor.drift_dir = 1
	kart.motor.drift_charge = 0.1

	var cmd := ia.poll(1.0 / 60.0)
	assert_false(cmd.drift,
		"une glisse qu'on tient en ligne droite finit dans le décor")


func test_le_decalage_lateral_deplace_la_mire() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	var propre := ia.point_vise()
	ia.lateral_bias = 4.0
	var decale := ia.point_vise()

	var d := piste.distance_of(propre)
	var vers := decale - propre
	vers.y = 0.0
	assert_almost_eq(vers.dot(piste.right_at(d)), 4.0, 0.3,
		"un biais positif vise quatre mètres à droite de la ligne idéale")


func test_le_decalage_lateral_ne_change_pas_la_distance_de_mire() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	var avant := piste.distance_of(ia.point_vise())
	ia.lateral_bias = 4.0
	var apres := piste.distance_of(ia.point_vise())
	assert_almost_eq(apres, avant, 1.0,
		"se décaler sur le côté ne veut pas dire viser plus loin")


func test_sans_delai_elle_decide_a_chaque_image() -> void:
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	var premier := ia.poll(1.0 / 60.0).steer
	# Le kart se réaligne d'un coup : sans délai, la commande suit tout de suite.
	kart.motor.heading = piste.yaw_at(0.0)
	var second := ia.poll(1.0 / 60.0).steer
	assert_lt(absf(second), absf(premier) - 0.2,
		"sans délai de réaction, elle corrige dans l'image")


func test_le_delai_de_reaction_fige_la_commande() -> void:
	ia.reaction_delay = 0.25
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	var premier := ia.poll(1.0 / 60.0).steer

	kart.motor.heading = piste.yaw_at(0.0)
	var tout_de_suite := ia.poll(1.0 / 60.0).steer
	assert_almost_eq(tout_de_suite, premier, 0.0001,
		"une IA lente braque en retard, elle ne braque pas mollement")

	# Après le délai, elle finit par voir.
	for i in 20:
		ia.poll(1.0 / 60.0)
	var plus_tard := ia.poll(1.0 / 60.0).steer
	assert_lt(absf(plus_tard), absf(premier) - 0.2,
		"le retard finit par se rattraper")
