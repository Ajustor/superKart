extends GutTest

## Le multijoueur, dans tout ce qui ne demande pas d'ouvrir un port : le
## salon, la grille, l'état d'un kart sur le fil, son interpolation, le
## montage d'une course en réseau et le comportement d'une session qui
## n'arbitre pas. Le réseau lui-même se vérifie à deux instances, avec
## tools/essai_reseau.gd.

var a_liberer: Array[Object] = []


func after_each() -> void:
	for o in a_liberer:
		if is_instance_valid(o):
			o.free()
	a_liberer.clear()


func _kart() -> Kart:
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	a_liberer.append(k)
	return k


# --- Salon ------------------------------------------------------------------------

func test_deux_joueurs_ne_portent_pas_le_meme_nom() -> void:
	var l := Lobby.new()
	assert_eq(l.ajouter(1, "Alex"), "Alex")
	assert_eq(l.ajouter(2, "Alex"), "Alex 2")
	assert_eq(l.ajouter(3, "Alex"), "Alex 3")


func test_un_pseudo_vide_ou_demesure_est_nettoye() -> void:
	assert_eq(Lobby.nettoyer("   "), "Pilote")
	assert_eq(Lobby.nettoyer("Un pseudo bien trop long pour la grille").length(), 16)
	assert_false(Lobby.nettoyer("a\nb").contains("\n"))


func test_le_salon_voyage_et_garde_son_ordre() -> void:
	var l := Lobby.new()
	l.ajouter(1, "Hôte")
	l.ajouter(77, "Bea")
	l.ajouter(12, "Cyril")
	var copie := Lobby.new()
	copie.depuis_liste(l.en_liste())
	assert_eq(copie.ordre, [1, 77, 12] as Array[int])
	assert_eq(copie.joueurs[77], "Bea")


func test_un_depart_libere_la_place() -> void:
	var l := Lobby.new()
	l.ajouter(1, "A")
	l.ajouter(2, "B")
	l.retirer(2)
	assert_eq(l.joueurs.size(), 1)
	assert_false(l.ordre.has(2))


func test_le_salon_est_plein_a_huit() -> void:
	var l := Lobby.new()
	for i in Lobby.PLACES:
		l.ajouter(i + 1, "J%d" % i)
	assert_true(l.est_plein())


# --- Grille ---------------------------------------------------------------------------

func _plan(humains: int, graine: int = 5) -> Array:
	var l := Lobby.new()
	for i in humains:
		l.ajouter(i + 1, "J%d" % i)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	return l.plan_de_course(rng)


func test_la_grille_a_toujours_huit_places() -> void:
	for n in range(1, Lobby.PLACES + 1):
		var plan := _plan(n)
		assert_eq(plan.size(), Lobby.PLACES)
		var humains := plan.filter(func(p: Dictionary) -> bool: return p.peer != 0)
		assert_eq(humains.size(), n, "%d humains sur la grille" % n)


func test_chaque_place_a_son_gid() -> void:
	var plan := _plan(3)
	for i in plan.size():
		assert_eq(plan[i].gid, i)


func test_l_ia_complete_de_la_plus_rapide_a_la_plus_lente() -> void:
	var plan := _plan(3)
	var niveaux := []
	for p in plan:
		if p.niveau_ia > 0:
			niveaux.append(p.niveau_ia)
	assert_eq(niveaux, [1, 2, 3, 4, 5], "la plus rapide devant, sans trou dans les niveaux")


func test_les_humains_sont_repartis_au_hasard() -> void:
	var places := {}
	for graine in 30:
		for p in _plan(1, graine):
			if p.peer != 0:
				places[p.gid] = true
	assert_gt(places.size(), 4, "un seul humain ne part pas toujours de la même case")


# --- L'état d'un kart sur le fil --------------------------------------------------------

