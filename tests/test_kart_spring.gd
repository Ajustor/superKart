extends GutTest

## L'amortisseur ne connaît ni la scène ni les roues : on lui donne une
## distance au sol, il rend une longueur. Tout se teste donc ici, sans rendu.

const DT := 1.0 / 60.0

var ressort: KartSpring


func before_each() -> void:
	# 25 cm de longueur au repos, 12 cm de débattement.
	ressort = KartSpring.new(0.25, 0.12, 260.0, 26.0)


func _rouler(distance: float, secondes: float) -> void:
	for i in int(secondes / DT):
		ressort.step(distance, DT)


func test_une_roue_pendante_reste_detendue() -> void:
	_rouler(INF, 1.0)
	assert_almost_eq(ressort.length, ressort.rest_length, 0.001,
		"sans sol, la roue pend au bout de son ressort")
	assert_almost_eq(ressort.compression(), 0.0, 0.001)
	assert_false(ressort.grounded)


func test_posee_sur_un_sol_a_sa_longueur_de_repos_elle_ne_bouge_pas() -> void:
	_rouler(0.25, 1.0)
	assert_almost_eq(ressort.length, 0.25, 0.005,
		"un sol pile à la longueur de repos ne demande aucun travail")


func test_un_sol_plus_haut_tasse_la_roue() -> void:
	_rouler(0.18, 1.0)
	assert_almost_eq(ressort.length, 0.18, 0.005,
		"la roue doit finir par épouser le sol")
	assert_gt(ressort.compression(), 0.5, "et se tasser nettement")


func test_la_roue_ne_remonte_pas_dans_le_chassis() -> void:
	_rouler(0.02, 1.0)
	assert_almost_eq(ressort.length, ressort.min_length(), 0.001,
		"la butée arrête la roue avant qu'elle n'entre dans la caisse")
	assert_almost_eq(ressort.compression(), 1.0, 0.001)


func test_le_tassement_va_de_zero_a_un() -> void:
	for d in [INF, 0.30, 0.25, 0.20, 0.13, 0.05, 0.0]:
		ressort.reset()
		_rouler(d, 1.0)
		assert_between(ressort.compression(), 0.0, 1.0,
			"tassement hors bornes pour un sol à %f" % d)


func test_l_amortisseur_finit_par_se_calmer() -> void:
	# Un choc franc, puis on laisse vivre : sans amortisseur, le kart
	# rebondirait sans fin, ce qui est le défaut qu'il existe pour éviter.
	ressort.step(0.10, DT)
	_rouler(0.25, 2.0)
	assert_almost_eq(ressort.velocity, 0.0, 0.01,
		"deux secondes suffisent à dissiper le choc")
	assert_almost_eq(ressort.length, 0.25, 0.005)


func test_sans_amortisseur_ca_ne_s_arrete_pas() -> void:
	# La preuve que le frottement sert à quelque chose. On oscille à l'intérieur
	# du débattement, loin des deux butées : elles absorbent de l'énergie, et
	# masqueraient donc l'absence d'amortisseur.
	var sans := KartSpring.new(0.25, 0.12, 260.0, 0.0)
	sans.length = 0.16
	for i in int(2.0 / DT):
		sans.step(0.19, DT)
	assert_gt(absf(sans.velocity), 0.05,
		"sans frottement, l'oscillation ne se dissipe pas")

	var avec := KartSpring.new(0.25, 0.12, 260.0, 26.0)
	avec.length = 0.16
	for i in int(2.0 / DT):
		avec.step(0.19, DT)
	assert_lt(absf(avec.velocity), 0.01,
		"avec frottement, le même mouvement s'éteint")


func test_la_butee_de_detente_ne_renvoie_pas_la_roue() -> void:
	# La roue pendante est en butée haute. Sans absorption à cet endroit, le
	# ressort y rebondirait et le kart sauterait tout seul en roulant.
	ressort.length = ressort.min_length()
	for i in int(1.0 / DT):
		ressort.step(INF, DT)
	assert_almost_eq(ressort.length, ressort.rest_length, 0.001)
	assert_almost_eq(ressort.velocity, 0.0, 0.001,
		"arrivée en butée de détente, la roue s'y arrête")


func test_un_ressort_plus_raide_se_tasse_moins_vite() -> void:
	var mou := KartSpring.new(0.25, 0.12, 80.0, 14.0)
	var dur := KartSpring.new(0.25, 0.12, 600.0, 40.0)
	for i in 6:
		mou.step(0.15, DT)
		dur.step(0.15, DT)
	assert_gt(mou.length, dur.length,
		"à raideur égale de sollicitation, le dur encaisse plus vite")


func test_la_detente_se_voit_quand_le_sol_se_derobe() -> void:
	_rouler(0.15, 1.0)
	var tasse := ressort.length
	# Le sol disparaît : on saute une bosse.
	_rouler(INF, 0.15)
	assert_gt(ressort.length, tasse,
		"la roue doit se détendre en quittant le sol, pas rester tassée")


func test_la_remise_a_neuf_efface_tout() -> void:
	_rouler(0.10, 0.5)
	ressort.reset()
	assert_almost_eq(ressort.length, ressort.rest_length, 0.001)
	assert_almost_eq(ressort.velocity, 0.0, 0.001)
	assert_false(ressort.grounded,
		"une roue qui garde sa vitesse fait tressauter la caisse à la remise en piste")


func test_le_debattement_nul_ne_divise_pas_par_zero() -> void:
	var fige := KartSpring.new(0.25, 0.0, 260.0, 26.0)
	fige.step(0.10, DT)
	assert_almost_eq(fige.compression(), 0.0, 0.001,
		"une suspension sans débattement ne se tasse pas, et ne plante pas")
