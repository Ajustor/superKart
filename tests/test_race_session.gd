extends GutTest

## RaceSession n'a besoin de l'arbre que pour lire global_position. En passant
## le point en paramètre, toute sa logique se teste comme KartMotor : sans
## nœud, sans rendu, en quelques microsecondes. Deux défauts — un meilleur tour
## fabriqué en reculant sur la ligne, un kart qui tombait sans fin après
## l'arrivée — avaient traversé une campagne verte faute de cette couture.
##
## La remise en piste se constate sur le moteur et non sur la position : lire
## global_position hors de l'arbre est justement ce qui ne marche pas, et
## respawn_at remet le moteur à neuf.

var track: Track
var karts: Array[Kart] = []
var cerveaux: Array[AIInput] = []
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


## Monte une session de `combien` karts, sans jamais entrer dans l'arbre.
## Démonte d'abord ce qui existe : `before_each` a déjà monté une session à un
## kart, et un test qui en remonte une à huit laisserait sinon des nœuds
## orphelins derrière lui — que GUT compte et signale.
func _monter(combien: int, avec_ia: bool = false) -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	session = RaceSession.new()
	# Sans décompte : ces tests roulent dès la première image. Le décompte a
	# ses propres tests, plus bas.
	session.duree_decompte = 0.0
	for i in combien:
		var k := _kart()
		karts.append(k)
		if avec_ia:
			var cerveau := AIInput.new()
			cerveau.kart = k
			cerveaux.append(cerveau)
			session.brancher_ia(cerveau)
	session.demarrer(track, karts)


func _demonter() -> void:
	if session != null:
		session.free()
		session = null
	for c in cerveaux:
		c.free()
	cerveaux.clear()
	for k in karts:
		k.free()
	karts.clear()
	if track != null:
		track.free()
		track = null


func before_each() -> void:
	_monter(1)


func after_each() -> void:
	_demonter()


## Le concurrent du joueur, celui qu'on suit dans la plupart des tests.
func _joueur() -> RaceEntry:
	return session.entries[0]


## Avance le long de l'axe par pas de 50 cm, en appelant la session comme le
## ferait le moteur, à 60 Hz.
func _rouler(de: float, vers: float) -> void:
	var d := de
	var pas := 0.5 * signf(vers - de)
	while absf(vers - d) > 0.5:
		d += pas
		session.avancer(_joueur(), track.track_curve.position_at(d), 1.0 / 60.0)
	session.avancer(_joueur(), track.track_curve.position_at(vers), 1.0 / 60.0)


func test_un_tour_honnete_enregistre_un_tour() -> void:
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_eq(_joueur().progress.lap, 1)
	assert_true(_joueur().timer.has_best, "le tour bouclé donne un meilleur temps")
	assert_gt(_joueur().timer.best, 1.0, "et ce temps n'est pas dérisoire")


func test_reculer_sur_la_ligne_ne_refabrique_pas_de_tour() -> void:
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	var reference := _joueur().timer.best

	# À cheval sur la ligne, et non au-delà : c'est le passage sous une
	# longueur entière qui fait redescendre progress.lap, et rien d'autre.
	for i in 20:
		session.avancer(_joueur(), track.track_curve.position_at(L - 0.4), 1.0 / 60.0)
		assert_eq(_joueur().progress.lap, 0,
			"reculer sous la ligne ramène bien le compteur à zéro")
		session.avancer(_joueur(), track.track_curve.position_at(L + 0.3), 1.0 / 60.0)

	assert_almost_eq(_joueur().timer.best, reference, 0.0001,
		"repasser la ligne à l'envers ne doit pas offrir un tour de deux images")


func test_le_hors_piste_ne_se_fige_pas_apres_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_true(_joueur().finished, "un tour suffit à finir cette course")

	# Entre le bord de piste et la marge de remise en piste : assez dehors pour
	# que le drapeau lève, pas assez pour être ramené. Sinon la remise en piste
	# remettrait le moteur à neuf dans la même image et effacerait le drapeau.
	var large := track.track_curve.position_at(100.0) \
		+ track.track_curve.right_at(100.0) * 10.5
	session.avancer(_joueur(), large, 1.0 / 60.0)

	assert_true(karts[0].motor.on_offroad,
		"le hors-piste ne se fige pas parce que la course est finie")


