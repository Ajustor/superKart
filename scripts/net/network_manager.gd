extends Node

## Le multijoueur en réseau : héberger, rejoindre, tenir le salon, lancer la
## course. Déclaré en autoload sous le nom `Reseau`, pour que les appels RPC
## trouvent le même nœud au même chemin sur toutes les machines.
##
## L'hôte est aussi un joueur (peer 1). Il tient le salon, choisit le circuit,
## et arbitre la course ; les autres rejoignent par son adresse IP, ou le
## trouvent sur le réseau local.

signal salon_change
signal erreur(message: String)
signal connecte
signal deconnecte(raison: String)
## La dernière manche d'une coupe est comptée : chacun montre le podium.
signal podium
## Un joueur de plus a fini de charger la course (voir `charges`).
signal charges_changes
## L'hôte donne le départ : tout le monde a chargé, ou l'attente a trop duré.
signal depart

const PORT := 8910
## Monté à chaque changement du protocole : un client d'une autre version est
## refusé poliment plutôt que de désynchroniser la course en silence.
const VERSION := 5

## Pas de coupe : une course seule.
const SANS_COUPE := -1

var lobby := Lobby.new()
var config: Dictionary = {piste = "", tours = 3, cylindree = Cylindree.Classe.CC150, coupe = SANS_COUPE}
var en_course: bool = false

## La coupe en cours, la même sur toutes les machines : l'hôte la tient et
## l'envoie à chaque manche. Null en course seule.
var grand_prix: GrandPrix

## Le chargement de la course : peer -> prêt. Tenu par l'hôte, recopié chez
## les autres pour l'écran de chargement. Porté par cet autoload et non par la
## course : les machines ne finissent pas de charger en même temps, et un
## message adressé à une course pas encore montée se perdrait.
var charges: Dictionary = {}
var depart_donne := false

## Le dernier plan de course lancé : qui occupe quelle place de la grille.
var plan: Array = []

var decouverte := LanDiscovery.new()
## Le port de l'hôte ouvert sur sa box, pour jouer par Internet.
var port_internet := PortInternet.new()

var _nom_voulu: String = ""
## Le port réellement ouvert, celui qu'on annonce sur le réseau local.
var _port: int = PORT


func _ready() -> void:
	add_child(decouverte)
	add_child(port_internet)
	port_internet.fini.connect(func() -> void: salon_change.emit())
	multiplayer.peer_connected.connect(_sur_arrivee)
	multiplayer.peer_disconnected.connect(_sur_depart)
	multiplayer.connected_to_server.connect(_sur_connexion)
	multiplayer.connection_failed.connect(_sur_echec)
	multiplayer.server_disconnected.connect(_sur_perte_hote)
	if not TrackCatalog.PISTES.is_empty():
		config.piste = TrackCatalog.PISTES[0].id
		config.tours = TrackCatalog.PISTES[0].tours


func actif() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not peer is OfflineMultiplayerPeer \
		and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func est_hote() -> bool:
	return actif() and multiplayer.is_server()


func mon_id() -> int:
	return multiplayer.get_unique_id() if actif() else 1


# --- Héberger, rejoindre, partir ----------------------------------------------