func test_l_etat_d_un_kart_fait_l_aller_retour() -> void:
	var k := _kart()
	k.transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(12, 3, -40))
	k.motor.speed = 18.5
	k.motor.state = KartMotor.State.DRIFT
	k.motor.drift_dir = -1
	k.motor.boost_timer = 0.4
	var etat := KartSnapshot.capturer(4, k)
	assert_eq(etat.size(), KartSnapshot.TAILLE)

	var copie := _kart()
	KartSnapshot.appliquer(etat, copie)
	assert_almost_eq(copie.transform.origin.distance_to(Vector3(12, 3, -40)), 0.0, 0.001)
	assert_almost_eq(copie.motor.speed, 18.5, 0.001)
	assert_eq(copie.motor.state, KartMotor.State.DRIFT, "un kart distant qui glisse doit se voir glisser")
	assert_eq(copie.motor.drift_dir, -1)


func test_un_paquet_se_decoupe_kart_par_kart() -> void:
	var paquet := PackedFloat32Array()
	for gid in 3:
		paquet.append_array(KartSnapshot.capturer(gid, _kart()))
	var etats := KartSnapshot.decouper(paquet)
	assert_eq(etats.size(), 3)
	assert_eq(int(etats[2][KartSnapshot.GID]), 2)


func _etat_en(x: float) -> PackedFloat32Array:
	var k := _kart()
	k.transform.origin = Vector3(x, 0, 0)
	k.motor.speed = 10.0
	k.motor.velocity_dir = PI * 0.5   # vers +X
	return KartSnapshot.capturer(0, k)


func test_on_interpole_entre_deux_etats() -> void:
	var t := SnapshotBuffer.new()
	t.retard = 0.1
	t.ajouter(1.0, _etat_en(0.0))
	t.ajouter(1.1, _etat_en(1.0))
	var milieu := t.echantillonner(1.05 + t.retard)
	assert_almost_eq(KartSnapshot.position(milieu).x, 0.5, 0.01)


func test_sans_retard_on_montre_le_present() -> void:
	var t := SnapshotBuffer.new()
	t.ajouter(1.0, _etat_en(0.0))
	# Reçu 80 ms après avoir été pris : le kart a roulé entre-temps.
	var la := t.echantillonner(1.08)
	assert_almost_eq(KartSnapshot.position(la).x, 0.8, 0.01, "on le montre où il est, pas où il était")


func test_faute_de_nouvelles_on_prolonge_puis_on_attend() -> void:
	var t := SnapshotBuffer.new()
	t.ajouter(1.0, _etat_en(0.0))
	var un_peu_plus_tard := t.echantillonner(1.1)
	assert_almost_eq(KartSnapshot.position(un_peu_plus_tard).x, 1.0, 0.05, "il continue sur sa lancée")
	var bien_plus_tard := t.echantillonner(5.0)
	assert_almost_eq(KartSnapshot.position(bien_plus_tard).x, 10.0 * SnapshotBuffer.EXTRAPOLATION_MAX, 0.05,
		"mais pas indéfiniment")


func test_un_paquet_en_retard_est_jete() -> void:
	var t := SnapshotBuffer.new()
	t.ajouter(2.0, _etat_en(5.0))
	t.ajouter(1.0, _etat_en(0.0))
	assert_almost_eq(KartSnapshot.position(t.dernier()).x, 5.0, 0.001, "remonter le temps ferait reculer le kart")


func test_un_kart_qui_tourne_est_prolonge_en_virage() -> void:
	var k := _kart()
	k.motor.speed = 10.0
	var t := SnapshotBuffer.new()
	# Il tourne à droite à 1 rad/s : deux états à un dixième de seconde.
	for i in 2:
		k.motor.velocity_dir = 0.1 * i
		k.transform = Transform3D(Basis(Vector3.UP, -0.1 * i), Vector3.ZERO)
		t.ajouter(0.1 * i, KartSnapshot.capturer(0, k))
	var plus_tard := t.echantillonner(0.1 + SnapshotBuffer.EXTRAPOLATION_MAX)
	var cap := plus_tard[KartSnapshot.CAP_MARCHE]
	assert_almost_eq(cap, 0.1 + SnapshotBuffer.EXTRAPOLATION_MAX, 0.001, "il continue de tourner")
	assert_gt(KartSnapshot.position(plus_tard).x, 0.1, "vers la droite")
	# La caisse tourne avec sa trajectoire.
	var devant := -Basis(KartSnapshot.rotation(plus_tard)).z
	assert_almost_eq(devant.x, sin(cap), 0.001)
	assert_almost_eq(devant.z, -cos(cap), 0.001)