func test_la_remise_en_piste_continue_apres_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_true(_joueur().finished)

	karts[0].motor.speed = 20.0
	var dehors := track.track_curve.position_at(100.0) \
		+ track.track_curve.right_at(100.0) * 40.0
	session.avancer(_joueur(), dehors, 1.0 / 60.0)

	assert_eq(karts[0].motor.speed, 0.0,
		"respawn_at remet le moteur à neuf : sans lui le kart tombe sans fin")


func test_le_chrono_s_arrete_a_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	var fige := _joueur().timer.current
	for i in 30:
		session.avancer(_joueur(), track.track_curve.position_at(10.0), 1.0 / 60.0)
	assert_almost_eq(_joueur().timer.current, fige, 0.0001,
		"le chrono ne tourne plus une fois la course finie")


func test_chaque_concurrent_a_son_propre_etat() -> void:
	_monter(3)
	var L := track.track_curve.length

	# Seul le deuxième roule.
	for i in 40:
		session.avancer(session.entries[1], track.track_curve.position_at(float(i) * 0.5), 1.0 / 60.0)

	assert_gt(session.entries[1].progress.total, 5.0, "celui qui roule avance")
	var depart := RaceSession.case_de_grille(session.entries[0].case_de_grille).x
	assert_almost_eq(session.entries[0].progress.total, depart, 0.001,
		"et les autres restent où ils sont")
	assert_almost_eq(session.entries[2].timer.current, 0.0, 0.001,
		"un chrono par concurrent, pas un pour tous")


func test_la_course_finit_pour_chacun_separement() -> void:
	_monter(2)
	session.lap_count = 1
	var L := track.track_curve.length
	var d := 0.0
	while d < L + 0.3:
		d = minf(d + 0.5, L + 0.3)
		session.avancer(session.entries[0], track.track_curve.position_at(d), 1.0 / 60.0)

	assert_true(session.entries[0].finished, "celui qui a bouclé a fini")
	assert_false(session.entries[1].finished, "celui qui n'a pas bouclé court toujours")


func test_la_grille_ne_superpose_personne() -> void:
	_monter(8)
	# Sur les positions dans l'espace et non sur les distances le long de l'axe :
	# deux karts de la même rangée sont côte à côte, ce qui est exactement le
	# but d'une grille à deux colonnes.
	var places: Array[Vector3] = []
	for i in session.entries.size():
		var ou := _place_de_la_case(i).origin
		for autre in places:
			assert_gt(ou.distance_to(autre), 2.0,
				"la case %d chevauche une autre" % i)
		places.append(ou)


func test_la_grille_part_en_amont_de_la_ligne() -> void:
	_monter(8)
	var L := track.track_curve.length
	for i in session.entries.size():
		# Les cases sont à des distances négatives, donc enroulées près de la
		# fin du tour. wrapf les relit en « combien de mètres avant la ligne ».
		var recul := wrapf(-session.entries[i].progress.distance, 0.0, L)
		assert_between(recul, RaceSession.RECUL_GRILLE, 30.0,
			"la case %d doit être derrière la ligne, à moins de trente mètres" % i)


## Le tour se boucle sur la ligne peinte pour tout le monde : chacun part de
## l'avancement de sa case. Avec un même retard pour tous, le dernier de la
## grille bouclait son tour dix-sept mètres avant la ligne.
func test_chacun_part_de_l_avancement_de_sa_case() -> void:
	_monter(8)
	for entree in session.entries:
		assert_almost_eq(entree.progress.total, RaceSession.case_de_grille(entree.case_de_grille).x, 0.001)


func test_le_dernier_de_la_grille_boucle_son_tour_sur_la_ligne() -> void:
	_monter(8)
	var L := track.track_curve.length
	var dernier: RaceEntry = session.entries[0]
	for entree in session.entries:
		if entree.case_de_grille > dernier.case_de_grille:
			dernier = entree
	var d := RaceSession.case_de_grille(dernier.case_de_grille).x
	while d < L - 0.5:
		d += 0.5
		session.avancer(dernier, track.track_curve.position_at(d), 1.0 / 60.0)
	assert_eq(dernier.progress.lap, 0, "pas encore la ligne, même parti de loin")
	session.avancer(dernier, track.track_curve.position_at(L + 0.5), 1.0 / 60.0)
	assert_eq(dernier.progress.lap, 1, "la ligne franchie")


