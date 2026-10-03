extends GutTest

## Les figures en l'air : un appui sur DRIFT pendant un vrai saut, un
## tonneau, et un turbo à l'atterrissage.

const PAS := 1.0 / 60.0

var kart: Kart


func before_each() -> void:
	kart = Kart.new()
	kart.stats = KartStats.new()
	kart.motor = KartMotor.new(kart.stats)
	kart.motor.speed = 20.0


func after_each() -> void:
	kart.free()


func _commande(derapage: bool) -> KartCommand:
	var c := KartCommand.new()
	c.drift = derapage
	return c


## `duree` secondes en l'air, DRIFT appuyé à partir de `appui_a`.
func _voler(duree: float, appui_a: float) -> void:
	kart.en_saut = true
	kart.au_sol = false
	var t := 0.0
	while t < duree:
		kart._figures(_commande(appui_a >= 0.0 and t >= appui_a), PAS)
		t += PAS


func test_un_appui_en_plein_saut_fait_une_figure() -> void:
	watch_signals(kart)
	_voler(0.5, 0.2)
	assert_true(kart.figure_faite)
	assert_signal_emit_count(kart, "figure", 1, "un seul tonneau par saut, même bouton tenu")
	kart.au_sol = true
	kart._atterrir()
	assert_gt(kart.motor.boost_timer, 0.0, "le turbo tombe à l'atterrissage")
	assert_false(kart.en_saut)


func test_sans_figure_pas_de_turbo() -> void:
	_voler(0.5, -1.0)
	kart._atterrir()
	assert_eq(kart.motor.boost_timer, 0.0)


func test_un_appui_au_decollage_n_est_pas_perdu() -> void:
	# Le joueur appuie en même temps que le kart quitte la rampe, et relâche.
	kart.en_saut = true
	kart.au_sol = false
	kart._figures(_commande(true), PAS)
	assert_false(kart.figure_faite, "juste après le décollage, pas encore")
	var t := PAS
	while t < Kart.FIGURE_APRES + 2.0 * PAS:
		kart._figures(_commande(false), PAS)
		t += PAS
	assert_true(kart.figure_faite, "l'appui attendait son moment : pas besoin d'un second")


func test_la_figure_part_tot_dans_le_saut() -> void:
	_voler(0.1, 0.0)
	assert_true(kart.figure_faite, "un dixième de seconde après le décollage, c'est fait")


func test_un_appui_attendu_ne_survit_pas_a_l_atterrissage() -> void:
	kart.en_saut = true
	kart.au_sol = false
	kart._figures(_commande(true), PAS)
	kart.au_sol = true
	kart._atterrir()
	_voler(0.3, -1.0)
	assert_false(kart.figure_faite, "un appui d'un saut ne sert pas au suivant")


func test_en_plein_vol_le_derapage_ne_relance_pas_le_kart() -> void:
	kart.en_saut = true
	kart.au_sol = false
	var c := _commande(true)
	kart._figures(c, PAS)
	assert_false(c.drift, "le bond de dérapage ferait un double saut")


func test_une_bosse_n_est_pas_un_saut() -> void:
	kart.en_saut = false
	kart.au_sol = false
	var c := _commande(true)
	kart._figures(c, PAS)
	kart._figures(_commande(true), 0.5)
	assert_false(kart.figure_faite)
	assert_true(c.drift, "hors saut, le dérapage passe comme d'habitude")


## La caisse faisait sa vrille au-dessus de quatre roues restées à plat.
func test_les_roues_font_le_tonneau_avec_la_caisse() -> void:
	var kart := (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate() as Kart
	add_child_autofree(kart)
	await wait_process_frames(2)
	var roues := kart.get_node("Wheels") as Node3D
	var caisse := kart.get_node("Body") as Node3D
	var visuels := kart.get_node("Visuals") as KartVisuals
	kart.figure.emit()
	visuels._update_lean(kart.motor, KartVisuals.DUREE_FIGURE * 0.25)
	var roulis_roues := roues.transform.basis.get_euler().z
	assert_ne(roulis_roues, 0.0, "les roues tournent pendant la figure")
	assert_almost_eq(wrapf(roulis_roues - caisse.rotation.z, -PI, PI), 0.0, 0.05,
		"du même angle que la caisse (hors dérapage)")
	# Le pivot est celui de la caisse : son centre ne se déplace pas.
	assert_almost_eq(roues.transform * caisse.position, caisse.position, Vector3.ONE * 0.001)
	visuels._update_lean(kart.motor, KartVisuals.DUREE_FIGURE)
	assert_eq(roues.transform, Transform3D.IDENTITY, "à plat une fois la figure finie")
