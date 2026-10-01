extends GutTest

## Le mode en ligne : le serveur dédié, le chef du salon, l'annuaire vu du jeu.


func test_les_arguments_du_serveur() -> void:
	var r := ServeurDedie.lire_arguments(PackedStringArray([
		"--serveur", "--port", "8931", "--nom", "  Chez Jo  ", "--code", "abcde", "--prive",
		"--annuaire", "http://127.0.0.1:8900/", "--jeton", "s3cret"]))
	assert_true(r.serveur)
	assert_eq(r.port, 8931)
	assert_eq(r.nom, "Chez Jo")
	assert_eq(r.code, "ABCDE")
	assert_true(r.prive)
	assert_false(r.permanent)
	assert_eq(r.annuaire, "http://127.0.0.1:8900", "sans la barre finale")
	assert_eq(r.jeton, "s3cret")


func test_sans_serveur_le_jeu_reste_un_jeu() -> void:
	var r := ServeurDedie.lire_arguments(PackedStringArray([]))
	assert_false(r.serveur)
	assert_eq(r.port, Reseau.PORT)
	assert_false(ServeurDedie.actif, "les tests ne tournent pas en serveur")


func test_un_nom_trop_long_ou_vide() -> void:
	assert_eq(ServeurDedie.lire_arguments(PackedStringArray(["--nom", "x".repeat(80)])).nom.length(), 32)
	assert_eq(ServeurDedie.lire_arguments(PackedStringArray(["--nom", "  "])).nom, "Salon SuperKart")


func test_le_chef_est_le_premier_arrive_encore_la() -> void:
	var lobby := Lobby.new()
	assert_eq(lobby.chef(), 0, "salon vide : pas de chef")
	lobby.ajouter(7, "Jo")
	lobby.ajouter(9, "Lou")
	assert_eq(lobby.chef(), 7)
	lobby.retirer(7)
	assert_eq(lobby.chef(), 9, "le suivant prend la main")


func test_hors_ligne_personne_ne_dirige() -> void:
	assert_false(Reseau.actif())
	assert_false(Reseau.peut_diriger())
	assert_false(Reseau.en_ligne())


func _salon(reglages: Dictionary) -> Dictionary:
	var s := {code = "ABCDE", nom = "S", hote = "jeu.exemple.org", port = 8910, prive = false,
		joueurs = 1, places = 8, en_course = false, version = Reseau.VERSION, ouvert = true}
	s.merge(reglages, true)
	return s


func test_la_partie_rapide_remplit_le_salon_le_plus_frequente() -> void:
	var salons := [
		_salon({code = "AAAAA", joueurs = 2}),
		_salon({code = "BBBBB", joueurs = 5}),
		_salon({code = "CCCCC", joueurs = 7, en_course = true}),
		_salon({code = "DDDDD", joueurs = 8}),
		_salon({code = "EEEEE", joueurs = 6, version = Reseau.VERSION + 1}),
		_salon({code = "FFFFF", joueurs = 6, prive = true}),
		_salon({code = "GGGGG", joueurs = 6, ouvert = false}),
	]
	assert_eq(EnLigne.choisir_pour_partie_rapide(salons).code, "BBBBB")
	assert_true(EnLigne.choisir_pour_partie_rapide([salons[2], salons[3]]).is_empty(),
		"rien de libre : on crée un salon")


func test_un_code_de_salon() -> void:
	assert_true(EnLigne.code_valide("AB2CD"))
	assert_false(EnLigne.code_valide("AB2C"))
	assert_false(EnLigne.code_valide("AB/CD"))
	assert_false(EnLigne.code_valide("ab2cd"), "le code se met en majuscules avant")


func test_l_adresse_de_l_annuaire() -> void:
	assert_eq(EnLigne.completer_url("superkart.exemple.org"), "https://superkart.exemple.org")
	assert_eq(EnLigne.completer_url("superkart.exemple.org/"), "https://superkart.exemple.org")
	assert_eq(EnLigne.completer_url("192.168.1.20:8900"), "http://192.168.1.20:8900")
	assert_eq(EnLigne.completer_url("localhost:8900"), "http://localhost:8900")
	assert_eq(EnLigne.completer_url("http://jeu.exemple.org"), "http://jeu.exemple.org")
	assert_eq(EnLigne.completer_url(""), "")


func test_la_liste_des_salons() -> void:
	assert_eq(MultiplayerPanel.texte_salon(_salon({nom = "Chez Jo", joueurs = 3})), "Chez Jo — 3/8 joueurs")
	assert_string_contains(MultiplayerPanel.texte_salon(_salon({en_course = true, piste = "Grand Huit"})),
		"en course : Grand Huit")
	assert_true(MultiplayerPanel.salon_joignable(_salon({})))
	assert_false(MultiplayerPanel.salon_joignable(_salon({joueurs = 8})))
	assert_false(MultiplayerPanel.salon_joignable(_salon({version = 1})))


func test_le_code_s_affiche_dans_le_salon() -> void:
	assert_eq(MultiplayerPanel.texte_code({}), "")
	assert_eq(MultiplayerPanel.texte_code({code = "ABCDE"}), "Code du salon : ABCDE")
	assert_string_contains(MultiplayerPanel.texte_code({code = "ABCDE", prive = true}), "privé")


func _plan_sans_le_serveur() -> Array:
	# Un salon en ligne : deux joueurs (7 et 9), l'IA ailleurs ; le serveur
	# (peer 1) n'a pas de place.
	var plan := []
	var niveau := 1
	for gid in Lobby.PLACES:
		if gid == 2:
			plan.append({gid = gid, peer = 7, nom = "Jo", niveau_ia = 0})
		elif gid == 4:
			plan.append({gid = gid, peer = 9, nom = "Lou", niveau_ia = 0})
		else:
			plan.append({gid = gid, peer = 0, nom = Lobby.NOMS_IA[niveau - 1], niveau_ia = niveau})
			niveau += 1
	return plan


func test_le_serveur_simule_tout_sans_piloter() -> void:
	var course := RaceLauncher.monter_reseau(_plan_sans_le_serveur(), {piste = "circuit_01", tours = 2}, 1, true)
	var session := course.get_node("Session") as RaceSession
	assert_true(session.arbitre)
	assert_eq(session.kart_paths.size(), Lobby.PLACES, "toute la grille est là")
	var simules := 0
	for i in session.kart_paths.size():
		var kart := course.get_node(String(session.kart_paths[i]).trim_prefix("../")) as Kart
		var gid := session.cases_imposees[i]
		if gid == 2 or gid == 4:
			assert_false(kart.simule, "les joueurs pilotent chez eux")
		else:
			simules += 1
	assert_eq(simules, 6, "l'IA tourne sur le serveur")
	course.free()


func test_le_champ_remonte_au_dessus_du_clavier() -> void:
	# Écran de jeu haut de 720, fenêtre de 1080 pixels, clavier de 540 : le
	# clavier couvre la moitié basse, à partir de 360.
	assert_eq(MultiplayerPanel.decalage_pour_clavier(300.0, 720.0, 540, 1080), 0.0, "déjà visible")
	assert_almost_eq(MultiplayerPanel.decalage_pour_clavier(500.0, 720.0, 540, 1080), 156.0, 0.01)
	assert_eq(MultiplayerPanel.decalage_pour_clavier(500.0, 720.0, 0, 1080), 0.0, "pas de clavier")
