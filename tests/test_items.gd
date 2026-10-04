extends GutTest

## Les objets, de l'emplacement jusqu'à l'impact. Comme pour RaceSession, les
## positions des karts sont passées en paramètre : rien ici n'a besoin de
## l'arbre de scènes ni du moteur physique.

var track: Track
var karts: Array[Kart] = []
var session: RaceSession
var objets: ItemManager
var a_liberer: Array[Object] = []


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


func _monter(combien: int, rangees: PackedFloat32Array = PackedFloat32Array([0.25])) -> void:
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	session = RaceSession.new()
	session.duree_decompte = 0.0
	for i in combien:
		karts.append(_kart())
	session.demarrer(track, karts)
	objets = ItemManager.new()
	objets.rng.seed = 1
	objets.preparer(session, rangees)


func after_each() -> void:
	if objets != null:
		objets.free()
		objets = null
	if session != null:
		session.free()
		session = null
	for k in karts:
		k.free()
	karts.clear()
	for o in a_liberer:
		o.free()
	a_liberer.clear()
	if track != null:
		track.free()
		track = null


func _piste() -> TrackCurve:
	return track.track_curve


## Un point de la chaussée, à la hauteur d'un kart.
func _sur_route(distance: float, lateral: float = 0.0) -> Vector3:
	return _piste().position_at(distance) + _piste().right_at(distance) * lateral + Vector3.UP * 0.4


## Toutes les positions à un endroit neutre, loin des boîtes (posées au quart).
func _positions_neutres() -> Array[Vector3]:
	var p: Array[Vector3] = []
	for i in session.entries.size():
		p.append(_sur_route(float(i) * 3.0 + 200.0, -6.0))
	return p


func _une(point: Vector3) -> Array[Vector3]:
	var p: Array[Vector3] = [point]
	return p


func _vider_roulette(entree: RaceEntry) -> void:
	entree.inventaire.avancer(KartInventory.DUREE_ROULETTE + 0.1)


# --- Emplacement -------------------------------------------------------------

func test_un_emplacement_vide_recoit_l_objet() -> void:
	var inv := KartInventory.new()
	assert_true(inv.recevoir(ItemKind.BANANA))
	assert_eq(inv.objet, ItemKind.BANANA)


func test_un_emplacement_plein_refuse_un_second_objet() -> void:
	var inv := KartInventory.new()
	inv.recevoir(ItemKind.BANANA)
	assert_false(inv.recevoir(ItemKind.RED_SHELL), "un seul emplacement")
	assert_eq(inv.objet, ItemKind.BANANA, "et il garde ce qu'il tenait")


func test_la_roulette_retient_l_objet() -> void:
	var inv := KartInventory.new()
	inv.recevoir(ItemKind.GREEN_SHELL)
	assert_false(inv.pret())
	assert_eq(inv.utiliser(), ItemKind.NONE, "rien ne part pendant la roulette")
	inv.avancer(KartInventory.DUREE_ROULETTE)
	assert_eq(inv.utiliser(), ItemKind.GREEN_SHELL)
	assert_true(inv.est_vide())


func test_le_triple_champignon_lance_trois_champignons() -> void:
	var inv := KartInventory.new()
	inv.recevoir(ItemKind.TRIPLE_MUSHROOM, 0.0)
	for i in 3:
		assert_eq(inv.utiliser(), ItemKind.MUSHROOM, "charge %d" % (i + 1))
	assert_true(inv.est_vide(), "et plus rien après la troisième")
	assert_eq(inv.utiliser(), ItemKind.NONE)


func test_rien_ne_se_recoit_pas() -> void:
	var inv := KartInventory.new()
	assert_false(inv.recevoir(ItemKind.NONE))
	assert_true(inv.est_vide())


# --- Table de tirage ---------------------------------------------------------

func test_la_place_choisit_sa_ligne() -> void:
	var t := ItemTable.new()
	assert_eq(t.ligne_pour(1, 8), 0, "le premier lit la première ligne")
	assert_eq(t.ligne_pour(8, 8), t.lignes.size() - 1, "le dernier la dernière")
	assert_eq(t.ligne_pour(4, 4), t.lignes.size() - 1,
		"à quatre concurrents, le quatrième est aussi le dernier")
	assert_eq(t.ligne_pour(99, 8), t.lignes.size() - 1, "une place hors bornes reste dans la table")


