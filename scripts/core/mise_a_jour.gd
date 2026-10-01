extends Node

## Cherche une nouvelle version du jeu, la télécharge et l'installe.
## Déclaré en autoload sous le nom `MiseAJour` : le menu principal l'interroge
## et l'affiche, mais la vérification vit ici, une fois par lancement.
##
## La page de téléchargement (GitHub Pages) publie, à côté des binaires, un
## petit manifeste `telecharger/version.json` : la version proposée, ses
## notes, et pour chaque plateforme le fichier, sa taille et son empreinte
## SHA-256. Le jeu lit ce manifeste plutôt que l'API GitHub : sur un dépôt
## privé, l'API et les fichiers des Releases demandent un compte, la page non.
##
## L'installation dépend de la plateforme :
## - Windows : l'archive est téléchargée, l'exécutable et le .pck en sont
##   extraits à côté des fichiers en place (`.maj`), puis un petit script
##   attend que le jeu se ferme, remplace les fichiers et relance le jeu ;
## - Android : l'APK est téléchargé dans les fichiers de l'application, puis
##   confié à l'installeur du système (qui demande confirmation au joueur) ;
## - ailleurs (éditeur, Linux…) : on ouvre la page de téléchargement.
##
## Une version de développement (« dev ») ne cherche rien : elle n'a pas de
## numéro à comparer.

## Pas de class_name : il entrerait en conflit avec le nom de l'autoload.

signal etat_change(etat: int)
signal progression(fraction: float)

enum Etat {
	## Rien demandé, ou version de développement.
	INACTIF,
	VERIFICATION,
	A_JOUR,
	DISPONIBLE,
	TELECHARGEMENT,
	## Téléchargé et vérifié : il n'y a plus qu'à installer.
	PRET,
	INSTALLATION,
	ERREUR,
}

## Où lire le manifeste. Surchargeable dans project.godot
## (application/config/url_mises_a_jour) : un fork n'a qu'à y mettre sa page.
const URL_PAR_DEFAUT := "https://ajustor.github.io/superKart/telecharger/version.json"
const DOSSIER := "user://mise_a_jour"
## Le délai au-delà duquel on abandonne la vérification : au menu, personne
## n'attend un serveur qui ne répond pas.
const DELAI_VERIFICATION := 10.0

var etat: int = Etat.INACTIF
## La version proposée, telle que le manifeste l'écrit (« 1.3 »).
var version_disponible: String = ""
## Les notes de version, en Markdown.
var notes: String = ""
## Ce qui a mal tourné, à afficher au joueur.
var erreur: String = ""

var _manifeste: Dictionary = {}
var _url_manifeste: String = ""
var _requete: HTTPRequest
var _fichier: String = ""
var _taille_attendue: int = 0


func _ready() -> void:
	_url_manifeste = str(ProjectSettings.get_setting("application/config/url_mises_a_jour", URL_PAR_DEFAUT))
	# Différé : les réglages (GameSettings) doivent être chargés, et le menu
	# s'affiche avant que le réseau ne réponde.
	if GameSettings.verifier_mises_a_jour:
		verifier.call_deferred()


## La version de ce jeu, telle que la CI l'a inscrite (« 1.2 », « 1.1.57 »),
## ou « dev ».
static func version_installee() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return "dev" if v == "" else v


## -1, 0 ou 1 selon que `a` est plus ancienne, égale ou plus récente que `b`.
## Composante par composante, en nombres : 1.10 vient après 1.9. Un « v » en
## tête est ignoré, et une composante absente vaut zéro : 1.2 = 1.2.0.
static func comparer_versions(a: String, b: String) -> int:
	var pa := _composantes(a)
	var pb := _composantes(b)
	for i in maxi(pa.size(), pb.size()):
		var x: int = pa[i] if i < pa.size() else 0
		var y: int = pb[i] if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


static func _composantes(v: String) -> Array[int]:
	v = v.strip_edges()
	if v.begins_with("v") or v.begins_with("V"):
		v = v.substr(1)
	var r: Array[int] = []
	for morceau in v.split("."):
		# « 2-beta » compte pour 2 : seul le nombre en tête importe.
		var chiffres := ""
		for car in morceau:
			if car < "0" or car > "9":
				break
			chiffres += car
		r.append(int(chiffres) if chiffres != "" else 0)
	return r


## Une version numérotée peut-elle se comparer ? « dev » ne le peut pas.
static func version_comparable(v: String) -> bool:
	return v.strip_edges().trim_prefix("v").trim_prefix("V").substr(0, 1).is_valid_int()