func test_la_grille_tient_sur_la_chaussee() -> void:
	_monter(8)
	for i in session.entries.size():
		var place := _place_de_la_case(i)
		var ecart := absf(track.track_curve.lateral_offset(place.origin))
		assert_lt(ecart, 9.0,
			"la case %d doit être sur le bitume, pas sur le bas-côté" % i)


func _place_de_la_case(index: int) -> Transform3D:
	return session.transformee_de_case(index)


func test_le_classement_suit_la_distance_parcourue() -> void:
	_monter(3)
	session.entries[0].progress.total = 120.0
	session.entries[1].progress.total = 400.0
	session.entries[2].progress.total = 250.0

	session.classer()

	assert_eq(session.entries[1].position, 1, "le plus avancé est premier")
	assert_eq(session.entries[2].position, 2)
	assert_eq(session.entries[0].position, 3)


func test_le_classement_ne_se_laisse_pas_tromper_par_la_position_sur_l_axe() -> void:
	_monter(2)
	var L := track.track_curve.length

	# Le premier a bouclé un tour et entamé le suivant : 10 m parcourus au-delà.
	session.entries[0].progress.total = L + 10.0
	session.entries[0].progress.distance = 10.0
	# Le second a reculé sous la ligne sans jamais boucler : sa position sur
	# l'axe est proche de la fin du tour, mais il n'a presque rien parcouru.
	session.entries[1].progress.total = 5.0
	session.entries[1].progress.distance = L - 2.0

	session.classer()

	assert_eq(session.entries[0].position, 1,
		"celui qui a réellement parcouru le plus est devant")
	assert_eq(session.entries[1].position, 2,
		"une position d'axe élevée ne vaut pas un tour")


func test_le_classement_est_stable_a_egalite() -> void:
	_monter(3)
	for entree in session.entries:
		entree.progress.total = 100.0

	session.classer()

	var places := [session.entries[0].position, session.entries[1].position, session.entries[2].position]
	places.sort()
	assert_eq(places, [1, 2, 3],
		"trois karts à égalité occupent quand même trois places distinctes")


func test_chaque_image_met_le_classement_a_jour() -> void:
	_monter(2)
	session.avancer(session.entries[1], track.track_curve.position_at(30.0), 1.0 / 60.0)
	session.classer()
	assert_eq(session.entries[1].position, 1,
		"celui qui a roulé passe devant sans qu'on ait à le dire")


func test_la_session_branche_l_ia_sur_le_circuit() -> void:
	_monter(1, true)

	assert_eq(cerveaux[0].track, track.track_curve,
		"sans circuit, l'IA ne sait pas où viser")
	assert_almost_eq(cerveaux[0].distance, session.entries[0].progress.distance, 0.001,
		"et elle part de sa case de grille, pas de la ligne")
	assert_gt(cerveaux[0].position.length(), 1.0,
		"amorcée sur sa case, pas sur l'origine du monde")


func test_avancer_tient_l_ia_a_jour() -> void:
	_monter(1, true)

	var ou := track.track_curve.position_at(60.0)
	session.avancer(session.entries[0], ou, 1.0 / 60.0)

	assert_almost_eq(cerveaux[0].distance, 60.0, 0.5,
		"l'IA doit savoir où elle est rendue")
	assert_almost_eq(cerveaux[0].position.distance_to(ou), 0.0, 0.001,
		"et à quel endroit exactement, pour mesurer son écart à la ligne")


## Le même anneau, mais creusé loin sous l'altitude zéro : une piste à
## plusieurs niveaux descend, et « en bas » ne veut rien dire dans l'absolu.
func _anneau_enfoui(profondeur: float) -> Curve3D:
	var c := _anneau()
	for i in c.point_count:
		var p := c.get_point_position(i)
		c.set_point_position(i, p + Vector3.DOWN * profondeur)
	return c