func test_le_premier_n_a_jamais_de_carapace_rouge() -> void:
	var t := ItemTable.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var bananes := 0
	for i in 2000:
		var o := t.tirer(1, 8, rng)
		assert_ne(o, ItemKind.RED_SHELL)
		if o == ItemKind.BANANA:
			bananes += 1
	assert_gt(bananes, 1000, "en tête, surtout des bananes")


func test_le_premier_n_a_jamais_de_champignon() -> void:
	var t := ItemTable.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 2000:
		assert_does_not_have([ItemKind.MUSHROOM, ItemKind.TRIPLE_MUSHROOM], t.tirer(1, 8, rng),
			"le premier n'a pas à creuser l'écart")


func test_le_dernier_a_le_plus_de_champignons() -> void:
	var t := ItemTable.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var parts := []
	for place in [1, 4, 8]:
		var n := 0
		for i in 3000:
			if t.tirer(place, 8, rng) in [ItemKind.MUSHROOM, ItemKind.TRIPLE_MUSHROOM]:
				n += 1
		parts.append(n)
	assert_eq(parts[0], 0)
	assert_gt(parts[2], parts[1], "plus on est loin, plus on en a")
	assert_gt(parts[2], 3000 * 0.5, "le dernier : un objet sur deux est un champignon")


func test_le_dernier_n_a_jamais_de_banane() -> void:
	var t := ItemTable.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var rattrapage := 0
	for i in 2000:
		var o := t.tirer(8, 8, rng)
		assert_ne(o, ItemKind.BANANA)
		if o in [ItemKind.RED_SHELL, ItemKind.MUSHROOM, ItemKind.TRIPLE_MUSHROOM, ItemKind.STAR,
				ItemKind.LIGHTNING, ItemKind.BLUE_SHELL]:
			rattrapage += 1
	assert_gt(rattrapage, 1600, "en queue, de quoi revenir")


func test_une_ligne_vide_donne_quand_meme_un_objet() -> void:
	var t := ItemTable.new()
	t.lignes = [PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])]
	assert_eq(t.tirer(1, 8, RandomNumberGenerator.new()), ItemKind.MUSHROOM)


# --- Moteur : tête-à-queue et champignon --------------------------------------

func test_le_tete_a_queue_ignore_les_commandes_et_ralentit() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = 20.0
	m.velocity_dir = 0.3
	m.heading = 0.3
	assert_true(m.stun())
	var cmd := KartCommand.new()
	cmd.throttle = 1.0
	cmd.steer = 1.0
	for i in 30:
		m.step(cmd, 1.0 / 60.0)
	assert_lt(m.speed, 20.0, "le kart touché ralentit, gaz ou pas")
	assert_almost_eq(m.velocity_dir, 0.3, 0.0001, "et ne tourne pas au volant")
	assert_ne(m.heading, 0.3, "c'est la caisse qui pivote")


func test_le_tete_a_queue_finit_par_rendre_la_main() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = 20.0
	m.stun()
	var cmd := KartCommand.new()
	var images := int(ceil(m.stats.stun_duration * 60.0)) + 2
	for i in images:
		m.step(cmd, 1.0 / 60.0)
	assert_eq(m.state, KartMotor.State.GRIP)
	assert_almost_eq(m.heading, m.velocity_dir, 0.0001, "la caisse se réaligne sur la trajectoire")


func test_on_ne_sonne_pas_un_kart_deja_sonne() -> void:
	var m := KartMotor.new(KartStats.new())
	assert_true(m.stun())
	m.step(KartCommand.new(), 0.5)
	var restant := m.stun_timer
	assert_false(m.stun(), "deux bananes coup sur coup ne clouent pas au sol")
	assert_almost_eq(m.stun_timer, restant, 0.0001)


func test_le_tete_a_queue_eteint_le_turbo() -> void:
	var m := KartMotor.new(KartStats.new())
	m.boost_objet()
	m.stun()
	assert_eq(m.boost_timer, 0.0)


func test_le_champignon_pousse_au_dela_de_la_vitesse_max() -> void:
	var m := KartMotor.new(KartStats.new())
	m.speed = m.stats.max_speed
	m.boost_objet()
	var cmd := KartCommand.new()
	cmd.throttle = 1.0
	m.step(cmd, 1.0 / 60.0)
	assert_gt(m.speed, m.stats.max_speed * 1.2)