func test_un_arc_prolonge_garde_sa_longueur() -> void:
	var d := _etat_en(0.0)
	var droit := KartSnapshot.prolonger(d, 0.5)
	var courbe := KartSnapshot.prolonger(d, 0.5, 2.0)
	assert_almost_eq(KartSnapshot.position(droit).x, 5.0, 0.001)
	# Un radian d'arc sur un cercle de 5 m de rayon (10 m/s à 2 rad/s) :
	# la corde fait 2 · 5 · sin(0,5).
	assert_almost_eq(KartSnapshot.position(courbe).length(), 2.0 * 5.0 * sin(0.5), 0.001)


func test_une_prediction_dementie_est_rattrapee_en_douceur() -> void:
	var t := SnapshotBuffer.new()
	t.ajouter(1.0, _etat_en(0.0))
	var avant := KartSnapshot.position(t.echantillonner(1.1))
	# Le kart avait en fait freiné : il est un mètre moins loin que prévu.
	var freine := _etat_en(0.0)
	freine[KartSnapshot.VITESSE] = 0.0
	t.ajouter(1.05, freine, 1.1)
	var juste_apres := KartSnapshot.position(t.echantillonner(1.1))
	assert_almost_eq(juste_apres.x, avant.x, 0.001, "pas de saut à la réception")
	var bien_apres := KartSnapshot.position(t.echantillonner(1.6))
	assert_almost_eq(bien_apres.x, 0.0, 0.01, "l'écart est rattrapé")


func test_une_remise_en_piste_se_voit_tout_de_suite() -> void:
	var t := SnapshotBuffer.new()
	t.ajouter(1.0, _etat_en(0.0))
	t.echantillonner(1.02)
	t.ajouter(1.02, _etat_en(60.0), 1.02)
	assert_almost_eq(KartSnapshot.position(t.echantillonner(1.02)).x, 60.0, 0.001,
		"rattraper 60 m en douceur, ce serait voir le kart traverser le décor")


# --- Annonces sur le réseau local -------------------------------------------------------

func test_une_annonce_valide_est_lue() -> void:
	var infos := LanDiscovery.lire(JSON.stringify({jeu = "superkart", nom = "Alex", port = 8910, joueurs = 3}))
	assert_eq(infos.nom, "Alex")
	assert_eq(infos.port, 8910)
	assert_eq(infos.joueurs, 3)


func test_n_importe_quoi_sur_le_port_est_ignore() -> void:
	assert_true(LanDiscovery.lire("bonjour").is_empty())
	assert_true(LanDiscovery.lire(JSON.stringify({jeu = "autre", port = 1})).is_empty())
	assert_true(LanDiscovery.lire("[1, 2, 3]").is_empty())


# --- Monter une course en réseau ---------------------------------------------------------

func _plan_fixe() -> Array:
	# Deux humains : l'hôte (1) en case 5, un client (42) en pole ; l'IA ailleurs.
	var plan := []
	var niveau := 1
	for gid in Lobby.PLACES:
		if gid == 5:
			plan.append({gid = gid, peer = 1, nom = "Hôte", niveau_ia = 0})
		elif gid == 0:
			plan.append({gid = gid, peer = 42, nom = "Client", niveau_ia = 0})
		else:
			plan.append({gid = gid, peer = 0, nom = Lobby.NOMS_IA[niveau - 1], niveau_ia = niveau})
			niveau += 1
	return plan