func test_rouler_loin_sous_l_altitude_zero_ne_teleporte_pas() -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau_enfoui(30.0), 9.0)
	session = RaceSession.new()
	karts.append(_kart())
	session.demarrer(track, karts)

	karts[0].motor.speed = 20.0
	var sur_la_route := track.track_curve.racing_line_at(120.0)
	session.avancer(session.entries[0], sur_la_route, 1.0 / 60.0)

	assert_eq(karts[0].motor.speed, 20.0,
		"une route à -30 m n'est pas un kart tombé dans le vide : "
		+ "un plancher absolu téléportait le kart 88 %% des images")


func test_tomber_sous_la_route_teleporte_toujours() -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau_enfoui(30.0), 9.0)
	session = RaceSession.new()
	karts.append(_kart())
	session.demarrer(track, karts)

	karts[0].motor.speed = 20.0
	var sous_la_route := track.track_curve.racing_line_at(120.0) 		+ Vector3.DOWN * (RaceSession.FALL_DEPTH + 1.0)
	session.avancer(session.entries[0], sous_la_route, 1.0 / 60.0)

	assert_eq(karts[0].motor.speed, 0.0,
		"le garde-fou doit toujours rattraper un kart réellement tombé")


# --- Décompte et départ -----------------------------------------------------

func _monter_avec_decompte(combien: int, duree: float) -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	session = RaceSession.new()
	session.duree_decompte = duree
	for i in combien:
		karts.append(_kart())
	session.demarrer(track, karts)


func test_le_decompte_fige_les_karts_sur_leur_case() -> void:
	_monter_avec_decompte(3, 3.0)
	assert_false(session.en_course, "la course attend le vert")
	for k in karts:
		assert_false(k.controle_actif, "aucun kart ne part avant le vert")


func test_le_decompte_n_entre_dans_aucun_chrono() -> void:
	_monter_avec_decompte(1, 3.0)
	for i in 60:
		session.avancer_decompte(1.0 / 60.0)
		session.avancer(_joueur(), track.track_curve.position_at(0.0), 1.0 / 60.0)
	assert_almost_eq(_joueur().timer.current, 0.0, 0.0001,
		"une seconde de décompte ne doit pas coûter une seconde au chrono")
	assert_almost_eq(_joueur().temps_course, 0.0, 0.0001)


func test_le_vert_lache_tout_le_monde() -> void:
	_monter_avec_decompte(3, 3.0)
	watch_signals(session)
	for i in 200:
		session.avancer_decompte(1.0 / 60.0)
	assert_true(session.en_course)
	for k in karts:
		assert_true(k.controle_actif, "chaque kart est lâché au vert")
	assert_signal_emit_count(session, "depart", 1, "un seul départ, pas un par image")
	assert_signal_emit_count(session, "decompte", 3, "trois, deux, un")


func test_sans_decompte_la_course_part_tout_de_suite() -> void:
	_monter_avec_decompte(2, 0.0)
	assert_true(session.en_course)
	assert_true(karts[0].controle_actif)


# --- Case de départ du joueur ------------------------------------------------

func test_les_cases_attribuees_sont_toutes_distinctes() -> void:
	for choix in range(0, 10):
		var cases := RaceSession.cases_attribuees(8, choix)
		var triees := cases.duplicate()
		triees.sort()
		assert_eq(triees, [0, 1, 2, 3, 4, 5, 6, 7],
			"choisir la case %d ne doit ni doubler ni oublier une case" % choix)


func test_le_joueur_prend_la_case_choisie() -> void:
	assert_eq(RaceSession.cases_attribuees(8, 1)[0], 0, "1 = pole position")
	assert_eq(RaceSession.cases_attribuees(8, 5)[0], 4)
	assert_eq(RaceSession.cases_attribuees(8, 8)[0], 7)


func test_sans_choix_le_joueur_part_du_fond() -> void:
	assert_eq(RaceSession.cases_attribuees(8, 0)[0], 7)
	assert_eq(RaceSession.cases_attribuees(8, 42)[0], 7,
		"une case hors grille renvoie au fond, pas dans le vide")