func test_la_remise_en_piste_efface_le_tete_a_queue() -> void:
	var m := KartMotor.new(KartStats.new())
	m.stun()
	m.reset(0.0)
	assert_eq(m.state, KartMotor.State.GRIP)
	assert_eq(m.stun_timer, 0.0)


# --- Politique de l'IA ------------------------------------------------------

func test_l_ia_utilise_ce_qu_elle_recoit() -> void:
	var ia := AIInput.new()
	a_liberer.append(ia)
	assert_false(ia.veut_utiliser_objet(), "rien à utiliser")
	ia.objet_pret = ItemKind.GREEN_SHELL
	assert_true(ia.veut_utiliser_objet())


func test_l_ia_en_tete_garde_sa_banane() -> void:
	var ia := AIInput.new()
	a_liberer.append(ia)
	ia.objet_pret = ItemKind.BANANA
	ia.en_tete = true
	ia.ecart_poursuivant = 40.0
	assert_false(ia.veut_utiliser_objet(), "en tête, la banane protège")
	ia.ecart_poursuivant = 5.0
	assert_true(ia.veut_utiliser_objet(), "et tombe quand un poursuivant approche")
	ia.en_tete = false
	ia.ecart_poursuivant = 40.0
	assert_true(ia.veut_utiliser_objet(), "hors de la tête, elle part tout de suite")


# --- Boîtes -----------------------------------------------------------------

func test_une_rangee_pose_ses_boites_sur_la_route() -> void:
	_monter(1)
	assert_eq(objets.boites.size(), ItemManager.BOITES_PAR_RANGEE)
	for b in objets.boites:
		assert_lt(absf(_piste().lateral_offset(b.position)), 9.0, "la boîte doit être sur le bitume")


func test_traverser_une_boite_donne_un_objet() -> void:
	_monter(1)
	watch_signals(objets)
	var p: Array[Vector3] = [objets.boites[0].position]
	objets.avancer(p, 1.0 / 60.0)
	assert_false(session.entries[0].inventaire.est_vide())
	assert_false(objets.boites[0].disponible(), "la boîte disparaît")
	assert_signal_emit_count(objets, "objet_recu", 1)


func test_la_boite_revient_apres_un_delai() -> void:
	_monter(1)
	objets.avancer([objets.boites[0].position] as Array[Vector3], 1.0 / 60.0)
	var loin := _positions_neutres()
	objets.avancer(loin, ItemManager.REAPPARITION * 0.5)
	assert_false(objets.boites[0].disponible())
	objets.avancer(loin, ItemManager.REAPPARITION)
	assert_true(objets.boites[0].disponible())


func test_une_boite_ne_donne_rien_a_un_emplacement_plein() -> void:
	_monter(1)
	session.entries[0].inventaire.recevoir(ItemKind.BANANA)
	objets.avancer([objets.boites[0].position] as Array[Vector3], 1.0 / 60.0)
	assert_eq(session.entries[0].inventaire.objet, ItemKind.BANANA)
	assert_false(objets.boites[0].disponible(), "mais la boîte est consommée quand même")


# --- Utilisation ------------------------------------------------------------

func test_le_champignon_part_a_la_demande() -> void:
	_monter(1)
	var moi := session.entries[0]
	moi.inventaire.recevoir(ItemKind.MUSHROOM, 0.0)
	karts[0].demande_objet = true
	objets.avancer(_positions_neutres(), 1.0 / 60.0)
	assert_gt(karts[0].motor.boost_timer, 0.0)
	assert_true(moi.inventaire.est_vide())
	assert_false(karts[0].demande_objet, "la demande est consommée")


func test_une_demande_sans_objet_ne_fait_rien() -> void:
	_monter(1)
	watch_signals(objets)
	karts[0].demande_objet = true
	objets.avancer(_positions_neutres(), 1.0 / 60.0)
	assert_signal_emit_count(objets, "objet_utilise", 0)


