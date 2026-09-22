extends GutTest

## TrackSmoother ne touche ni à la scène ni aux nœuds : il ne fait que du calcul
## sur une Curve3D. C'est ce qui permet de tester ici la décision de déplacer un
## point de contrôle, plutôt que de la laisser dans un script jetable.


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


## Le défaut réellement rencontré sur le circuit 1 : un point de contrôle dont
## les poignées sont bien plus courtes que celles de ses voisins. Le tracé reste
## joli à l'écran, mais la courbe se pince au point et le kart s'y encastre.
## Huit points plutôt que seize : des segments longs et une poignée courte, le
## rapport exact du point fautif du circuit 1 (13,7 m de poignée pour 50 à 63 m
## d'espacement, quand ses voisins tenaient 23 à 27 m).
func _anneau_a_poignee_courte(index: int = 3, part: float = 0.10) -> Curve3D:
	var c := _anneau(50.0, 8)
	c.set_point_in(index, c.get_point_in(index) * part)
	c.set_point_out(index, c.get_point_out(index) * part)
	return c


## Un pincement pathologique : trois points consécutifs effondrés vers le
## centre. Aucun tracé réel ne ressemble à ça ; il sert à vérifier que l'outil
## avoue son échec au lieu de rendre une courbe encore impraticable en silence.
func _anneau_pince() -> Curve3D:
	var c := _anneau(50.0, 16)
	for i in [4, 5, 6]:
		var p := c.get_point_position(i)
		c.set_point_position(i, p * 0.25)
	return c


func test_une_courbe_fermee_se_reconnait() -> void:
	assert_true(TrackSmoother.est_fermee(_anneau()),
		"un anneau répète son premier point à la fin")
	var ouverte := Curve3D.new()
	ouverte.add_point(Vector3.ZERO)
	ouverte.add_point(Vector3(0, 0, -50))
	assert_false(TrackSmoother.est_fermee(ouverte))


func test_les_poignees_manquantes_se_posent() -> void:
	var c := _anneau(50.0, 16)
	for i in [3, 7]:
		c.set_point_in(i, Vector3.ZERO)
		c.set_point_out(i, Vector3.ZERO)

	assert_eq(TrackSmoother.poser_les_poignees(c), 2,
		"seuls les deux points vidés doivent être repris")
	assert_gt(c.get_point_out(3).length(), 1.0, "et ils ont maintenant des poignées")


func test_poser_les_poignees_ne_touche_pas_au_travail_fait_a_la_main() -> void:
	var c := _anneau(50.0, 16)
	var avant := c.get_point_out(5)
	TrackSmoother.poser_les_poignees(c)
	assert_almost_eq(c.get_point_out(5).distance_to(avant), 0.0, 0.001,
		"un point déjà réglé ne doit pas être écrasé")


func test_les_poignees_posees_sont_colineaires() -> void:
	# C'est toute la question : des poignées colinéaires rendent la tangente
	# continue, donc suppriment l'angle vif.
	var c := _anneau(50.0, 16)
	c.set_point_in(3, Vector3.ZERO)
	c.set_point_out(3, Vector3.ZERO)
	TrackSmoother.poser_les_poignees(c)
	var entree := c.get_point_in(3)
	var sortie := c.get_point_out(3)
	assert_almost_eq(entree.normalized().dot(sortie.normalized()), -1.0, 0.001,
		"l'entrée et la sortie doivent être exactement opposées")


func test_un_anneau_large_n_a_rien_a_elargir() -> void:
	var c := _anneau(50.0, 16)
	var bilan := TrackSmoother.elargir(c, 9.0)
	assert_true(bilan["atteint"], "un anneau de rayon 50 est déjà roulable")
	assert_almost_eq(float(bilan["deplacement_max"]), 0.0, 0.01,
		"et rien ne doit bouger")


func test_une_poignee_trop_courte_s_ouvre() -> void:
	var c := _anneau_a_poignee_courte()
	var serre_avant := TrackSmoother.rayon_le_plus_serre(c)
	assert_lt(serre_avant, 9.0, "prémisse : ce tracé a bien un virage impraticable")

	var bilan := TrackSmoother.elargir(c, 9.0)

	assert_true(bilan["atteint"],
		"objectif %.1f m, obtenu %.1f m" % [bilan["objectif"], bilan["rayon_apres"]])
	assert_eq(bilan["points_deplaces"], 0,
		"allonger une poignée suffit : le tracé ne doit pas avoir bougé d'un centimètre")
	assert_almost_eq(float(bilan["deplacement_max"]), 0.0, 0.01)