func test_l_ia_la_plus_rapide_part_devant() -> void:
	var cases := RaceSession.cases_attribuees(8, 1)
	assert_eq(cases, [0, 1, 2, 3, 4, 5, 6, 7])
	cases = RaceSession.cases_attribuees(8, 3)
	assert_eq(cases, [2, 0, 1, 3, 4, 5, 6, 7],
		"les adversaires gardent leur ordre autour de la case du joueur")


func test_la_pole_position_est_juste_derriere_la_ligne() -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	session = RaceSession.new()
	session.duree_decompte = 0.0
	session.case_du_joueur = 1
	for i in 8:
		karts.append(_kart())
	session.demarrer(track, karts)
	var recul := wrapf(-_joueur().progress.distance, 0.0, track.track_curve.length)
	assert_almost_eq(recul, RaceSession.RECUL_GRILLE, 0.01,
		"en pole, le joueur est posé quelques mètres derrière la ligne")
	assert_gt(wrapf(-session.entries[1].progress.distance, 0.0, track.track_curve.length), 0.5,
		"et le premier adversaire derrière lui")


# --- Arrivée et classement final ---------------------------------------------

## Fait rouler ce concurrent jusqu'à ce qu'il boucle un tour de plus.
func _faire_boucler(entree: RaceEntry) -> void:
	var vise := entree.tours_comptes + 1
	var d := entree.progress.distance
	var garde := 0
	while entree.tours_comptes < vise and garde < 10000:
		d += 0.5
		garde += 1
		session.avancer(entree, track.track_curve.position_at(d), 1.0 / 60.0)


func test_l_ordre_d_arrivee_prime_sur_la_distance() -> void:
	_monter(2)
	session.lap_count = 1
	_faire_boucler(session.entries[0])
	_faire_boucler(session.entries[1])
	assert_eq(session.entries[0].place_finale, 1)
	assert_eq(session.entries[1].place_finale, 2)

	# Le second continue de rouler bien plus loin que le vainqueur.
	session.entries[1].progress.total += 500.0
	session.classer()
	assert_eq(session.entries[0].position, 1,
		"le vainqueur reste premier, même dépassé après la ligne")


func test_le_temps_de_course_s_arrete_a_l_arrivee() -> void:
	session.lap_count = 1
	_faire_boucler(_joueur())
	var fige := _joueur().temps_course
	assert_gt(fige, 1.0)
	for i in 30:
		session.avancer(_joueur(), track.track_curve.position_at(10.0), 1.0 / 60.0)
	assert_almost_eq(_joueur().temps_course, fige, 0.0001)


func test_la_course_se_termine_quand_tout_le_monde_a_fini() -> void:
	_monter(2)
	session.lap_count = 1
	watch_signals(session)
	_faire_boucler(session.entries[0])
	assert_false(session.terminee, "il reste quelqu'un en piste")
	_faire_boucler(session.entries[1])
	assert_true(session.terminee)
	assert_signal_emit_count(session, "course_terminee", 1)
	assert_signal_emit_count(session, "arrivee", 2)


func test_le_joueur_passe_en_pilote_automatique_apres_l_arrivee() -> void:
	session.lap_count = 1
	var manette := PlayerInput.new()
	karts[0].changer_pilote(manette)
	assert_true(karts[0].est_pilote_par_le_joueur())

	_faire_boucler(_joueur())

	assert_false(karts[0].est_pilote_par_le_joueur(),
		"le tour d'honneur se fait sans les mains")
	var pilote := karts[0].get_node_or_null("PiloteAutomatique") as AIInput
	assert_not_null(pilote)
	assert_eq(pilote.track, track.track_curve,
		"le kart consulte son pilote avant la prochaine image de la session : "
		+ "il doit déjà savoir où viser")
	manette.free()


func test_le_classement_rend_les_concurrents_dans_l_ordre() -> void:
	_monter(3)
	session.entries[0].progress.total = 10.0
	session.entries[1].progress.total = 30.0
	session.entries[2].progress.total = 20.0
	session.classer()
	var ordre := session.classement()
	assert_eq(ordre[0], session.entries[1])
	assert_eq(ordre[1], session.entries[2])
	assert_eq(ordre[2], session.entries[0])


