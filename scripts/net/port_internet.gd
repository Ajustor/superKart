class_name PortInternet
extends Node

## Ouvre le port de la partie sur la box de l'hôte, par UPnP, pour qu'on
## puisse le rejoindre depuis Internet sans rien régler à la main, et trouve
## son adresse publique à donner aux autres.
##
## La recherche de la box bloque plusieurs secondes : elle se fait dans un
## fil à part, et le salon s'affiche sans l'attendre. Le port est refermé en
## quittant la partie, et en fermant le jeu.
##
## Ça ne marche pas partout : une box sans UPnP (ou qui l'a désactivé), ou un
## accès derrière le réseau d'un opérateur (CGNAT, fréquent en 4G/5G et chez
## certains fournisseurs) ne laissent pas entrer. Le message le dit, pour
## qu'on ne cherche pas en vain.

signal fini

enum Etat { INACTIF, EN_COURS, OUVERT, ECHEC }

## Durée du bail demandé à la box, en secondes : si le jeu plante sans
## refermer, le port se referme tout seul. Certaines box refusent les baux
## limités ; on redemande alors sans limite.
const BAIL := 4 * 3600
const DESCRIPTION := "SuperKart"

var etat: Etat = Etat.INACTIF
## « ip:port » à donner aux autres, une fois le port ouvert.
var adresse: String = ""
## Pourquoi ça n'a pas marché, en clair.
var message: String = ""

var _fil: Thread
var _upnp: UPNP
var _port: int = 0


static func disponible() -> bool:
	return ClassDB.class_exists("UPNP") and not OS.has_feature("web")


func ouvrir(port: int) -> void:
	fermer()
	_attendre_le_fil()
	_port = port
	if not disponible():
		_echouer("L'ouverture automatique du port n'est pas possible sur cette plateforme.")
		return
	etat = Etat.EN_COURS
	_fil = Thread.new()
	_fil.start(_chercher.bind(port))


## Dans le fil : trouver la box, lui demander le port, lire l'adresse
## publique. Ne touche à rien d'autre que ses variables locales.
func _chercher(port: int) -> void:
	var upnp := UPNP.new()
	var resultat := {}
	var err := upnp.discover(2500, 2, "InternetGatewayDevice")
	# Sans appareil trouvé, get_gateway() se plaint dans la console.
	var box: UPNPDevice = upnp.get_gateway() if err == UPNP.UPNP_RESULT_SUCCESS and upnp.get_device_count() > 0 else null
	if box == null or not box.is_valid_gateway():
		resultat = {ok = false, message = "Box introuvable par UPnP : ouvrez le port %d (UDP) à la main, ou jouez en réseau local." % port}
	else:
		var ouvert := upnp.add_port_mapping(port, port, DESCRIPTION, "UDP", BAIL)
		if ouvert != UPNP.UPNP_RESULT_SUCCESS:
			ouvert = upnp.add_port_mapping(port, port, DESCRIPTION, "UDP", 0)
		if ouvert != UPNP.UPNP_RESULT_SUCCESS:
			resultat = {ok = false, message = "La box refuse d'ouvrir le port %d : activez l'UPnP dans ses réglages, ou ouvrez-le à la main (UDP)." % port}
		else:
			resultat = {ok = true, ip = upnp.query_external_address()}
	_terminer.call_deferred(upnp, resultat)


func _terminer(upnp: UPNP, resultat: Dictionary) -> void:
	if _fil != null:
		_fil.wait_to_finish()
		_fil = null
	# Entre-temps, on a peut-être quitté la partie.
	if etat != Etat.EN_COURS:
		if bool(resultat.get("ok", false)):
			upnp.delete_port_mapping(_port, "UDP")
		return
	if not bool(resultat.get("ok", false)):
		_echouer(str(resultat.get("message", "")))
		return
	_upnp = upnp
	var ip := str(resultat.get("ip", ""))
	etat = Etat.OUVERT
	adresse = "%s:%d" % [ip, _port] if ip != "" else ""
	message = ""
	if ip == "":
		message = "Port ouvert, mais la box ne donne pas son adresse publique."
	elif adresse_privee(ip):
		# La box elle-même est derrière un autre réseau : ouvrir chez elle ne
		# suffit pas, personne ne peut entrer depuis Internet.
		message = "Votre accès à Internet passe par le réseau de votre opérateur (CGNAT) : on ne peut pas vous rejoindre depuis Internet."
	fini.emit()


func _echouer(pourquoi: String) -> void:
	etat = Etat.ECHEC
	adresse = ""
	message = pourquoi
	fini.emit()


func fermer() -> void:
	if etat == Etat.OUVERT and _upnp != null:
		_upnp.delete_port_mapping(_port, "UDP")
	_upnp = null
	etat = Etat.INACTIF
	adresse = ""
	message = ""


## Ce que le salon affiche.
func texte() -> String:
	match etat:
		Etat.EN_COURS:
			return "Internet : ouverture du port…"
		Etat.OUVERT:
			if message != "":
				return "Internet : " + message
			return "Depuis Internet : %s" % adresse
		Etat.ECHEC:
			return "Internet : " + message
	return ""


## Une adresse qui ne se voit pas depuis Internet : réseau privé, ou partagé
## par l'opérateur (100.64.0.0/10).
static func adresse_privee(ip: String) -> bool:
	var parts := ip.split(".")
	if parts.size() != 4:
		return false
	var a := int(parts[0])
	var b := int(parts[1])
	return a == 10 or a == 127 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31) \
		or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)


## Une recherche encore en cours (on relance, ou on quitte le jeu) : on la
## laisse finir, un fil abandonné ferait planter la sortie.
func _attendre_le_fil() -> void:
	if _fil != null and _fil.is_started():
		_fil.wait_to_finish()
	_fil = null


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST or quoi == NOTIFICATION_PREDELETE:
		fermer()
		_attendre_le_fil()