## Le nom de la plateforme dans le manifeste, ou "" si le jeu ne sait pas s'y
## mettre à jour seul.
static func plateforme() -> String:
	if OS.has_feature("editor"):
		return ""
	if OS.get_name() == "Windows":
		return "windows"
	if OS.get_name() == "Android":
		return "android"
	return ""


## Une version plus récente a-t-elle été annoncée ? Reste vrai pendant le
## téléchargement, et après une erreur de téléchargement.
func mise_a_jour_connue() -> bool:
	return version_comparable(version_disponible) \
		and comparer_versions(version_disponible, version_installee()) > 0


## Peut-on installer ici, ou seulement ouvrir la page ?
func installation_automatique() -> bool:
	return plateforme() != "" and _manifeste.has(plateforme())


## Lit le manifeste et dit si une version plus récente existe. Sans effet
## pendant une autre opération.
func verifier() -> void:
	if etat in [Etat.VERIFICATION, Etat.TELECHARGEMENT, Etat.INSTALLATION]:
		return
	if not version_comparable(version_installee()):
		_changer(Etat.INACTIF)
		return
	_changer(Etat.VERIFICATION)
	var requete := _nouvelle_requete()
	requete.timeout = DELAI_VERIFICATION
	requete.request_completed.connect(_sur_manifeste.bind(requete))
	if requete.request(_url_manifeste) != OK:
		requete.queue_free()
		_echouer("impossible de joindre le serveur de mises à jour")


func _sur_manifeste(resultat: int, code: int, _entetes: PackedStringArray, corps: PackedByteArray,
		requete: HTTPRequest) -> void:
	requete.queue_free()
	if resultat != HTTPRequest.RESULT_SUCCESS or code != 200:
		_echouer("serveur de mises à jour injoignable")
		return
	var lu: Variant = JSON.parse_string(corps.get_string_from_utf8())
	if not lu is Dictionary:
		_echouer("manifeste de mise à jour illisible")
		return
	lire_manifeste(lu)


## Retient le manifeste et décide : à jour, ou version disponible. Séparé de
## la requête pour se tester sans réseau.
func lire_manifeste(manifeste: Dictionary) -> void:
	_manifeste = manifeste
	version_disponible = str(manifeste.get("version", ""))
	notes = str(manifeste.get("notes", ""))
	if version_comparable(version_disponible) \
			and comparer_versions(version_disponible, version_installee()) > 0:
		_changer(Etat.DISPONIBLE)
	else:
		_changer(Etat.A_JOUR)


## L'adresse d'un fichier du manifeste : relative au manifeste lui-même, pour
## que la page puisse déménager sans qu'on réécrive le manifeste.
func url_de(fichier: String) -> String:
	if fichier.begins_with("http://") or fichier.begins_with("https://"):
		return fichier
	return _url_manifeste.get_base_dir().path_join(fichier)


## La page de téléchargement, pour qui ne peut pas installer tout seul.
func url_page() -> String:
	var page := str(_manifeste.get("page", ""))
	if page != "":
		return url_de(page)
	# telecharger/version.json → la racine du site.
	return _url_manifeste.get_base_dir().get_base_dir() + "/"


## Télécharge le fichier de cette plateforme, ou ouvre la page s'il n'y a rien
## à installer ici.
func mettre_a_jour() -> void:
	if etat != Etat.DISPONIBLE and etat != Etat.ERREUR:
		return
	if not mise_a_jour_connue():
		# L'erreur venait de la vérification elle-même : on la refait.
		verifier()
		return
	if not installation_automatique():
		OS.shell_open(url_page())
		return
	var info: Dictionary = _manifeste[plateforme()]
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	_fichier = DOSSIER.path_join(str(info.get("fichier", "")).get_file())
	_taille_attendue = int(info.get("taille", 0))
	if FileAccess.file_exists(_fichier):
		DirAccess.remove_absolute(_fichier)
	_changer(Etat.TELECHARGEMENT)
	progression.emit(0.0)
	_requete = _nouvelle_requete()
	_requete.download_file = _fichier
	# Pas de délai : une archive de 80 Mo sur une mauvaise 4G prend son temps.
	_requete.request_completed.connect(_sur_telechargement)
	if _requete.request(url_de(str(info.get("fichier", "")))) != OK:
		_echouer("téléchargement impossible")


func _process(_delta: float) -> void:
	if etat != Etat.TELECHARGEMENT or _requete == null:
		return
	var total := _requete.get_body_size()
	if total <= 0:
		total = _taille_attendue
	if total > 0:
		progression.emit(clampf(float(_requete.get_downloaded_bytes()) / float(total), 0.0, 1.0))