func test_chaque_machine_pilote_son_propre_kart() -> void:
	var cote_hote := RaceLauncher.monter_reseau(_plan_fixe(), {piste = "circuit_01", tours = 2}, 1, true)
	var cote_client := RaceLauncher.monter_reseau(_plan_fixe(), {piste = "circuit_01", tours = 2}, 42, false)
	for course in [cote_hote, cote_client]:
		var session := course.get_node("Session") as RaceSession
		assert_eq(session.kart_paths[0], NodePath("../Kart"), "le joueur local est le kart de joueur")
		assert_eq(session.noms[0], "Vous")
		assert_eq(session.lap_count, 2)
		assert_eq(session.id_piste, "", "pas de record en réseau")
		assert_not_null(course.get_node_or_null("RaceSync"))
	var s_hote := cote_hote.get_node("Session") as RaceSession
	var s_client := cote_client.get_node("Session") as RaceSession
	assert_eq(s_hote.cases_imposees[0], 5, "l'hôte part de sa case")
	assert_eq(s_client.cases_imposees[0], 0, "le client de la sienne")
	assert_true(s_hote.arbitre)
	assert_false(s_client.arbitre)
	cote_hote.free()
	cote_client.free()


func test_l_hote_simule_l_ia_et_pas_les_autres_humains() -> void:
	var course := RaceLauncher.monter_reseau(_plan_fixe(), {piste = "circuit_01", tours = 3}, 1, true)
	var session := course.get_node("Session") as RaceSession
	var simules := 0
	for i in session.kart_paths.size():
		var kart := course.get_node(String(session.kart_paths[i]).trim_prefix("../")) as Kart
		var gid := session.cases_imposees[i]
		if gid == 0:
			assert_false(kart.simule, "le kart du client est piloté sur sa machine")
		else:
			assert_true(kart.simule, "le reste est simulé par l'hôte")
			simules += 1
	assert_eq(simules, 7)
	course.free()


func test_le_client_ne_simule_que_son_kart() -> void:
	var course := RaceLauncher.monter_reseau(_plan_fixe(), {piste = "circuit_01", tours = 3}, 42, false)
	var session := course.get_node("Session") as RaceSession
	for i in session.kart_paths.size():
		var kart := course.get_node(String(session.kart_paths[i]).trim_prefix("../")) as Kart
		assert_eq(kart.simule, i == 0, "seul son propre kart")
	assert_false((course.get_node("Objets") as ItemManager).autorite, "les objets viennent de l'hôte")
	course.free()


func test_tous_les_karts_de_la_scene_sont_distribues() -> void:
	var course := RaceLauncher.monter_reseau(_plan_fixe(), {piste = "circuit_01", tours = 3}, 1, true)
	var session := course.get_node("Session") as RaceSession
	var vus := {}
	for chemin in session.kart_paths:
		vus[chemin] = true
	assert_eq(vus.size(), Lobby.PLACES, "huit karts distincts, aucun en double")
	course.free()


# --- Une session qui n'arbitre pas ---------------------------------------------------------

func _anneau() -> Curve3D:
	var c := Curve3D.new()
	var rayon := 50.0
	var points := 16
	var pas := TAU / float(points)
	var poignee := rayon * (4.0 / 3.0) * tan(pas / 4.0)
	for i in points:
		var a := pas * float(i)
		var p := Vector3(sin(a) * rayon, 0.0, -cos(a) * rayon)
		var t := Vector3(cos(a), 0.0, sin(a)) * poignee
		c.add_point(p, -t, t)
	c.add_point(c.get_point_position(0), -c.get_point_out(0), c.get_point_out(0))
	return c


func _session_client() -> RaceSession:
	var track := Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	a_liberer.append(track)
	var session := RaceSession.new()
	a_liberer.append(session)
	session.duree_decompte = 0.0
	session.arbitre = false
	session.lap_count = 1
	var karts: Array[Kart] = [_kart(), _kart()]
	session.demarrer(track, karts)
	return session


func test_un_client_n_arbitre_pas_l_arrivee() -> void:
	var session := _session_client()
	var e := session.entries[0]
	var c := e.progress.track
	var d := 0.0
	while e.tours_comptes < 1:
		d += 0.5
		session.avancer(e, c.position_at(d), 1.0 / 60.0)
	assert_false(e.finished, "c'est l'hôte qui dit qui est arrivé")


