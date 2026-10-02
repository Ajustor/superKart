extends GutTest

## Ce qui fait passer l'IA pour un joueur : elle choisit sa ligne au lieu de
## coller à la trajectoire idéale, double par le côté libre, ferme la porte,
## va chercher les boîtes, se trompe parfois — et redevient sage avant un
## saut. On la pose sur un anneau et on lui décrit la course à la main.

const PAS := 1.0 / 60.0

var piste: TrackCurve
var kart: Kart
var ia: AIInput


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
	kart.motor.speed = 18.0
	ia = AIInput.new()
	ia.kart = kart
	ia.track = piste
	ia.regularite = 1.0
	ia.lateral_bias = 0.0


func after_each() -> void:
	ia.free()
	kart.free()


## Fait rouler l'IA sur place pendant `secondes`, à `distance` du départ.
func _rouler(secondes: float, distance: float = 0.0) -> void:
	ia.distance = distance
	ia.position = piste.position_at(distance)
	for i in int(secondes / PAS):
		ia.poll(PAS)


## Elle seule à `distance`, et un autre kart décrit par (avance, écart, vitesse).
func _avec_un_autre(distance: float, moi: Vector2, autre: Vector3) -> void:
	ia.distance = distance
	ia.voisins = PackedVector3Array([Vector3(distance, moi.x, moi.y),
		Vector3(distance + autre.x, autre.y, autre.z)])
	ia.mon_index = 0


func test_elle_ne_suit_pas_la_ligne_ideale_a_la_lettre() -> void:
	ia._ready()
	var mini := INF
	var maxi := -INF
	for i in 30 * 60:
		ia.distance = fmod(float(i) * 0.3, piste.length)
		ia.position = piste.position_at(ia.distance)
		ia.poll(PAS)
		var ecart := ia.ligne_visee() - ia.lateral_de_la_ligne(ia.distance_visee())
		mini = minf(mini, ecart)
		maxi = maxf(maxi, ecart)
	assert_gt(maxi - mini, 0.8, "sa ligne flâne autour de la trajectoire idéale")


func test_sa_ligne_reste_sur_la_route() -> void:
	ia._ready()
	ia.lateral_bias = 6.0
	ia.boite_laterale = 9.0
	var bord := piste.half_width - AIInput.MARGE_BORD
	for i in 20 * 60:
		ia.distance = fmod(float(i) * 0.3, piste.length)
		ia.poll(PAS)
		assert_between(ia.ligne_visee(), -bord - 0.001, bord + 0.001)
		if absf(ia.ligne_visee()) > bord + 0.001:
			return


func test_elle_change_de_ligne_sans_zigzaguer() -> void:
	_rouler(0.1)
	var avant := ia.ligne_visee()
	ia.boite_laterale = 6.0
	ia.poll(PAS)
	assert_lte(absf(ia.ligne_visee() - avant), AIInput.CHANGEMENT_DE_LIGNE * PAS + 0.001,
		"elle rejoint sa nouvelle ligne à vitesse bornée")


func test_elle_double_par_le_cote_libre() -> void:
	# Un kart plus lent, juste devant, serré à droite : on passe à gauche.
	_avec_un_autre(0.0, Vector2(2.0, 20.0), Vector3(8.0, 3.0, 14.0))
	_rouler(2.0)
	assert_lt(ia.ligne_visee(), 3.0 - 2.0, "elle déboîte du côté où il y a la place")
	_avec_un_autre(0.0, Vector2(-2.0, 20.0), Vector3(8.0, -3.0, 14.0))
	ia._depassement_reste = 0.0
	_rouler(3.0)
	assert_gt(ia.ligne_visee(), -3.0 + 2.0, "et à droite s'il est serré à gauche")


func test_un_kart_derriere_ne_la_fait_pas_doubler() -> void:
	_avec_un_autre(10.0, Vector2(0.0, 20.0), Vector3(-6.0, 0.0, 22.0))
	assert_eq(ia.kart_devant(AIInput.PORTEE_DEPASSEMENT, AIInput.LARGEUR_FILE), -1)
	assert_eq(ia.kart_derriere(AIInput.PORTEE_DEFENSE), 1)


