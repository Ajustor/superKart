class_name EnLigne
extends Node

## Ce que le jeu demande à l'annuaire du mode en ligne (serveur/annuaire.py) :
## la liste des salons publics, la création d'un salon, un salon par son code.
## Chaque réponse arrive par un signal ; on rejoint ensuite le salon comme
## n'importe quelle partie (Reseau.rejoindre), à son adresse et son port.

signal liste_recue(salons: Array)
signal salon_recu(salon: Dictionary)
signal echec(message: String)

## Réglable dans project.godot (application/config/annuaire_en_ligne), que la
## CI remplit pour les versions publiées, et par le joueur (GameSettings).
const REGLAGE := "application/config/annuaire_en_ligne"
const DELAI := 25.0

var _requete: HTTPRequest
var _attendu := ""


func _ready() -> void:
	_requete = HTTPRequest.new()
	_requete.timeout = DELAI
	_requete.request_completed.connect(_sur_reponse)
	add_child(_requete)


## L'adresse de l'annuaire : celle du joueur s'il en a donné une, sinon celle
## du jeu. Vide : pas de mode en ligne.
static func url() -> String:
	var choisie := GameSettings.serveur_en_ligne.strip_edges()
	if choisie == "":
		choisie = str(ProjectSettings.get_setting(REGLAGE, "")).strip_edges()
	return completer_url(choisie)


## « superkart.exemple.org » → https://… ; une adresse IP ou localhost, sur un
## réseau à soi et sans certificat, → http://…
static func completer_url(adresse: String) -> String:
	var choisie := adresse.strip_edges().trim_suffix("/")
	if choisie == "" or choisie.begins_with("http://") or choisie.begins_with("https://"):
		return choisie
	var hote := str(Reseau.decouper_adresse(choisie)[0])
	var local := hote == "localhost" or hote.is_valid_ip_address()
	return ("http://" if local else "https://") + choisie


func occupe() -> bool:
	return _attendu != ""


func lister() -> void:
	_envoyer("liste", "/salons", HTTPClient.METHOD_GET, "")


func creer(nom: String, prive: bool) -> void:
	_envoyer("salon", "/salons", HTTPClient.METHOD_POST, JSON.stringify({nom = nom, prive = prive}))


func chercher(code: String) -> void:
	var propre := code.strip_edges().to_upper()
	if not code_valide(propre):
		echec.emit("Un code de salon fait 5 lettres ou chiffres.")
		return
	_envoyer("salon", "/salons/" + propre.uri_encode(), HTTPClient.METHOD_GET, "")


static func code_valide(code: String) -> bool:
	if code.length() != 5:
		return false
	for c in code:
		if not ((c >= "A" and c <= "Z") or (c >= "0" and c <= "9")):
			return false
	return true


func _envoyer(attendu: String, chemin: String, methode: int, corps: String) -> void:
	if url() == "":
		echec.emit("Aucun serveur en ligne n'est réglé.")
		return
	_requete.cancel_request()
	_attendu = attendu
	var err := _requete.request(url() + chemin, PackedStringArray(["Content-Type: application/json"]),
		methode, corps)
	if err != OK:
		_attendu = ""
		echec.emit("Adresse du serveur invalide.")


func _sur_reponse(resultat: int, code: int, _entetes: PackedStringArray, corps: PackedByteArray) -> void:
	var attendu := _attendu
	_attendu = ""
	if resultat != HTTPRequest.RESULT_SUCCESS:
		echec.emit("Serveur en ligne injoignable.")
		return
	var lu: Variant = JSON.parse_string(corps.get_string_from_utf8())
	var donnees: Dictionary = lu if lu is Dictionary else {}
	if code >= 400:
		echec.emit(str(donnees.get("erreur", "Le serveur a refusé (%d)." % code)))
		return
	match attendu:
		"liste":
			var salons: Array = donnees.get("salons", [])
			liste_recue.emit(salons.filter(func(s: Variant) -> bool: return s is Dictionary))
		"salon":
			salon_recu.emit(donnees)


## Le meilleur salon pour une partie rapide : public, ouvert, à la bonne
## version, pas en pleine course, pas complet ; le plus fréquenté d'abord,
## pour remplir les grilles. Vide si aucun ne convient.
static func choisir_pour_partie_rapide(salons: Array) -> Dictionary:
	var meilleur: Dictionary = {}
	for s: Dictionary in salons:
		if bool(s.get("prive", false)) or not bool(s.get("ouvert", true)) or bool(s.get("en_course", false)):
			continue
		if int(s.get("version", 0)) != Reseau.VERSION:
			continue
		if int(s.get("joueurs", 0)) >= int(s.get("places", Lobby.PLACES)):
			continue
		if meilleur.is_empty() or int(s.joueurs) > int(meilleur.joueurs):
			meilleur = s
	return meilleur
