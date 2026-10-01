extends Node

## Le serveur de jeu en ligne : SuperKart lancé sans écran, qui tient un salon
## sans y piloter. Déclaré en autoload sous le nom `ServeurDedie` ; inerte sauf
## quand le jeu est lancé avec `--serveur` :
##
##   godot --headless --path . -- --serveur --port 8920 --nom "Salon 1" \
##       [--code ABCDE] [--prive] [--annuaire http://127.0.0.1:8900 --jeton S]
##
## Le serveur :
## - ouvre le salon (Reseau.heberger_dedie) ; le premier joueur arrivé en est
##   le chef, et choisit circuit et mode ;
## - enchaîne lui-même quand le chef tarde : retour au salon après une course,
##   manche suivante d'une coupe, retour après le podium ;
## - donne son état à l'annuaire (voir serveur/annuaire.py) toutes les
##   quelques secondes, s'il en a un ;
## - s'arrête quand plus personne ne l'occupe : l'annuaire en relance un à la
##   demande.

## Secondes avant de s'arrêter si personne ne vient, puis si tout le monde
## est parti. Zéro : jamais (un salon permanent).
const ATTENTE_PREMIER_JOUEUR := 300.0
const ATTENTE_SALON_VIDE := 120.0
## Après l'arrivée du dernier, le chef a ce temps pour revenir au salon ou
## lancer la manche suivante ; ensuite le serveur le fait.
const DELAI_APRES_COURSE := 25.0
const DELAI_ENTRE_MANCHES := 12.0
const DELAI_APRES_PODIUM := 20.0
## Toutes les combien de secondes l'état part vers l'annuaire.
const PERIODE_ETAT := 5.0

var actif := false
var reglages: Dictionary = {}

var _vide_depuis := 0.0
var _a_eu_des_joueurs := false
var _session: RaceSession
var _fin_de_course := -1.0
var _podium := -1.0
var _horloge := 0.0
var _depuis_etat := PERIODE_ETAT
var _requete: HTTPRequest


func _ready() -> void:
	reglages = lire_arguments(OS.get_cmdline_user_args())
	if not reglages.get("serveur", false):
		set_process(false)
		return
	actif = true
	# Sans écran, la boucle tournerait aussi vite qu'elle peut : soixante
	# images par seconde suffisent, la physique en fait autant.
	Engine.max_fps = 60
	GameSettings.qualite = QualiteGraphique.Niveau.BASSE
	_requete = HTTPRequest.new()
	_requete.timeout = 4.0
	add_child(_requete)
	Reseau.podium.connect(func() -> void: _podium = _horloge)
	# Le menu principal est la scène de départ ; un serveur n'en a pas l'usage.
	get_tree().change_scene_to_node.call_deferred(_scene_vide())
	_ouvrir.call_deferred()


func _ouvrir() -> void:
	var infos := {nom = reglages.nom, code = reglages.code, prive = reglages.prive}
	var err := Reseau.heberger_dedie(int(reglages.port), infos)
	if err != OK:
		printerr("serveur : port %d indisponible (%d)" % [reglages.port, err])
		get_tree().quit(1)
		return
	print("serveur : salon « %s » ouvert sur le port %d (code %s)" % [reglages.nom, reglages.port, reglages.code])


## Les arguments après `--` : `--serveur`, `--port N`, `--nom X`, `--code X`,
## `--prive`, `--annuaire URL`, `--jeton X`, `--permanent`.
static func lire_arguments(args: PackedStringArray) -> Dictionary:
	var r := {serveur = false, port = Reseau.PORT, nom = "Salon SuperKart", code = "", prive = false,
		annuaire = "", jeton = "", permanent = false}
	var i := 0
	while i < args.size():
		var a := args[i]
		var suivant := args[i + 1] if i + 1 < args.size() else ""
		match a:
			"--serveur":
				r.serveur = true
			"--prive":
				r.prive = true
			"--permanent":
				r.permanent = true
			"--port":
				r.port = clampi(int(suivant), 1, 65535)
				i += 1
			"--nom":
				if suivant.strip_edges() != "":
					r.nom = suivant.strip_edges().left(32)
				i += 1
			"--code":
				r.code = suivant.to_upper()
				i += 1
			"--annuaire":
				r.annuaire = suivant.trim_suffix("/")
				i += 1
			"--jeton":
				r.jeton = suivant
				i += 1
		i += 1
	return r


static func _scene_vide() -> Node:
	var vide := Node.new()
	vide.name = "Serveur"
	return vide


func _process(delta: float) -> void:
	_horloge += delta
	_surveiller_le_salon(delta)
	_enchainer()
	_depuis_etat += delta
	if _depuis_etat >= PERIODE_ETAT:
		_depuis_etat = 0.0
		_envoyer_etat()


func _surveiller_le_salon(delta: float) -> void:
	if Reseau.lobby.joueurs.is_empty():
		_vide_depuis += delta
	else:
		_vide_depuis = 0.0
		_a_eu_des_joueurs = true
	if reglages.permanent:
		return
	var limite := ATTENTE_SALON_VIDE if _a_eu_des_joueurs else ATTENTE_PREMIER_JOUEUR
	if _vide_depuis > limite:
		print("serveur : salon vide depuis %d s, arrêt" % int(_vide_depuis))
		_envoyer_etat(true)
		Reseau.quitter()
		get_tree().quit()


## Ce que le chef ferait s'il était là : le serveur ne laisse pas un salon
## bloqué sur un écran de résultats.
func _enchainer() -> void:
	if not Reseau.en_course:
		_session = null
		_fin_de_course = -1.0
		_podium = -1.0
		return
	if _session == null or not is_instance_valid(_session):
		_session = _trouver_session()
		_fin_de_course = -1.0
	if _podium >= 0.0:
		if _horloge - _podium > DELAI_APRES_PODIUM:
			_podium = -1.0
			Reseau.retour_salon()
		return
	if _session == null or not _session.terminee:
		return
	if _fin_de_course < 0.0:
		_fin_de_course = _horloge
		return
	var attente := DELAI_ENTRE_MANCHES if Reseau.grand_prix != null else DELAI_APRES_COURSE
	if _horloge - _fin_de_course < attente:
		return
	_fin_de_course = INF
	if Reseau.grand_prix != null:
		Reseau.manche_suivante(Reseau.ordre_de_la_course(get_tree()))
	else:
		Reseau.retour_salon()


func _trouver_session() -> RaceSession:
	for noeud in get_tree().root.find_children("Session", "Node", true, false):
		if noeud is RaceSession:
			return noeud
	return null


## L'état du salon, pour l'annuaire et ceux qui le consultent.
func etat(ferme := false) -> Dictionary:
	var piste := TrackCatalog.par_id(str(Reseau.config.get("piste", "")))
	return {
		jeton = reglages.get("jeton", ""),
		code = reglages.get("code", ""),
		nom = reglages.get("nom", ""),
		joueurs = Reseau.lobby.joueurs.size(),
		places = Lobby.PLACES,
		en_course = Reseau.en_course,
		piste = piste.nom if piste != null else "",
		version = Reseau.VERSION,
		ferme = ferme,
	}


func _envoyer_etat(ferme := false) -> void:
	if str(reglages.get("annuaire", "")) == "" or reglages.code == "":
		return
	if _requete.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED and not ferme:
		return
	_requete.cancel_request()
	_requete.request("%s/salons/%s/etat" % [reglages.annuaire, reglages.code],
		PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST,
		JSON.stringify(etat(ferme)))
