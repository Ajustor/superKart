extends GutTest

## Les objets venus après les premiers : l'éclair, l'étoile, la carapace
## bleue, la fausse boîte et les pièces.

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


## Donne l'objet au kart `i` et le lui fait utiliser.
func _utiliser(i: int, objet: int, p: Array[Vector3]) -> void:
	var e := session.entries[i]
	e.inventaire.vider()
	e.inventaire.recevoir(objet, 0.0)
	e.kart.demande_objet = true
	objets.avancer(p, 1.0 / 60.0)


# --- Catalogue ----------------------------------------------------------------

func test_chaque_objet_a_un_nom_et_une_colonne() -> void:
	for objet in ItemKind.TIRABLES:
		assert_ne(ItemKind.nom(objet), "", str(objet))
	for ligne in ItemTable.new().lignes:
		assert_eq(ligne.size(), ItemKind.TIRABLES.size(), "une colonne par objet")


func test_le_premier_n_a_ni_bleue_ni_eclair_ni_etoile() -> void:
	var t := ItemTable.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 2000:
		assert_does_not_have([ItemKind.BLUE_SHELL, ItemKind.LIGHTNING, ItemKind.STAR], t.tirer(1, 8, rng))


# --- Étoile -------------------------------------------------------------------

func test_l_etoile_rend_intouchable_et_plus_rapide() -> void:
	var m := KartMotor.new(KartStats.new())
	var normale := m.vitesse_de_pointe()
	m.prendre_etoile()
	assert_false(m.stun(), "rien ne touche un kart sous étoile")
	assert_false(m.foudroyer())
	var cmd := KartCommand.new()
	cmd.throttle = 1.0
	for i in 240:
		m.step(cmd, 1.0 / 60.0)
	assert_gt(m.speed, normale * 1.1, "plus vite que sa vitesse de pointe")
	for i in int(KartMotor.DUREE_ETOILE * 60.0):
		m.step(cmd, 1.0 / 60.0)
	assert_eq(m.etoile, 0.0)
	assert_true(m.stun(), "l'étoile finie, on redevient vulnérable")


func test_l_etoile_arrete_un_tete_a_queue() -> void:
	var m := KartMotor.new(KartStats.new())
	m.stun()
	m.prendre_etoile()
	assert_ne(m.state, KartMotor.State.STUNNED)


func test_sous_etoile_on_renverse_ce_qu_on_touche() -> void:
	var etoile := _kart()
	var autre := _kart()
	a_liberer.append_array([etoile, autre])
	etoile.motor.prendre_etoile()
	etoile.position = Vector3.ZERO
	autre.position = Vector3(0.8, 0, 0)
	KartCollisions.resoudre([etoile, autre] as Array[Kart])
	assert_eq(autre.motor.state, KartMotor.State.STUNNED)
	assert_ne(etoile.motor.state, KartMotor.State.STUNNED)


func test_utiliser_l_etoile() -> void:
	_monter(2)
	_utiliser(0, ItemKind.STAR, _positions_neutres())
	assert_gt(karts[0].motor.etoile, 0.0)


# --- Éclair -------------------------------------------------------------------

func test_l_eclair_frappe_tous_les_autres() -> void:
	_monter(4)
	var p := _positions_neutres()
	session.entries[2].inventaire.recevoir(ItemKind.RED_SHELL, 0.0)
	karts[3].motor.prendre_etoile()
	watch_signals(objets)
	_utiliser(0, ItemKind.LIGHTNING, p)
	assert_ne(karts[0].motor.state, KartMotor.State.STUNNED, "pas le lanceur")
	assert_eq(karts[0].motor.retreci, 0.0)
	for i in [1, 2]:
		assert_eq(karts[i].motor.state, KartMotor.State.STUNNED, "kart %d" % i)
		assert_gt(karts[i].motor.retreci, 0.0, "kart %d rétréci" % i)
	assert_true(session.entries[2].inventaire.est_vide(), "son objet s'envole")
	assert_eq(karts[3].motor.retreci, 0.0, "l'étoile protège de l'éclair")
	assert_signal_emit_count(objets, "kart_foudroye", 2)


func test_un_kart_retreci_roule_moins_vite() -> void:
	var m := KartMotor.new(KartStats.new())
	var normale := m.vitesse_de_pointe()
	m.foudroyer()
	assert_lt(m.vitesse_de_pointe(), normale * 0.8)
	var cmd := KartCommand.new()
	for i in int((KartMotor.DUREE_RETRECI + 0.1) * 60.0):
		m.step(cmd, 1.0 / 60.0)
	assert_almost_eq(m.vitesse_de_pointe(), normale, 0.001, "il regrandit")


# --- Pièces -------------------------------------------------------------------

func test_les_pieces_donnent_de_la_vitesse_et_se_perdent_au_choc() -> void:
	var m := KartMotor.new(KartStats.new())
	var normale := m.vitesse_de_pointe()
	for i in 8:
		m.gagner_pieces(2)
	assert_eq(m.pieces, KartMotor.PIECES_MAX, "plafonnées")
	assert_almost_eq(m.vitesse_de_pointe(), normale * (1.0 + KartMotor.BONUS_PAR_PIECE * KartMotor.PIECES_MAX), 0.001)
	m.stun()
	assert_eq(m.pieces, KartMotor.PIECES_MAX - KartMotor.PIECES_PERDUES)
	m.reset(0.0)
	assert_eq(m.pieces, KartMotor.PIECES_MAX - 2 * KartMotor.PIECES_PERDUES, "une remise en piste aussi")