func test_chaque_concurrent_a_un_nom() -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	session = RaceSession.new()
	session.noms = PackedStringArray(["Vous", "Turbo"])
	for i in 3:
		karts.append(_kart())
	session.demarrer(track, karts)
	assert_eq(session.entries[0].nom, "Vous")
	assert_eq(session.entries[1].nom, "Turbo")
	assert_ne(session.entries[2].nom, "", "un nom manquant ne laisse pas une ligne vide")


func test_sur_la_grille_la_place_est_la_case() -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	session = RaceSession.new()
	session.duree_decompte = 3.0
	session.case_du_joueur = 1
	for i in 4:
		karts.append(_kart())
	session.demarrer(track, karts)
	# Le bruit de tassement qui trompait le tri sur la distance.
	session.entries[0].progress.total = -0.002
	session.entries[3].progress.total = 0.004
	session.classer()
	assert_eq(session.entries[0].position, 1, "en pole, on est premier avant le départ")
	assert_eq(session.entries[3].position, 4)


# --- Turbo au départ -----------------------------------------------------------------

## Un décompte de trois secondes, le joueur prenant les gaz à `gaz_a` secondes
## du vert (-1 : jamais).
func _decompter(gaz_a: float) -> void:
	_monter_avec_decompte(1, 3.0)
	var pas := 1.0 / 60.0
	while not session.en_course:
		karts[0].gaz_tenu = gaz_a >= 0.0 and session.decompte_restant <= gaz_a + pas * 0.5
		session.avancer_decompte(pas)


func test_les_gaz_au_bon_moment_font_partir_en_trombe() -> void:
	_decompter(1.0)
	assert_gt(karts[0].motor.boost_timer, 0.0, "turbo au départ")
	assert_true(karts[0].controle_actif)


func test_les_gaz_des_le_premier_feu_font_caler() -> void:
	_decompter(2.8)
	assert_false(karts[0].controle_actif, "calé au vert")
	assert_eq(karts[0].motor.boost_timer, 0.0)
	var pas := 1.0 / 60.0
	var t := 0.0
	while not karts[0].controle_actif and t < 2.0:
		session._relancer_les_cales(pas)
		t += pas
	assert_almost_eq(t, RaceSession.CALAGE, 0.05, "il repart après un court instant")


func test_sans_gaz_ou_trop_tard_le_depart_est_normal() -> void:
	_decompter(-1.0)
	assert_eq(karts[0].motor.boost_timer, 0.0)
	assert_true(karts[0].controle_actif)
	_decompter(0.1)
	assert_eq(karts[0].motor.boost_timer, 0.0, "accélérer au vert, c'est trop tard pour le turbo")


func test_la_fenetre_du_turbo() -> void:
	assert_eq(RaceSession.resultat_du_depart(-1.0), RaceSession.Depart.NORMAL)
	assert_eq(RaceSession.resultat_du_depart(0.1), RaceSession.Depart.NORMAL)
	assert_eq(RaceSession.resultat_du_depart(0.5), RaceSession.Depart.TURBO)
	assert_eq(RaceSession.resultat_du_depart(1.4), RaceSession.Depart.TURBO)
	assert_eq(RaceSession.resultat_du_depart(2.0), RaceSession.Depart.CALE)


func test_le_tactile_retient_ses_gaz_automatiques_pendant_le_decompte() -> void:
	_monter_avec_decompte(1, 3.0)
	assert_true(TouchControls.gaz_auto_retenus, "sinon le joueur tactile calerait à chaque course")
	while not session.en_course:
		session.avancer_decompte(0.1)
	assert_false(TouchControls.gaz_auto_retenus, "au vert, l'accélération automatique reprend")


## La pole recule derrière la ligne, mais le tour se boucle toujours sur la
## ligne peinte : pas six mètres avant, sous le nez du portique.
func test_la_pole_boucle_son_tour_sur_la_ligne() -> void:
	var L := track.track_curve.length
	_rouler(-RaceSession.RECUL_GRILLE, L - 0.5)
	assert_eq(_joueur().progress.lap, 0, "pas encore la ligne")
	_rouler(L - 0.5, L + 0.5)
	assert_eq(_joueur().progress.lap, 1, "la ligne franchie")