func test_la_banane_tombe_derriere_le_kart() -> void:
	_monter(1)
	var p := _positions_neutres()
	session.entries[0].inventaire.recevoir(ItemKind.BANANA, 0.0)
	karts[0].motor.velocity_dir = _piste().yaw_at(_piste().distance_of(p[0]))
	karts[0].demande_objet = true
	objets.avancer(p, 1.0 / 60.0)
	assert_eq(objets.bananes.size(), 1)
	var derriere := _piste().distance_of(objets.bananes[0].position)
	var devant := _piste().distance_of(p[0])
	assert_lt(wrapf(derriere - devant, -50.0, 50.0), -1.0, "la banane est en arrière du kart")


func test_rouler_sur_une_banane_fait_un_tete_a_queue() -> void:
	_monter(2)
	watch_signals(objets)
	var b := objets.poser_banane(_sur_route(120.0), session.entries[0])
	var p := _positions_neutres()
	p[1] = b.position
	objets.avancer(p, 1.0 / 60.0)
	assert_eq(karts[1].motor.state, KartMotor.State.STUNNED)
	assert_eq(objets.bananes.size(), 0, "la banane est consommée")
	assert_signal_emit_count(objets, "kart_touche", 1)


func test_le_lanceur_ne_glisse_pas_sur_sa_propre_banane_en_la_posant() -> void:
	_monter(1)
	var b := objets.poser_banane(_sur_route(120.0), session.entries[0])
	objets.avancer(_une(b.position), 1.0 / 60.0)
	assert_ne(karts[0].motor.state, KartMotor.State.STUNNED)
	# Mais s'il revient dessus plus tard, elle le piège comme les autres.
	objets.avancer(_une(b.position), ItemManager.GRACE_LANCEUR)
	assert_eq(karts[0].motor.state, KartMotor.State.STUNNED)


## Tirée en travers, sans mur : elle quitte la route et disparaît. Elle
## rebondissait sur le bord du bitume, comme s'il y avait un mur invisible.
func test_la_carapace_verte_sort_de_la_route_sans_mur() -> void:
	_monter(1)
	var d := 60.0
	var travers := _piste().right_at(d)
	var c := objets.lancer_carapace(_sur_route(d), travers, session.entries[0], null)
	var p := _positions_neutres()
	var avant := c.direction
	for i in 60:
		objets.avancer(p, 1.0 / 60.0)
		if objets.carapaces.is_empty():
			break
		assert_gt(c.direction.dot(avant), 0.0, "pas de rebond sans mur (image %d)" % i)
	assert_true(objets.carapaces.is_empty(), "sortie de la route, elle est perdue")


func test_la_carapace_verte_rebondit_sur_un_mur() -> void:
	_monter(1)
	var mur := TrackWall.new()
	mur.debut = 20.0
	mur.longueur = 120.0
	mur.cote = TrackWall.Cote.LES_DEUX
	track.add_child(mur)
	var d := 60.0
	var c := objets.lancer_carapace(_sur_route(d), _piste().right_at(d), session.entries[0], null)
	var p := _positions_neutres()
	var rebonds := 0
	var avant := c.direction
	for i in 60:
		objets.avancer(p, 1.0 / 60.0)
		if objets.carapaces.is_empty():
			break
		assert_lt(absf(_piste().lateral_offset(c.position)), 9.5, "image %d" % i)
		if c.direction.dot(avant) < 0.0:
			rebonds += 1
		avant = c.direction
	assert_gt(rebonds, 0, "entre deux murs, elle rebondit")
	assert_false(objets.carapaces.is_empty(), "et reste en jeu")


func test_la_carapace_verte_touche_le_kart_qu_elle_croise() -> void:
	_monter(2)
	var p := _positions_neutres()
	var c := objets.lancer_carapace(p[1] - Vector3(0.5, 0, 0), Vector3(1, 0, 0), session.entries[0], null)
	p[1] = c.position
	objets.avancer(p, 1.0 / 60.0)
	assert_eq(karts[1].motor.state, KartMotor.State.STUNNED)
	assert_true(objets.carapaces.is_empty())


func test_la_carapace_rouge_vise_le_kart_de_devant() -> void:
	_monter(3)
	session.entries[0].progress.total = 60.0
	session.entries[1].progress.total = 30.0
	session.entries[2].progress.total = 10.0
	session.classer()
	assert_eq(objets.cible_devant(session.entries[2]), session.entries[1])
	assert_null(objets.cible_devant(session.entries[0]), "le premier n'a personne devant lui")