func test_un_client_recopie_l_arrivee_annoncee() -> void:
	var session := _session_client()
	watch_signals(session)
	session.appliquer_arrivee(session.entries[1], 1, 41.5)
	assert_true(session.entries[1].finished)
	assert_eq(session.entries[1].place_finale, 1)
	assert_almost_eq(session.entries[1].temps_course, 41.5, 0.001)
	assert_signal_emit_count(session, "arrivee", 1)
	session.appliquer_arrivee(session.entries[1], 1, 41.5)
	assert_signal_emit_count(session, "arrivee", 1, "une arrivée annoncée deux fois n'arrive qu'une fois")


func test_un_client_garde_les_places_de_l_hote() -> void:
	var session := _session_client()
	session.entries[0].position = 2
	session.entries[1].position = 1
	session.entries[0].progress.total = 500.0
	session.classer()
	assert_eq(session.entries[0].position, 2, "le classement local ne réécrit pas celui de l'hôte")


func test_le_depart_attend_le_feu_vert_de_l_hote() -> void:
	var session := _session_client()
	session.en_course = false
	session.attente_depart = true
	session.decompte_restant = 3.0
	session.avancer_decompte(5.0)
	assert_false(session.en_course)
	session.attente_depart = false
	session.avancer_decompte(5.0)
	assert_true(session.en_course)


func test_un_kart_distant_n_est_pas_remis_en_piste_ici() -> void:
	var session := _session_client()
	var e := session.entries[1]
	e.kart.simule = false
	e.kart.motor.speed = 20.0
	var loin := e.progress.track.position_at(50.0) + Vector3(0, 0, 40)
	session.avancer(e, loin, 1.0 / 60.0)
	assert_eq(e.kart.motor.speed, 20.0, "c'est sa machine qui le remet en piste, pas nous")


# --- Les objets en miroir ---------------------------------------------------------------------

func test_les_objets_de_l_hote_se_recopient_chez_le_client() -> void:
	var session := _session_client()
	var hote := ItemManager.new()
	var client := ItemManager.new()
	a_liberer.append(hote)
	a_liberer.append(client)
	var rangee := PackedFloat32Array([0.25])
	hote.preparer(session, rangee)
	client.preparer(session, rangee)
	client.autorite = false
	var c := session.entries[0].progress.track
	hote.boites[1].attente = 1.0
	hote.poser_banane(c.position_at(40.0), null)
	hote.lancer_carapace(c.position_at(80.0), c.forward_at(80.0), null, session.entries[1])

	client.appliquer_instantane(hote.instantane())
	assert_false(client.boites[1].disponible(), "la boîte ramassée chez l'hôte l'est aussi ici")
	assert_true(client.boites[0].disponible())
	assert_eq(client.bananes.size(), 1)
	assert_eq(client.carapaces.size(), 1)
	assert_true(client.carapaces[0].rouge)
	assert_almost_eq(client.bananes[0].position.distance_to(hote.bananes[0].position), 0.0, 0.001)

	# Entre deux photos, la carapace continue sa route chez le client.
	var recue := client.carapaces[0].position
	client._prolonger_carapaces(0.1)
	assert_almost_eq(client.carapaces[0].position.distance_to(recue), ItemManager.VITESSE_CARAPACE * 0.1, 0.001)
	# Une photo vieille de 50 ms la montre déjà 50 ms plus loin.
	client.appliquer_instantane(hote.instantane(), 0.05)
	assert_almost_eq(client.carapaces[0].position.distance_to(hote.carapaces[0].position),
		ItemManager.VITESSE_CARAPACE * 0.05, 0.001)

	# La banane est ramassée, la carapace a disparu : le client suit.
	hote._retirer_banane(0)
	hote._retirer_carapace(0)
	client.appliquer_instantane(hote.instantane())
	assert_eq(client.bananes.size(), 0)
	assert_eq(client.carapaces.size(), 0)