func heberger(nom: String, port: int = PORT) -> Error:
	quitter()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Lobby.PLACES - 1)
	if err != OK:
		erreur.emit("Impossible d'ouvrir le port %d (erreur %d)." % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	_port = port
	lobby = Lobby.new()
	lobby.ajouter(1, nom)
	lobby.choisir_vehicule(1, GameSettings.course.modele, GameSettings.course.couleur)
	en_course = false
	_annoncer()
	port_internet.ouvrir(port)
	salon_change.emit()
	connecte.emit()
	return OK


func rejoindre(adresse: String, nom: String, port: int = PORT) -> Error:
	quitter()
	var cible := decouper_adresse(adresse, port)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(cible[0], cible[1])
	if err != OK:
		erreur.emit("Adresse invalide : %s" % adresse)
		return err
	_nom_voulu = nom
	multiplayer.multiplayer_peer = peer
	return OK


## « hôte » ou « hôte:port » (l'adresse Internet qu'affiche le salon de
## l'hôte porte son port) : rend [hôte, port].
static func decouper_adresse(texte: String, port_par_defaut: int = PORT) -> Array:
	var propre := texte.strip_edges()
	var deux_points := propre.rfind(":")
	# Un seul « : » : c'est un port. Plusieurs : une adresse IPv6, sans port.
	if deux_points > 0 and propre.count(":") == 1 and propre.substr(deux_points + 1).is_valid_int():
		return [propre.left(deux_points), int(propre.substr(deux_points + 1))]
	return [propre, port_par_defaut]


func quitter() -> void:
	decouverte.arreter_annonce()
	port_internet.fermer()
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	lobby = Lobby.new()
	en_course = false
	plan = []
	grand_prix = null


## Les adresses sous lesquelles les autres peuvent joindre cet appareil : à
## afficher dans le salon de l'hôte, pour qu'on sache quoi taper.
static func adresses_locales() -> PackedStringArray:
	var trouvees := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		trouvees.append(a)
	return trouvees


# --- Le salon ------------------------------------------------------------------

func choisir_config(piste: String, tours: int, cylindree: int = Cylindree.Classe.CC150,
		coupe: int = SANS_COUPE, miroir := false) -> void:
	if not est_hote():
		return
	config = {
		piste = piste, tours = clampi(tours, 1, 9),
		cylindree = clampi(cylindree, Cylindree.Classe.CC50, Cylindree.Classe.CC200),
		coupe = clampi(coupe, SANS_COUPE, TrackCatalog.COUPES.size() - 1),
		miroir = miroir,
	}
	_diffuser_salon()


func _sur_arrivee(_peer: int) -> void:
	# Rien à faire tant que le client ne s'est pas présenté.
	pass


func _sur_depart(peer: int) -> void:
	if not multiplayer.is_server():
		return
	lobby.retirer(peer)
	_diffuser_salon()
	# Celui qu'on attendait pour partir s'en va : on part sans lui.
	if en_course and charges.has(peer):
		charges.erase(peer)
		if not depart_donne and not charges.values().has(false):
			donner_le_depart()


func _sur_connexion() -> void:
	_bonjour.rpc_id(1, _nom_voulu, VERSION)
	annoncer_vehicule()


## Le kart du garage, à l'hôte (qui le range dans le salon et le diffuse).
## À rappeler quand le joueur en change en cours de salon.
func annoncer_vehicule() -> void:
	if not actif():
		return
	var reglage := GameSettings.course
	if multiplayer.is_server():
		lobby.choisir_vehicule(1, reglage.modele, reglage.couleur)
		_diffuser_salon()
	else:
		_vehicule.rpc_id(1, reglage.modele, reglage.couleur)


@rpc("any_peer", "reliable")
func _vehicule(modele: int, couleur: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if not lobby.joueurs.has(peer):
		return
	lobby.choisir_vehicule(peer, modele, couleur)
	_diffuser_salon()


func _sur_echec() -> void:
	quitter()
	erreur.emit("Impossible de joindre l'hôte.")


func _sur_perte_hote() -> void:
	var etait_en_course := en_course
	quitter()
	deconnecte.emit("L'hôte a quitté la partie.")
	if etait_en_course:
		RaceLauncher.retour_au_menu(get_tree())


@rpc("any_peer", "reliable")
func _bonjour(nom: String, version: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var raison := ""
	if version != VERSION:
		raison = "Version différente de celle de l'hôte : mettez le jeu à jour."
	elif en_course:
		raison = "Une course est en cours : réessayez à la fin."
	elif lobby.est_plein():
		raison = "La partie est complète."
	if raison != "":
		_refus.rpc_id(peer, raison)
		# Laisser le refus partir avant de couper.
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(peer))
		return
	lobby.ajouter(peer, nom)
	_diffuser_salon()


@rpc("authority", "reliable")
func _refus(raison: String) -> void:
	quitter()
	erreur.emit(raison)


func _diffuser_salon() -> void:
	_etat_salon.rpc(lobby.en_liste(), config)
	_etat_salon(lobby.en_liste(), config)
	_annoncer()


@rpc("authority", "reliable")
func _etat_salon(liste: Array, reglages: Dictionary) -> void:
	var nouveau := not lobby.joueurs.has(mon_id()) and not multiplayer.is_server()
	lobby.depuis_liste(liste)
	config = reglages
	if nouveau and lobby.joueurs.has(mon_id()):
		connecte.emit()
	salon_change.emit()


func _annoncer() -> void:
	if not est_hote() or en_course:
		decouverte.arreter_annonce()
		return
	decouverte.annoncer({nom = lobby.joueurs.get(1, "Hôte"), port = _port, joueurs = lobby.joueurs.size()})


# --- La course -----------------------------------------------------------------

func lancer_course() -> void:
	if not est_hote():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var coupe := int(config.get("coupe", SANS_COUPE))
	if coupe == SANS_COUPE:
		_lancer_pour_tous(lobby.plan_de_course(rng), config)
		return
	var gp := GrandPrix.new(coupe, int(config.get("cylindree", Cylindree.Classe.CC150)))
	gp.miroir = bool(config.get("miroir", false))
	_lancer_pour_tous(lobby.plan_de_course(rng), config_de_manche(config, gp))


## Les réglages d'une manche : le circuit de la coupe, trois tours, et l'état
## de la coupe pour que chacun affiche les mêmes points.
static func config_de_manche(base: Dictionary, gp: GrandPrix) -> Dictionary:
	var c := base.duplicate()
	var piste := gp.piste()
	c.piste = piste.id
	# tours_coupe : pour les essais seulement, des manches courtes.
	c.tours = int(base.get("tours_coupe", piste.tours))
	c.cylindree = gp.classe
	c.miroir = gp.miroir
	c.coupe = gp.coupe
	c.gp = gp.en_dictionnaire()
	return c


## L'hôte compte la manche qui s'achève (les noms dans l'ordre d'arrivée),
## puis lance la suivante — ou le podium.
func manche_suivante(ordre_d_arrivee: PackedStringArray) -> void:
	if not est_hote() or grand_prix == null:
		return
	grand_prix.compter(ordre_d_arrivee)
	if grand_prix.terminee():
		_podium.rpc(grand_prix.en_dictionnaire())
		_podium(grand_prix.en_dictionnaire())
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_lancer_pour_tous(lobby.plan_de_coupe(grand_prix, rng), config_de_manche(config, grand_prix))


func _lancer_pour_tous(nouveau_plan: Array, reglages: Dictionary) -> void:
	_lancer.rpc(nouveau_plan, reglages)
	_lancer(nouveau_plan, reglages)


@rpc("authority", "reliable")
func _podium(etat: Dictionary) -> void:
	grand_prix = GrandPrix.depuis(etat)
	podium.emit()


@rpc("authority", "reliable")
func _lancer(nouveau_plan: Array, reglages: Dictionary) -> void:
	plan = nouveau_plan
	config = reglages
	grand_prix = GrandPrix.depuis(reglages.gp) if reglages.has("gp") else null
	en_course = true
	depart_donne = false
	charges = {}
	for place in plan:
		if int(place.peer) != 0:
			charges[int(place.peer)] = false
	decouverte.arreter_annonce()
	RaceLauncher.lancer_reseau(get_tree(), plan, config, mon_id(), est_hote())


## L'hôte ramène tout le monde au salon, pour la course suivante.
func retour_salon() -> void:
	if not est_hote():
		return
	_retour.rpc()
	_retour()


@rpc("authority", "reliable")
func _retour() -> void:
	en_course = false
	grand_prix = null
	config.erase("gp")
	_annoncer()
	RaceLauncher.retour_au_menu(get_tree())


## Un joueur qui quitte la course la quitte aussi en réseau : on ne revient
## pas au menu en laissant sa place ouverte.
func abandonner() -> void:
	quitter()
	RaceLauncher.retour_au_menu(get_tree())


# --- Chargement et départ ------------------------------------------------------

## Cette machine a fini de charger la course : elle le dit à l'hôte.
func signaler_charge() -> void:
	if est_hote():
		_sur_charge(1)
	elif actif():
		_charge.rpc_id(1)


@rpc("any_peer", "reliable")
func _charge() -> void:
	if multiplayer.is_server():
		_sur_charge(multiplayer.get_remote_sender_id())


func _sur_charge(peer: int) -> void:
	charges[peer] = true
	_etats_charges.rpc(charges)
	charges_changes.emit()
	# Arrivé après le départ (l'attente avait trop duré) : il part tout de suite.
	if depart_donne:
		if peer != 1:
			_depart.rpc_id(peer)
		return
	if not charges.values().has(false):
		donner_le_depart()


## Donne le départ à tous. L'hôte l'appelle quand tout le monde est prêt, ou
## quand l'attente a trop duré (RaceSync) : un téléphone lent ne bloque pas
## les autres.
func donner_le_depart() -> void:
	if not est_hote() or depart_donne:
		return
	_depart.rpc()
	_depart()


@rpc("authority", "reliable")
func _etats_charges(etats: Dictionary) -> void:
	charges = etats
	charges_changes.emit()


@rpc("authority", "reliable")
func _depart() -> void:
	depart_donne = true
	depart.emit()
