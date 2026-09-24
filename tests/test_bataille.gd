extends GutTest

## Le mode bataille : trois ballons, un de moins par objet encaissé, et le
## dernier en lice gagne.

var bataille: Bataille
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
	bataille = null


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


func _en_bataille(combien: int) -> void:
	_monter(combien, PackedFloat32Array())
	objets.bataille = true
	objets.table = Bataille.table()
	session.sans_tours = true
	bataille = Bataille.new()
	a_liberer.append(bataille)
	bataille.preparer(session, objets)


func _toucher(i: int) -> void:
	# Un objet qui touche : le tête-à-queue, puis on se relève.
	objets._toucher(session.entries[i])
	karts[i].motor.stun_timer = 0.0
	karts[i].motor.state = KartMotor.State.GRIP


func test_trois_ballons_au_depart() -> void:
	_en_bataille(4)
	for e in session.entries:
		assert_eq(bataille.ballons[e], Bataille.BALLONS)
		assert_eq(e.kart.get_node("Ballons").get_child_count(), Bataille.BALLONS)


func test_chaque_objet_encaisse_creve_un_ballon() -> void:
	_en_bataille(4)
	watch_signals(bataille)
	_toucher(1)
	assert_eq(bataille.ballons[session.entries[1]], 2)
	assert_false((karts[1].get_node("Ballons").get_child(2) as Node3D).visible)
	assert_signal_emitted(bataille, "ballon_perdu")


func test_sans_ballon_on_est_elimine_et_classe_derriere() -> void:
	_en_bataille(4)
	for n in Bataille.BALLONS:
		_toucher(2)
	var e := session.entries[2]
	assert_true(e.finished)
	assert_eq(e.place_finale, 4, "le premier éliminé est dernier")
	assert_eq(bataille.vivants().size(), 3)
	assert_false(karts[2].controle_actif)
	_toucher(2)
	assert_eq(bataille.ballons[e], 0, "on ne crève pas un ballon qu'on n'a plus")


func test_le_dernier_en_lice_gagne() -> void:
	_en_bataille(3)
	for i in [1, 2]:
		for n in Bataille.BALLONS:
			_toucher(i)
	assert_eq(bataille.vivants().size(), 1)
	bataille.terminer()
	assert_eq(session.entries[0].place_finale, 1)
	assert_eq(session.entries[1].place_finale, 3, "éliminé le premier")
	assert_eq(session.entries[2].place_finale, 2)
	assert_true(session.terminee)


func test_au_bout_du_temps_on_compte_les_ballons() -> void:
	_en_bataille(3)
	_toucher(0)
	_toucher(0)
	_toucher(2)
	bataille.terminer()
	assert_eq(session.entries[1].place_finale, 1, "trois ballons")
	assert_eq(session.entries[2].place_finale, 2, "deux")
	assert_eq(session.entries[0].place_finale, 3, "un seul")


func test_un_elimine_n_encaisse_ni_ne_lance_plus_rien() -> void:
	_en_bataille(2)
	for n in Bataille.BALLONS:
		_toucher(1)
	var p := _positions_neutres()
	var b := objets.poser_banane(p[1], null)
	session.entries[1].inventaire.recevoir(ItemKind.GREEN_SHELL, 0.0)
	karts[1].demande_objet = true
	objets.avancer(p, 1.0 / 60.0)
	assert_eq(objets.bananes.size(), 1, "la banane reste : il roule au travers")
	assert_true(objets.carapaces.is_empty(), "il ne lance plus")
	assert_ne(b, null)


func test_la_table_de_bataille() -> void:
	var t := Bataille.table()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 1000:
		assert_does_not_have([ItemKind.BLUE_SHELL, ItemKind.LIGHTNING, ItemKind.COINS], t.tirer(1 + i % 8, 8, rng))


func test_la_rouge_vise_le_plus_proche_devant() -> void:
	_en_bataille(3)
	karts[1].position = Vector3(0, 0, -10)
	karts[2].position = Vector3(0, 0, -30)
	assert_eq(objets.cible_proche(session.entries[0], Vector3.ZERO, Vector3(0, 0, -1)), session.entries[1])
	assert_null(objets.cible_proche(session.entries[0], Vector3.ZERO, Vector3(0, 0, 1)), "personne derrière")


func test_pas_de_tours_en_bataille() -> void:
	_en_bataille(1)
	var e := session.entries[0]
	e.progress.lap = 5
	session.avancer(e, _sur_route(10.0), 1.0 / 60.0)
	assert_eq(e.tours_comptes, 0)
	assert_false(e.finished)


func test_la_course_de_bataille() -> void:
	var r := RaceSetup.new()
	r.mode = RaceSetup.Mode.BATAILLE
	r.choisir_piste(TrackCatalog.ARENES[0])
	assert_eq(r.cle_record(), "", "pas de record en bataille")
	var course := RaceLauncher.monter(r)
	assert_not_null(course.get_node_or_null("Bataille"))
	assert_null(course.get_node_or_null("GridMarkings"), "ni grille ni portique")
	assert_true((course.get_node("Session") as RaceSession).sans_tours)
	assert_true((course.get_node("Objets") as ItemManager).bataille)
	assert_eq(TrackCatalog.par_id("arene_ovale"), TrackCatalog.ARENES[0])
	assert_does_not_have(TrackCatalog.PISTES, TrackCatalog.ARENES[0], "pas au menu des courses")
	course.free()


func test_la_bataille_se_joue_jusqu_au_bout() -> void:
	var r := RaceSetup.new()
	r.mode = RaceSetup.Mode.BATAILLE
	r.choisir_piste(TrackCatalog.ARENES[0])
	var course := RaceLauncher.monter(r)
	var s := course.get_node("Session") as RaceSession
	s.duree_decompte = 0.0
	add_child_autofree(course)
	var b := course.get_node("Bataille") as Bataille
	await wait_until(func() -> bool: return s.en_course, 3.0)
	# Le temps presque écoulé : la fin tombe à la prochaine image.
	b.temps_restant = 0.01
	await wait_until(func() -> bool: return s.terminee, 2.0)
	assert_true(s.terminee)
	var places := []
	for e in s.entries:
		places.append(e.place_finale)
	places.sort()
	assert_eq(places, [1, 2, 3, 4, 5, 6, 7, 8])
