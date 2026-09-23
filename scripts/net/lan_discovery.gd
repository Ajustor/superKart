class_name LanDiscovery
extends Node

## Trouver les parties du réseau local sans taper d'adresse. L'hôte crie une
## fois par seconde, en diffusion UDP, qu'il existe ; les joueurs qui
## cherchent écoutent et listent ce qu'ils entendent. Une partie qui se tait
## trois secondes disparaît de la liste.
##
## Tout passe par un seul petit message JSON : il porte de quoi l'afficher
## (nom, nombre de joueurs) et de quoi s'y connecter (port). L'adresse, elle,
## est celle d'où vient le paquet.

signal liste_changee

const PORT := 8911
const SIGNATURE := "superkart"
const INTERVALLE := 1.0
const OUBLI := 3.0

## adresse IP -> {nom, port, joueurs, max, vu}
var parties: Dictionary = {}

var _emetteur: PacketPeerUDP
var _ecouteur: PacketPeerUDP
var _annonce: Dictionary = {}
var _depuis_annonce: float = 0.0


func annoncer(infos: Dictionary) -> void:
	_annonce = infos
	if _emetteur == null:
		_emetteur = PacketPeerUDP.new()
		_emetteur.set_broadcast_enabled(true)
		_emetteur.set_dest_address("255.255.255.255", PORT)
	_depuis_annonce = INTERVALLE  # la première tout de suite


func arreter_annonce() -> void:
	if _emetteur != null:
		_emetteur.close()
	_emetteur = null


func ecouter() -> Error:
	arreter_ecoute()
	_ecouteur = PacketPeerUDP.new()
	var err := _ecouteur.bind(PORT)
	if err != OK:
		_ecouteur = null
	return err


func arreter_ecoute() -> void:
	if _ecouteur != null:
		_ecouteur.close()
	_ecouteur = null
	if not parties.is_empty():
		parties.clear()
		liste_changee.emit()


func _process(delta: float) -> void:
	if _emetteur != null:
		_depuis_annonce += delta
		if _depuis_annonce >= INTERVALLE:
			_depuis_annonce = 0.0
			var message := _annonce.duplicate()
			message["jeu"] = SIGNATURE
			_emetteur.put_packet(JSON.stringify(message).to_utf8_buffer())

	if _ecouteur == null:
		return
	var change := false
	var maintenant := Time.get_ticks_msec() / 1000.0
	while _ecouteur.get_available_packet_count() > 0:
		var brut := _ecouteur.get_packet()
		var ip := _ecouteur.get_packet_ip()
		var infos := lire(brut.get_string_from_utf8())
		if infos.is_empty():
			continue
		infos["vu"] = maintenant
		change = change or not parties.has(ip) or parties[ip]["joueurs"] != infos["joueurs"]
		parties[ip] = infos
	for ip in parties.keys():
		if maintenant - float(parties[ip]["vu"]) > OUBLI:
			parties.erase(ip)
			change = true
	if change:
		liste_changee.emit()


## Relit une annonce, ou rend un dictionnaire vide si ce n'en est pas une :
## n'importe qui peut envoyer n'importe quoi sur ce port.
static func lire(texte: String) -> Dictionary:
	# JSON.parse et non parse_string : celle-ci crie une erreur moteur pour
	# chaque paquet mal formé, et le port est ouvert à tout le réseau local.
	var json := JSON.new()
	if json.parse(texte) != OK:
		return {}
	var donnees = json.data
	if not donnees is Dictionary or donnees.get("jeu", "") != SIGNATURE:
		return {}
	return {
		nom = Lobby.nettoyer(str(donnees.get("nom", ""))),
		port = clampi(int(donnees.get("port", 0)), 1, 65535),
		joueurs = clampi(int(donnees.get("joueurs", 0)), 0, Lobby.PLACES),
		max = Lobby.PLACES,
	}


func _exit_tree() -> void:
	arreter_annonce()
	arreter_ecoute()