func test_la_carapace_rouge_rattrape_sa_cible() -> void:
	_monter(3)
	# La cible est 40 m devant, sur le côté de la route, et ne bouge pas.
	var cible := session.entries[1]
	var d_cible := 150.0
	cible.progress.distance = d_cible
	var p := _positions_neutres()
	p[1] = _sur_route(d_cible, 4.0)
	var c := objets.lancer_carapace(_sur_route(d_cible - 40.0), _piste().forward_at(d_cible - 40.0),
		session.entries[2], cible)
	assert_true(c.rouge)
	for i in 240:
		objets.avancer(p, 1.0 / 60.0)
		if objets.carapaces.is_empty():
			break
	assert_eq(karts[1].motor.state, KartMotor.State.STUNNED, "la cible est touchée")
	assert_ne(karts[0].motor.state, KartMotor.State.STUNNED, "et personne d'autre")


func test_une_carapace_et_une_banane_s_annulent() -> void:
	_monter(1)
	var b := objets.poser_banane(_sur_route(100.0), null)
	objets.lancer_carapace(b.position - _piste().forward_at(100.0) * 0.5, _piste().forward_at(100.0), null, null)
	objets.avancer(_positions_neutres(), 1.0 / 60.0)
	assert_true(objets.bananes.is_empty())
	assert_true(objets.carapaces.is_empty())


func test_la_carapace_finit_par_disparaitre() -> void:
	_monter(1)
	objets.lancer_carapace(_sur_route(10.0), _piste().forward_at(10.0), null, null)
	objets.avancer(_positions_neutres(), ItemManager.DUREE_VERTE + 0.1)
	assert_true(objets.carapaces.is_empty())


func test_les_bananes_ne_s_accumulent_pas_sans_fin() -> void:
	_monter(1)
	for i in ItemManager.MAX_BANANES + 5:
		objets.poser_banane(_sur_route(float(i) * 4.0), null)
	assert_eq(objets.bananes.size(), ItemManager.MAX_BANANES)


# --- L'IA est tenue au courant ---------------------------------------------------

func test_l_ia_sait_ce_qu_elle_tient() -> void:
	_monter(2)
	var ia := AIInput.new()
	a_liberer.append(ia)
	karts[1].changer_pilote(ia)
	session.entries[1].inventaire.recevoir(ItemKind.GREEN_SHELL)
	objets.avancer(_positions_neutres(), 1.0 / 60.0)
	assert_eq(ia.objet_pret, ItemKind.NONE, "pas pendant la roulette")
	_vider_roulette(session.entries[1])
	objets.avancer(_positions_neutres(), 1.0 / 60.0)
	assert_eq(ia.objet_pret, ItemKind.GREEN_SHELL)


# --- Objet tenu derrière, lancer devant ou derrière, klaxon -------------------------

## Le kart dans l'axe de la piste, à sa position neutre.
func _aligne(p: Array[Vector3], i: int = 0) -> void:
	karts[i].motor.velocity_dir = _piste().yaw_at(_piste().distance_of(p[i]))


func _ecart(ou: Vector3, kart_en: Vector3) -> float:
	return wrapf(_piste().distance_of(ou) - _piste().distance_of(kart_en), -50.0, 50.0)


## Appuie, garde le bouton `duree` secondes, puis le lâche.
func _tenir(p: Array[Vector3], duree: float, arriere: bool) -> void:
	karts[0].demande_objet = true
	karts[0].objet_tenu_presse = true
	karts[0].vise_arriere = arriere
	var t := 0.0
	while t < duree:
		objets.avancer(p, 1.0 / 60.0)
		t += 1.0 / 60.0
	karts[0].objet_tenu_presse = false
	objets.avancer(p, 1.0 / 60.0)


func test_tenir_le_bouton_garde_l_objet_derriere() -> void:
	_monter(1)
	var p := _positions_neutres()
	_aligne(p)
	session.entries[0].inventaire.recevoir(ItemKind.BANANA, 0.0)
	karts[0].demande_objet = true
	karts[0].objet_tenu_presse = true
	objets.avancer(p, 1.0 / 60.0)
	assert_true(session.entries[0].inventaire.tenu)
	assert_true(objets.bananes.is_empty(), "rien n'est encore posé")
	objets.avancer(p, 1.0)
	assert_true(session.entries[0].inventaire.tenu, "toujours tenu tant que le bouton l'est")


