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

const PORT := 8910
## Monté à chaque changement du protocole : un client d'une autre version est
## refusé poliment plutôt que de désynchroniser la course en silence.
const VERSION := 2

var lobby := Lobby.new()
var config: Dictionary = {piste = "", tours = 3}
var en_course: bool = false

## Le dernier plan de course lancé : qui occupe quelle place de la grille.
var plan: Array = []

var decouverte := LanDiscovery.new()

var _nom_voulu: String = ""
## Le port réellement ouvert, celui qu'on annonce sur le réseau local.
var _port: int = PORT


func _ready() -> void:
	add_child(decouverte)
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
	en_course = false
	_annoncer()
	salon_change.emit()
	connecte.emit()
	return OK


func rejoindre(adresse: String, nom: String, port: int = PORT) -> Error:
	quitter()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(adresse.strip_edges(), port)
	if err != OK:
		erreur.emit("Adresse invalide : %s" % adresse)
		return err
	_nom_voulu = nom
	multiplayer.multiplayer_peer = peer
	return OK


func quitter() -> void:
	decouverte.arreter_annonce()
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	lobby = Lobby.new()
	en_course = false
	plan = []


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

func choisir_config(piste: String, tours: int) -> void:
	if not est_hote():
		return
	config = {piste = piste, tours = clampi(tours, 1, 9)}
	_diffuser_salon()


func _sur_arrivee(_peer: int) -> void:
	# Rien à faire tant que le client ne s'est pas présenté.
	pass


func _sur_depart(peer: int) -> void:
	if not multiplayer.is_server():
		return
	lobby.retirer(peer)
	_diffuser_salon()


func _sur_connexion() -> void:
	_bonjour.rpc_id(1, _nom_voulu, VERSION)


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
	var nouveau_plan := lobby.plan_de_course(rng)
	_lancer.rpc(nouveau_plan, config)
	_lancer(nouveau_plan, config)


@rpc("authority", "reliable")
func _lancer(nouveau_plan: Array, reglages: Dictionary) -> void:
	plan = nouveau_plan
	config = reglages
	en_course = true
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
	_annoncer()
	RaceLauncher.retour_au_menu(get_tree())


## Un joueur qui quitte la course la quitte aussi en réseau : on ne revient
## pas au menu en laissant sa place ouverte.
func abandonner() -> void:
	quitter()
	RaceLauncher.retour_au_menu(get_tree())