func test_un_kart_d_une_autre_file_ne_la_gene_pas() -> void:
	_avec_un_autre(0.0, Vector2(-4.0, 20.0), Vector3(8.0, 4.0, 14.0))
	assert_eq(ia.kart_devant(AIInput.PORTEE_DEPASSEMENT, AIInput.LARGEUR_FILE), -1,
		"huit mètres à côté, ce n'est pas devant")


func test_elle_ferme_la_porte_en_ligne_droite() -> void:
	# Sur un anneau très large, la route est presque droite.
	piste = TrackCurve.new(_anneau(400.0), 9.0)
	ia.track = piste
	ia.audace = 1.0
	_avec_un_autre(0.0, Vector2(0.0, 20.0), Vector3(-5.0, -5.0, 22.0))
	_rouler(3.0)
	assert_lt(ia.ligne_visee() - ia.lateral_de_la_ligne(ia.distance_visee()), -1.5,
		"une IA audacieuse se met devant le poursuivant")


func test_une_ia_prudente_ne_defend_pas() -> void:
	piste = TrackCurve.new(_anneau(400.0), 9.0)
	ia.track = piste
	ia.audace = 0.2
	_avec_un_autre(0.0, Vector2(0.0, 20.0), Vector3(-5.0, -5.0, 22.0))
	_rouler(3.0)
	assert_almost_eq(ia.ligne_visee(), ia.lateral_de_la_ligne(ia.distance_visee()), 0.2)


func test_les_mains_vides_elle_va_chercher_une_boite() -> void:
	ia.boite_laterale = 4.0
	_rouler(3.0)
	assert_gt(ia.ligne_visee(), 2.5, "elle se décale vers la boîte")


func test_une_ia_reguliere_ne_se_trompe_jamais() -> void:
	ia.regularite = 1.0
	for i in 120 * 60:
		ia.poll(PAS)
		if ia.erreur_en_cours() != AIInput.Erreur.AUCUNE:
			fail_test("une erreur chez une IA parfaitement régulière")
			return
	pass_test("aucune erreur en deux minutes")


func test_une_ia_irreguliere_se_trompe_parfois_et_s_en_remet() -> void:
	ia.regularite = 0.0
	ia._rng.seed = 7
	var erreurs := 0
	var duree := 0.0
	var plus_longue := 0.0
	var avant := AIInput.Erreur.AUCUNE
	for i in 120 * 60:
		ia.poll(PAS)
		var e := ia.erreur_en_cours()
		if e != AIInput.Erreur.AUCUNE:
			duree += PAS
			plus_longue = maxf(plus_longue, duree)
			if avant == AIInput.Erreur.AUCUNE:
				erreurs += 1
		else:
			duree = 0.0
		avant = e
	assert_gt(erreurs, 3, "en deux minutes, une IA brouillonne commet des erreurs")
	assert_lt(erreurs, 40, "mais elle ne fait pas que ça")
	assert_lte(plus_longue, 1.2 + PAS * 2.0, "une erreur dure au plus un instant")


func test_l_hesitation_coupe_un_peu_les_gaz() -> void:
	ia._erreur = AIInput.Erreur.HESITATION
	ia._erreur_reste = 1.0
	var cmd := ia.poll(PAS)
	assert_lt(cmd.throttle, 1.0)
	assert_gt(cmd.throttle, 0.5, "un lever de pied, pas un freinage")


