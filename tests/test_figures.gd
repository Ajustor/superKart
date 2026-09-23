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


func test_un_appui_trop_tot_ne_compte_pas() -> void:
	_voler(Kart.FIGURE_APRES * 0.5, 0.0)
	assert_false(kart.figure_faite, "juste après le décollage, pas encore")


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
