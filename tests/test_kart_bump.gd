extends GutTest

## Les chocs entre karts, à plat et sans moteur physique : positions et
## moteurs suffisent.

var a_liberer: Array[Object] = []


func after_each() -> void:
	for o in a_liberer:
		o.free()
	a_liberer.clear()


func _moteur(vitesse: float, cap_deg: float = 0.0) -> KartMotor:
	var m := KartMotor.new(KartStats.new())
	m.speed = vitesse
	m.velocity_dir = deg_to_rad(cap_deg)
	m.heading = m.velocity_dir
	return m


func _kart(ou: Vector3, vitesse: float, cap_deg: float = 0.0) -> Kart:
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = _moteur(vitesse, cap_deg)
	k.motor.stats = k.stats
	k.position = ou
	a_liberer.append(k)
	return k


func test_loin_l_un_de_l_autre_rien_ne_se_passe() -> void:
	assert_eq(KartBump.contact(Vector3.ZERO, Vector3(3, 0, 0)), Vector3.ZERO)


func test_l_un_au_dessus_de_l_autre_ne_se_touchent_pas() -> void:
	assert_eq(KartBump.contact(Vector3(0, 2, 0), Vector3(0.5, 0, 0)), Vector3.ZERO,
		"un kart qui saute par-dessus un autre passe")


func test_le_contact_pousse_hors_du_chevauchement() -> void:
	var choc := KartBump.contact(Vector3(1.0, 0, 0), Vector3.ZERO)
	assert_almost_eq(choc.x, KartBump.RAYON * 2.0 - 1.0, 0.001, "on s'écarte de ce qui chevauche")
	assert_gt(choc.x, 0.0, "dans la direction qui éloigne de l'autre")


func test_deux_karts_superposes_s_ecartent_quand_meme() -> void:
	assert_ne(KartBump.contact(Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)


func test_pousser_par_l_arriere_ralentit_le_pousseur_et_lance_le_pousse() -> void:
	# Tous deux vers le nord (-Z) ; le pousseur, derrière, va plus vite.
	var devant := _kart(Vector3(0, 0, -1.0), 15.0)
	var derriere := _kart(Vector3(0, 0, 0), 22.0)
	KartCollisions.resoudre([devant, derriere] as Array[Kart])
	assert_lt(derriere.motor.speed, 22.0, "on ralentit en poussant")
	assert_gt(devant.motor.speed, 15.0, "on accélère en étant poussé")
	assert_gt(derriere.motor.speed, 10.0, "mais on ne s'arrête pas net comme contre un mur")
	assert_almost_eq(derriere.motor.velocity_dir, 0.0, 0.01, "un choc dans l'axe ne dévie pas")


func test_un_coup_d_epaule_devie_sans_retourner() -> void:
	# Côte à côte vers le nord ; celui de gauche se rabat vers la droite.
	var gauche := _kart(Vector3(-1.0, 0, 0), 20.0, 20.0)
	var droite := _kart(Vector3(0.0, 0, 0), 20.0, 0.0)
	KartCollisions.resoudre([gauche, droite] as Array[Kart])
	assert_gt(droite.motor.velocity_dir, 0.0, "celui qui est tassé part vers la droite")
	assert_lt(gauche.motor.velocity_dir, deg_to_rad(20.0), "celui qui tasse est redressé")
	assert_lt(absf(droite.motor.velocity_dir), 0.61, "sans jamais faire demi-tour")


func test_les_karts_s_ecartent() -> void:
	# Côte à côte, tous deux vers le nord : ils se touchent par le flanc.
	var a := _kart(Vector3(0, 0, 0), 10.0)
	var b := _kart(Vector3(0.6, 0, 0), 10.0)
	KartCollisions.resoudre([a, b] as Array[Kart])
	assert_almost_eq(a.position.distance_to(b.position), KartBump.DEMI_LARGEUR * 2.0, 0.01,
		"plus de chevauchement après le choc")


func test_de_face_on_se_touche_plus_tot_que_de_cote() -> void:
	# Même écart de 1,4 m : de côté, les caisses (1,1 m) ne se touchent pas ;
	# l'une derrière l'autre (1,7 m), si.
	assert_eq(KartBump.contact(Vector3(1.4, 0, 0), Vector3.ZERO, 0.0, 0.0), Vector3.ZERO)
	assert_ne(KartBump.contact(Vector3(0, 0, 1.4), Vector3.ZERO, 0.0, 0.0), Vector3.ZERO)


func test_un_kart_distant_n_est_pas_deplace_ici() -> void:
	var ici := _kart(Vector3(0, 0, 0), 10.0)
	var distant := _kart(Vector3(0.6, 0, 0), 10.0)
	distant.simule = false
	KartCollisions.resoudre([ici, distant] as Array[Kart])
	assert_eq(distant.position, Vector3(0.6, 0, 0), "c'est sa machine qui le déplace")
	assert_almost_eq(ici.position.distance_to(distant.position), KartBump.DEMI_LARGEUR * 2.0, 0.01,
		"celui d'ici fait tout le chemin")


func test_s_eloigner_ne_freine_pas() -> void:
	# Au contact, mais déjà en train de s'écarter : rien à échanger.
	var a := _kart(Vector3(-0.5, 0, 0), 10.0, -90.0)
	var b := _kart(Vector3(0.5, 0, 0), 10.0, 90.0)
	KartCollisions.resoudre([a, b] as Array[Kart])
	assert_almost_eq(a.motor.speed, 10.0, 0.001)
	assert_almost_eq(b.motor.speed, 10.0, 0.001)