func _sur_telechargement(resultat: int, code: int, _entetes: PackedStringArray, _corps: PackedByteArray) -> void:
	_requete.queue_free()
	_requete = null
	if resultat != HTTPRequest.RESULT_SUCCESS or code != 200:
		_echouer("le téléchargement a échoué (%d)" % code)
		return
	var info: Dictionary = _manifeste[plateforme()]
	if not fichier_valide(_fichier, str(info.get("sha256", ""))):
		DirAccess.remove_absolute(_fichier)
		_echouer("fichier téléchargé corrompu")
		return
	progression.emit(1.0)
	_changer(Etat.PRET)
	installer()


## L'empreinte du fichier est-elle celle annoncée ? Sans empreinte annoncée,
## on se contente d'un fichier non vide.
static func fichier_valide(chemin: String, sha256: String) -> bool:
	if not FileAccess.file_exists(chemin):
		return false
	if sha256 == "":
		var f := FileAccess.open(chemin, FileAccess.READ)
		return f != null and f.get_length() > 0
	return FileAccess.get_sha256(chemin).to_lower() == sha256.to_lower()


func installer() -> void:
	if etat != Etat.PRET:
		return
	_changer(Etat.INSTALLATION)
	var ok := false
	match plateforme():
		"windows":
			ok = _installer_windows()
		"android":
			ok = _installer_android()
	if not ok:
		_echouer("installation impossible : téléchargez la nouvelle version sur la page")
		OS.shell_open(url_page())


## L'installeur du système prend la main : il demande au joueur de confirmer
## (et, la première fois, d'autoriser SuperKart à installer des applications).
## Le jeu en cours sera fermé par Android pendant l'installation.
func _installer_android() -> bool:
	var err := OS.shell_open(ProjectSettings.globalize_path(_fichier))
	if err == OK:
		# Le joueur peut refuser : il retrouve alors le bouton, et l'APK déjà
		# téléchargé.
		_changer(Etat.PRET)
	return err == OK


## Un exécutable en cours ne se remplace pas sous Windows : on extrait la
## nouvelle version à côté, et un script prend le relais une fois le jeu
## fermé.
func _installer_windows() -> bool:
	var exe := OS.get_executable_path()
	var dossier := exe.get_base_dir()
	var nom_exe := exe.get_file()
	var nom_pck := nom_exe.get_basename() + ".pck"
	var zip := ZIPReader.new()
	if zip.open(_fichier) != OK:
		return false
	var trouves := {}
	for chemin in zip.get_files():
		var nom := chemin.get_file()
		if nom.ends_with(".exe") and not trouves.has("exe"):
			trouves.exe = chemin
		elif nom.ends_with(".pck") and not trouves.has("pck"):
			trouves.pck = chemin
	if not (trouves.has("exe") and trouves.has("pck")):
		zip.close()
		return false
	for cle in ["exe", "pck"]:
		var cible := dossier.path_join((nom_exe if cle == "exe" else nom_pck) + ".maj")
		var f := FileAccess.open(cible, FileAccess.WRITE)
		if f == null:
			zip.close()
			return false
		f.store_buffer(zip.read_file(trouves[cle]))
		f.close()
	zip.close()
	var script := dossier.path_join("mise_a_jour_superkart.cmd")
	var f := FileAccess.open(script, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(script_windows(OS.get_process_id(), nom_exe, nom_pck))
	f.close()
	if OS.create_process("cmd.exe", ["/c", script.replace("/", "\\")]) <= 0:
		return false
	get_tree().quit()
	return true


## Attend la fin du jeu, remplace l'exécutable et le paquet, relance le jeu,
## puis s'efface.
static func script_windows(pid: int, nom_exe: String, nom_pck: String) -> String:
	var lignes := PackedStringArray([
		"@echo off",
		"cd /d \"%~dp0\"",
		":attente",
		"tasklist /FI \"PID eq %d\" 2>NUL | find \"%d\" >NUL" % [pid, pid],
		"if not errorlevel 1 (",
		"  timeout /t 1 /nobreak >NUL",
		"  goto attente",
		")",
		"move /Y \"%s.maj\" \"%s\" >NUL" % [nom_pck, nom_pck],
		"move /Y \"%s.maj\" \"%s\" >NUL" % [nom_exe, nom_exe],
		"start \"\" \"%s\"" % nom_exe,
		"(goto) 2>NUL & del \"%~f0\"",
	])
	return "\r\n".join(lignes) + "\r\n"


func _nouvelle_requete() -> HTTPRequest:
	var requete := HTTPRequest.new()
	requete.use_threads = true
	add_child(requete)
	return requete


func _echouer(raison: String) -> void:
	erreur = raison
	push_warning("mise à jour : " + raison)
	_changer(Etat.ERREUR)


func _changer(nouvel: int) -> void:
	etat = nouvel
	etat_change.emit(etat)
