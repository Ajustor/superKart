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