func test_un_pincement_pathologique_s_ameliore_et_le_dit() -> void:
	# Aucun tracé réel ne ressemble à ça. Ce qui compte ici n'est pas que
	# l'outil y arrive, c'est qu'il améliore sans jamais empirer, et qu'il dise
	# la vérité sur le résultat.
	var c := _anneau_pince()
	var serre_avant := TrackSmoother.rayon_le_plus_serre(c)
	var bilan := TrackSmoother.elargir(c, 9.0, 40.0)

	assert_gt(float(bilan["rayon_apres"]), serre_avant,
		"une retouche ne doit jamais resserrer le virage qu'elle prétend ouvrir")
	assert_eq(bilan["atteint"], float(bilan["rayon_apres"]) >= 9.0,
		"le compte rendu doit correspondre au résultat réel")


func test_elargir_respecte_le_plafond_de_deplacement() -> void:
	var c := _anneau_pince()
	var bilan := TrackSmoother.elargir(c, 9.0, 3.0)
	assert_lte(float(bilan["deplacement_max"]), 3.01,
		"on ouvre les virages, on ne redessine pas le circuit à la place de son auteur")


func test_elargir_dit_quand_il_n_y_arrive_pas() -> void:
	# Plafond trop bas pour l'objectif : le compte rendu doit l'avouer plutôt
	# que de rendre une courbe encore impraticable en silence.
	var c := _anneau_pince()
	var bilan := TrackSmoother.elargir(c, 9.0, 0.2)
	assert_false(bilan["atteint"],
		"un plafond de 20 cm ne peut pas ouvrir un virage de 3 m de rayon")
	assert_lt(float(bilan["rayon_apres"]), 9.0,
		"et le rayon réel doit bien confirmer l'échec annoncé")


func test_elargir_garde_la_courbe_fermee() -> void:
	var c := _anneau_pince()
	TrackSmoother.elargir(c, 9.0, 40.0)
	assert_true(TrackSmoother.est_fermee(c),
		"désolidariser les deux extrémités ouvrirait le circuit sur la ligne de départ")


func test_le_devers_penche_vers_l_interieur() -> void:
	var c := _anneau(50.0, 16)
	TrackSmoother.incliner(c)
	# L'anneau des tests tourne à droite : le dévers doit avoir un signe
	# constant, et le même partout puisque la courbure l'est.
	var premier := c.get_point_tilt(2)
	assert_gt(absf(premier), 0.01, "un virage constant doit être incliné")
	for i in range(2, 12):
		assert_eq(signf(c.get_point_tilt(i)), signf(premier),
			"le dévers ne doit pas changer de sens sur une courbure constante")


func test_le_devers_est_plafonne() -> void:
	var serre := _anneau(12.0, 16)
	var bilan := TrackSmoother.incliner(serre, 18.0)
	assert_lte(float(bilan["devers_max_deg"]), 18.01,
		"un virage relevé à 39 degrés est juste sur le papier et illisible à l'écran")
	assert_gt(float(bilan["devers_max_deg"]), 17.0,
		"mais un virage très serré doit bien atteindre le plafond")


func test_un_virage_serre_penche_plus_qu_un_virage_large() -> void:
	var large := _anneau(80.0, 16)
	var serre := _anneau(25.0, 16)
	TrackSmoother.incliner(large, 45.0)
	TrackSmoother.incliner(serre, 45.0)
	assert_gt(absf(serre.get_point_tilt(4)), absf(large.get_point_tilt(4)),
		"l'inclinaison suit ce que la physique demanderait pour tenir le virage")


func test_une_ligne_droite_reste_a_plat() -> void:
	var droite := Curve3D.new()
	for i in 6:
		droite.add_point(Vector3(0.0, 0.0, -40.0 * float(i)))
	TrackSmoother.poser_les_poignees(droite)
	TrackSmoother.incliner(droite)
	for i in droite.point_count:
		assert_almost_eq(droite.get_point_tilt(i), 0.0, 0.01,
			"sans courbure, aucune raison de pencher")


func test_le_devers_ne_vrille_pas_trop_vite() -> void:
	# Ce n'est pas l'angle qui casse tout, c'est sa dérivée : à 22 degrés de
	# plafond le tracé passait de +21,5 à -5,8 degrés en 70 m, et les bords du
	# ruban se dressaient en murs. L'IA y restait bloquée 478 images.
	var c3 := _anneau(50.0, 8)
	# Une courbure qui s'inverse brutalement : le pire cas pour le dévers.
	for i in [2, 3]:
		var p := c3.get_point_position(i)
		c3.set_point_position(i, Vector3(p.x, p.y, -p.z))
	TrackSmoother.poser_les_poignees(c3, false)

	var bilan := TrackSmoother.incliner(c3, 25.0)
	assert_lte(float(bilan["torsion_max_deg_par_m"]), rad_to_deg(TrackSmoother.TORSION_MAX) + 0.01,
		"le dévers doit s'installer progressivement, pas d'un coup")


func test_borner_la_torsion_garde_du_devers() -> void:
	# Le correctif ne doit pas se contenter de tout remettre à plat.
	var c := _anneau(30.0, 16)
	var bilan := TrackSmoother.incliner(c, 25.0)
	assert_gt(float(bilan["devers_max_deg"]), 5.0,
		"un anneau de rayon 30 doit rester nettement incliné")