func test_une_banane_tenue_puis_lachee_part_devant() -> void:
	_monter(1)
	var p := _positions_neutres()
	_aligne(p)
	session.entries[0].inventaire.recevoir(ItemKind.BANANA, 0.0)
	_tenir(p, 0.6, false)
	assert_eq(objets.bananes.size(), 1)
	assert_gt(_ecart(objets.bananes[0].position, p[0]), 10.0, "lancée loin devant")
	assert_true(session.entries[0].inventaire.est_vide())


func test_une_banane_tenue_lachee_en_freinant_tombe_derriere() -> void:
	_monter(1)
	var p := _positions_neutres()
	_aligne(p)
	session.entries[0].inventaire.recevoir(ItemKind.BANANA, 0.0)
	_tenir(p, 0.6, true)
	assert_lt(_ecart(objets.bananes[0].position, p[0]), -1.0)


func test_un_appui_bref_garde_l_usage_habituel() -> void:
	_monter(1)
	var p := _positions_neutres()
	_aligne(p)
	session.entries[0].inventaire.recevoir(ItemKind.BANANA, 0.0)
	_tenir(p, 0.1, false)
	assert_lt(_ecart(objets.bananes[0].position, p[0]), -1.0, "tapé : derrière, comme toujours")


func test_une_carapace_lachee_en_freinant_part_derriere() -> void:
	_monter(1)
	var p := _positions_neutres()
	_aligne(p)
	session.entries[0].inventaire.recevoir(ItemKind.GREEN_SHELL, 0.0)
	_tenir(p, 0.6, true)
	assert_eq(objets.carapaces.size(), 1)
	assert_lt(_ecart(objets.carapaces[0].position, p[0]), 0.0)
	assert_lt(objets.carapaces[0].direction.dot(_piste().forward_at(_piste().distance_of(p[0]))), 0.0,
		"et file vers l'arrière")


func test_la_rouge_lancee_derriere_ne_poursuit_personne() -> void:
	_monter(2)
	var p := _positions_neutres()
	_aligne(p)
	session.entries[0].inventaire.recevoir(ItemKind.RED_SHELL, 0.0)
	_tenir(p, 0.6, true)
	assert_null(objets.carapaces[0].cible)


func test_l_objet_tenu_arrete_une_carapace() -> void:
	_monter(1)
	var p := _positions_neutres()
	_aligne(p)
	session.entries[0].inventaire.recevoir(ItemKind.BANANA, 0.0)
	karts[0].demande_objet = true
	karts[0].objet_tenu_presse = true
	objets.avancer(p, 1.0 / 60.0)
	var avant := _piste().forward_at(_piste().distance_of(p[0]))
	var traine := p[0] - avant * ItemManager.DISTANCE_TRAINE
	objets.lancer_carapace(traine - avant * 3.0, avant, null, null)
	for i in 10:
		objets.avancer(p, 1.0 / 60.0)
	assert_true(objets.carapaces.is_empty(), "la carapace s'est brisée sur la banane")
	assert_true(session.entries[0].inventaire.est_vide(), "et la banane avec")
	assert_ne(karts[0].motor.state, KartMotor.State.STUNNED, "le kart n'a rien")


func test_percuter_l_objet_tenu_d_un_autre_fait_un_tete_a_queue() -> void:
	_monter(2)
	var p := _positions_neutres()
	_aligne(p)
	session.entries[0].inventaire.recevoir(ItemKind.BANANA, 0.0)
	karts[0].demande_objet = true
	karts[0].objet_tenu_presse = true
	objets.avancer(p, 1.0 / 60.0)
	p[1] = p[0] - _piste().forward_at(_piste().distance_of(p[0])) * ItemManager.DISTANCE_TRAINE
	objets.avancer(p, 1.0 / 60.0)
	assert_eq(karts[1].motor.state, KartMotor.State.STUNNED)
	assert_true(session.entries[0].inventaire.est_vide())


func test_sonne_on_lache_ce_qu_on_traine() -> void:
	_monter(1)
	var p := _positions_neutres()
	session.entries[0].inventaire.recevoir(ItemKind.GREEN_SHELL, 0.0)
	karts[0].demande_objet = true
	karts[0].objet_tenu_presse = true
	objets.avancer(p, 1.0 / 60.0)
	objets._toucher(session.entries[0])
	assert_true(session.entries[0].inventaire.est_vide())


