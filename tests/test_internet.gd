extends GutTest

## Le jeu par Internet : l'adresse à taper (avec son port), et l'ouverture du
## port de l'hôte sur sa box.


func test_une_adresse_avec_son_port() -> void:
	assert_eq(Reseau.decouper_adresse("82.64.1.2:9000"), ["82.64.1.2", 9000])
	assert_eq(Reseau.decouper_adresse("  192.168.1.20 "), ["192.168.1.20", Reseau.PORT])
	assert_eq(Reseau.decouper_adresse("kart.exemple.fr:8910"), ["kart.exemple.fr", 8910])
	assert_eq(Reseau.decouper_adresse("::1"), ["::1", Reseau.PORT], "une IPv6 n'a pas de port à découper")
	assert_eq(Reseau.decouper_adresse("hote:abc"), ["hote:abc", Reseau.PORT])


func test_les_adresses_qu_on_ne_joint_pas_depuis_internet() -> void:
	for ip in ["10.0.0.1", "192.168.1.1", "172.16.4.2", "100.72.3.4", "127.0.0.1"]:
		assert_true(PortInternet.adresse_privee(ip), ip)
	for ip in ["82.64.1.2", "172.32.0.1", "100.128.0.1", "8.8.8.8"]:
		assert_false(PortInternet.adresse_privee(ip), ip)


func test_ce_que_le_salon_affiche() -> void:
	var p := PortInternet.new()
	add_child_autofree(p)
	assert_eq(p.texte(), "", "rien tant qu'on n'héberge pas")
	p.etat = PortInternet.Etat.OUVERT
	p.adresse = "82.64.1.2:8910"
	assert_string_contains(p.texte(), "82.64.1.2:8910")
	p.message = "CGNAT"
	assert_string_contains(p.texte(), "CGNAT")
	p.etat = PortInternet.Etat.ECHEC
	p.message = "Box introuvable"
	assert_string_contains(p.texte(), "Box introuvable")
	p.etat = PortInternet.Etat.INACTIF


func test_l_ouverture_finit_toujours_par_une_reponse() -> void:
	# Sans box (en test, en général), c'est un échec expliqué ; avec une box
	# UPnP, une adresse. Jamais une attente sans fin.
	var p := PortInternet.new()
	add_child_autofree(p)
	watch_signals(p)
	p.ouvrir(Reseau.PORT + 7)
	await wait_for_signal(p.fini, 12.0)
	assert_signal_emitted(p, "fini")
	assert_true(p.etat == PortInternet.Etat.ECHEC or p.etat == PortInternet.Etat.OUVERT)
	assert_ne(p.texte(), "")
	p.fermer()
	assert_eq(p.etat, PortInternet.Etat.INACTIF)


func test_une_reponse_perimee_ne_touche_pas_a_la_nouvelle_demande() -> void:
	var p := PortInternet.new()
	add_child_autofree(p)
	# Une demande en cours (sans fil lancé : on simule ses réponses).
	p.etat = PortInternet.Etat.EN_COURS
	p._demande = 2
	p._port = Reseau.PORT
	p._terminer(UPNP.new(), {ok = true, ip = "82.64.1.2"}, Reseau.PORT, 1)
	assert_eq(p.etat, PortInternet.Etat.EN_COURS, "la réponse de la demande 1 est ignorée")
	assert_eq(p.adresse, "")
	p._terminer(UPNP.new(), {ok = true, ip = "82.64.1.2"}, Reseau.PORT, 2)
	assert_eq(p.etat, PortInternet.Etat.OUVERT, "celle de la demande 2 compte")
	assert_string_contains(p.adresse, "82.64.1.2")
	p._upnp = null
	p.etat = PortInternet.Etat.INACTIF