func test_utiliser_des_pieces() -> void:
	_monter(1)
	_utiliser(0, ItemKind.COINS, _positions_neutres())
	assert_eq(karts[0].motor.pieces, ItemManager.PIECES_PAR_OBJET)


# --- Fausse boîte -------------------------------------------------------------

func test_la_fausse_boite_se_pose_derriere_et_fait_tourner() -> void:
	_monter(2)
	var p := _positions_neutres()
	_utiliser(0, ItemKind.FAKE_BOX, p)
	assert_eq(objets.bananes.size(), 1)
	var fausse := objets.bananes[0]
	assert_true(fausse.fausse)
	# Le kart 1 roule dessus, une fois passé le délai de grâce du lanceur.
	p[1] = fausse.position + Vector3(0.5, 0, 0)
	objets.avancer(p, 1.0 / 60.0)
	assert_eq(karts[1].motor.state, KartMotor.State.STUNNED)
	assert_true(objets.bananes.is_empty())


func test_la_fausse_boite_voyage_sur_le_reseau() -> void:
	_monter(1)
	objets.poser_banane(_sur_route(100.0), null, true)
	objets.poser_banane(_sur_route(120.0), null)
	var client := ItemManager.new()
	a_liberer.append(client)
	client.preparer(session, PackedFloat32Array())
	client.appliquer_instantane(objets.instantane())
	assert_eq(client.bananes.size(), 2)
	assert_true(client.bananes[0].fausse)
	assert_false(client.bananes[1].fausse)


# --- Carapace bleue -----------------------------------------------------------

func test_la_bleue_vise_le_premier_et_survole_les_autres() -> void:
	_monter(3)
	# Le 0 mène, 60 m devant le 1 ; le 2, dernier, lance la bleue.
	session.entries[0].progress.total = 160.0
	session.entries[0].progress.distance = 160.0
	session.entries[1].progress.total = 100.0
	session.entries[1].progress.distance = 100.0
	session.entries[2].progress.total = 40.0
	session.entries[2].progress.distance = 40.0
	session.classer()
	assert_eq(objets.cible_bleue(session.entries[2]), session.entries[0])
	assert_eq(objets.cible_bleue(session.entries[0]), session.entries[1], "lancée par le premier : le second")
	var p := _positions_neutres()
	p[0] = _sur_route(160.0)
	p[1] = _sur_route(100.0)
	p[2] = _sur_route(40.0, 3.0)
	# Un kart à côté du premier est pris dans l'explosion.
	watch_signals(objets)
	var c := objets.lancer_carapace(_sur_route(42.0), _piste().forward_at(42.0), session.entries[2],
		objets.cible_bleue(session.entries[2]), true)
	assert_true(c.bleue)
	assert_false(c.rouge)
	for i in 600:
		objets.avancer(p, 1.0 / 60.0)
		if objets.carapaces.is_empty():
			break
	assert_eq(karts[0].motor.state, KartMotor.State.STUNNED, "le premier saute")
	assert_ne(karts[1].motor.state, KartMotor.State.STUNNED, "survolé sans être touché")
	assert_signal_emitted(objets, "explosion")


func test_l_explosion_prend_ceux_qui_collent_au_premier() -> void:
	_monter(3)
	session.entries[0].progress.total = 100.0
	session.entries[0].progress.distance = 100.0
	session.classer()
	var p := _positions_neutres()
	p[0] = _sur_route(100.0)
	p[1] = _sur_route(101.5, 2.0)
	var c := objets.lancer_carapace(_sur_route(99.0), _piste().forward_at(99.0), session.entries[2],
		session.entries[0], true)
	c.position = p[0]
	objets.avancer(p, 1.0 / 60.0)
	assert_eq(karts[0].motor.state, KartMotor.State.STUNNED)
	assert_eq(karts[1].motor.state, KartMotor.State.STUNNED, "trop près du premier")
	assert_ne(karts[2].motor.state, KartMotor.State.STUNNED)


func test_la_bleue_voyage_sur_le_reseau_et_explose_chez_le_client() -> void:
	_monter(2)
	var c := objets.lancer_carapace(_sur_route(50.0), _piste().forward_at(50.0), session.entries[1],
		session.entries[0], true)
	var client := ItemManager.new()
	a_liberer.append(client)
	client.preparer(session, PackedFloat32Array())
	client.appliquer_instantane(objets.instantane())
	assert_eq(client.carapaces.size(), 1)
	assert_true(client.carapaces[0].bleue)
	assert_ne(c, null)
	objets.carapaces.clear()
	client.appliquer_instantane(objets.instantane())
	assert_true(client.carapaces.is_empty())


# --- Réseau : l'instantané du kart porte l'étoile et l'éclair ---------------------

func test_l_instantane_du_kart_porte_etoile_et_retreci() -> void:
	var k := _kart()
	a_liberer.append(k)
	k.motor.prendre_etoile()
	k.motor.retreci = 2.0
	var etat := KartSnapshot.capturer(3, k)
	var copie := _kart()
	a_liberer.append(copie)
	KartSnapshot.appliquer(etat, copie)
	assert_almost_eq(copie.motor.etoile, KartMotor.DUREE_ETOILE, 0.001)
	assert_almost_eq(copie.motor.retreci, 2.0, 0.001)