func test_sans_objet_le_bouton_klaxonne() -> void:
	_monter(1)
	watch_signals(objets)
	var p := _positions_neutres()
	karts[0].demande_objet = true
	objets.avancer(p, 1.0 / 60.0)
	assert_signal_emit_count(objets, "klaxon", 1)
	karts[0].demande_objet = true
	objets.avancer(p, 1.0 / 60.0)
	assert_signal_emit_count(objets, "klaxon", 1, "pas une sirène")
	objets.avancer(p, ItemManager.REPOS_KLAXON)
	karts[0].demande_objet = true
	objets.avancer(p, 1.0 / 60.0)
	assert_signal_emit_count(objets, "klaxon", 2)


func test_l_ia_en_tete_traine_sa_banane_puis_la_lache_derriere() -> void:
	var ia := AIInput.new()
	a_liberer.append(ia)
	ia.objet_pret = ItemKind.BANANA
	ia.en_tete = true
	ia.ecart_poursuivant = 40.0
	ia._objet(1.0 / 60.0)
	assert_true(ia.command.use_item and ia.command.item_held, "elle la garde derrière")
	ia.command.clear()
	ia.objet_tenu = true
	ia.ecart_poursuivant = 5.0
	ia._objet(0.5)
	assert_false(ia.command.item_held, "un poursuivant approche : elle la lâche")
	assert_true(ia.command.throw_back, "derrière elle")


func test_un_klaxon_se_synthetise() -> void:
	var son := Synth.klaxon()
	assert_gt(son.data.size(), 1000)


# --- L'IA dans la course -----------------------------------------------------

func test_l_ia_les_mains_vides_vise_la_boite_la_plus_proche_devant() -> void:
	_monter(1)
	var rangee := _piste().length * 0.25
	var visee := objets.boite_visee(rangee - 20.0, 5.0)
	assert_false(is_nan(visee), "une rangée vingt mètres devant se voit")
	assert_gt(visee, 2.0, "dans la rangée, celle qui demande le moins de détour")
	assert_true(is_nan(objets.boite_visee(rangee + 10.0)), "une rangée passée ne compte plus")
	assert_true(is_nan(objets.boite_visee(rangee - ItemManager.PORTEE_BOITE_IA - 5.0)),
		"ni une rangée trop loin")
	for b in objets.boites:
		b.attente = ItemManager.REAPPARITION
	assert_true(is_nan(objets.boite_visee(rangee - 20.0)), "ni des boîtes déjà prises")


func test_la_session_raconte_la_course_a_l_ia() -> void:
	_monter(3)
	var ia := AIInput.new()
	a_liberer.append(ia)
	ia.kart = karts[1]
	session.brancher_ia(ia)
	session.entries[2].lateral = 3.5
	session.partager_la_course()
	assert_eq(ia.voisins.size(), 3, "un état par concurrent")
	assert_eq(ia.mon_index, 1, "et sa propre place dans le tableau")
	assert_almost_eq(ia.voisins[2].y, 3.5, 0.001, "avec l'écart latéral de chacun")


func test_les_rampes_et_les_trous_sont_des_zones_prudentes() -> void:
	_monter(1)
	var trou := TrackGap.new()
	trou.debut = 100.0
	trou.longueur = 10.0
	track.add_child(trou)
	var zones := track.zones_prudentes()
	assert_eq(zones.size(), 1)
	assert_almost_eq(zones[0].x, 100.0 - Track.ELAN_PRUDENT, 0.001, "dès l'élan")
	assert_almost_eq(zones[0].y, 110.0 + Track.RETOMBEE_PRUDENTE, 0.001, "jusqu'à la retombée")


func test_les_plaques_d_acceleration_sont_donnees_a_l_ia() -> void:
	_monter(1)
	var plaque := TrackBoost.new()
	plaque.debut = 50.0
	plaque.decalage = -3.0
	track.add_child(plaque)
	var plaques := track.plaques_d_acceleration()
	assert_eq(plaques.size(), 1)
	assert_almost_eq(plaques[0].x, 50.0, 0.001)
	assert_almost_eq(plaques[0].z, -3.0, 0.001)