func test_avant_un_saut_elle_reprend_sa_ligne_et_ne_se_trompe_pas() -> void:
	ia.zones_prudentes = PackedVector2Array([Vector2(50.0, 90.0)])
	ia.boite_laterale = 5.0
	ia.regularite = 0.0
	ia._erreur = AIInput.Erreur.LARGE
	ia._erreur_reste = 1.0
	_avec_un_autre(60.0, Vector2(0.0, 20.0), Vector3(6.0, 0.0, 12.0))
	_rouler(4.0, 60.0)
	assert_true(ia.prudente())
	assert_eq(ia.erreur_en_cours(), AIInput.Erreur.AUCUNE, "pas d'erreur sur l'élan d'un saut")
	assert_almost_eq(ia.ligne_visee(), ia.lateral_de_la_ligne(ia.distance_visee()), 0.2,
		"ni dépassement ni détour pour une boîte : la ligne, droite")


func test_la_zone_prudente_fait_le_tour_du_circuit() -> void:
	ia.zones_prudentes = PackedVector2Array([Vector2(-10.0, 5.0)])
	ia.distance = piste.length - 4.0
	assert_true(ia.prudente(), "une zone à cheval sur la ligne d'arrivée")
	ia.distance = 20.0
	assert_false(ia.prudente(40.0), "passée, la zone ne compte plus")
	ia.distance = piste.length - 40.0
	assert_false(ia.prudente())
	assert_true(ia.prudente(40.0), "la marge l'étend en amont")


func test_rien_ne_tombe_sur_l_elan_d_un_saut() -> void:
	ia.zones_prudentes = PackedVector2Array([Vector2(100.0, 130.0)])
	ia.objet_pret = ItemKind.BANANA
	_avec_un_autre(80.0, Vector2(0.0, 20.0), Vector3(-4.0, 0.0, 22.0))
	var cmd := ia.poll(PAS)
	assert_false(cmd.use_item, "la banane attend la fin du saut")
	ia.objet_pret = ItemKind.MUSHROOM
	_avec_un_autre(80.0, Vector2(0.0, 20.0), Vector3(-40.0, 0.0, 22.0))
	cmd = ia.poll(PAS)
	assert_true(cmd.use_item, "le champignon, lui, aide à sauter")


func test_un_objet_tenu_reste_tenu_sur_l_elan() -> void:
	ia.zones_prudentes = PackedVector2Array([Vector2(100.0, 130.0)])
	ia.objet_pret = ItemKind.BANANA
	ia.objet_tenu = true
	ia._tenu_depuis = AIInput.ATTENTE_TENU_MAX + 1.0
	_avec_un_autre(110.0, Vector2(0.0, 20.0), Vector3(-4.0, 0.0, 22.0))
	assert_true(ia.poll(PAS).item_held)


func test_le_champignon_attend_la_ligne_droite() -> void:
	piste = TrackCurve.new(_anneau(20.0), 6.0)
	ia.track = piste
	ia.objet_pret = ItemKind.MUSHROOM
	assert_false(ia.poll(PAS).use_item, "en plein virage serré, on attend")
	for i in int(AIInput.ATTENTE_CHAMPIGNON / PAS) + 2:
		ia.poll(PAS)
	assert_true(ia.poll(PAS).use_item, "mais pas indéfiniment")


func test_la_verte_attend_une_cible_alignee() -> void:
	ia.objet_pret = ItemKind.GREEN_SHELL
	_avec_un_autre(0.0, Vector2(-4.0, 20.0), Vector3(15.0, 4.0, 20.0))
	assert_false(ia.veut_utiliser_objet(), "personne dans l'axe")
	_avec_un_autre(0.0, Vector2(0.0, 20.0), Vector3(15.0, 0.5, 20.0))
	assert_true(ia.veut_utiliser_objet(), "quelqu'un devant, dans sa file")


func test_derriere_la_tete_elle_garde_une_banane_en_bouclier() -> void:
	ia.objet_pret = ItemKind.BANANA
	_avec_un_autre(0.0, Vector2(0.0, 20.0), Vector3(30.0, 0.0, 20.0))
	assert_true(ia.veut_garder_derriere(), "personne derrière : elle la garde en bouclier")
	_avec_un_autre(0.0, Vector2(0.0, 20.0), Vector3(-5.0, 0.0, 22.0))
	assert_false(ia.veut_garder_derriere(), "un poursuivant colle : elle la lâche")
