extends Node

## Le journal de bord, pour comprendre un plantage qu'on ne voit pas d'ici :
## un téléphone qui ferme le jeu d'un coup ne laisse rien à l'écran.
##
## - Godot écrit déjà son journal (user://logs, debug/file_logging) ; on y
##   ajoute des repères : quel écran, quelle course, combien de mémoire.
## - Une marque posée au lancement et retirée à la sortie propre (ou quand le
##   système met le jeu en pause) : si elle est encore là au lancement
##   suivant, le jeu s'est arrêté brutalement.
## - Le journal de la partie précédente se lit dans le jeu (JournalPanel) et
##   se copie, pour l'envoyer.

const MARQUE := "user://partie_en_cours"
const DOSSIER := "user://logs"
## Un repère mémoire toutes les tant de secondes, en course comme au menu.
const PERIODE_MEMOIRE := 30.0
## Plus serrés au démarrage : un jeu qui se ferme dans la première minute
## ne laissait que la ligne du lancement.
const PERIODE_AU_DEMARRAGE := 5.0
const DEMARRAGE := 60.0

## Vrai si la partie précédente ne s'est pas terminée proprement.
var plantage_precedent := false
## Le fichier du journal de la partie précédente ; vide s'il n'y en a pas.
var journal_precedent := ""

var _depuis_memoire := 0.0
var _depuis_lancement := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	plantage_precedent = FileAccess.file_exists(MARQUE)
	journal_precedent = _dernier_journal()
	_poser_la_marque()
	reperer("lancement %s sur %s %s (%s), écran %s, plantage précédent : %s" % [
		ProjectSettings.get_setting("application/config/version", "?"), OS.get_name(), OS.get_version(),
		OS.get_model_name(), DisplayServer.screen_get_size(), "oui" if plantage_precedent else "non"])
	get_tree().node_added.connect(_sur_noeud)


func _process(delta: float) -> void:
	_depuis_memoire += delta
	_depuis_lancement += delta
	var periode := PERIODE_AU_DEMARRAGE if _depuis_lancement < DEMARRAGE else PERIODE_MEMOIRE
	if _depuis_memoire >= periode:
		_depuis_memoire = 0.0
		reperer(etat_memoire())


func _notification(quoi: int) -> void:
	match quoi:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE, NOTIFICATION_APPLICATION_PAUSED:
			# Le système peut tuer un jeu en pause sans prévenir : ce n'est pas
			# un plantage.
			_oter_la_marque()
		NOTIFICATION_APPLICATION_RESUMED:
			_poser_la_marque()
		NOTIFICATION_OS_MEMORY_WARNING:
			reperer("le système manque de mémoire : " + etat_memoire())


## Un repère dans le journal, daté.
func reperer(texte: String) -> void:
	print("[repère %s] %s" % [Time.get_time_string_from_system(), texte])


## La mémoire, en une ligne.
static func etat_memoire() -> String:
	return "mémoire %.0f Mo, vidéo %.0f Mo (textures %.0f Mo), %d objets, %d nœuds, %.0f FPS" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.TIME_FPS)]


## Les dernières lignes du journal de la partie précédente.
func fin_du_journal_precedent(lignes: int = 120) -> String:
	if journal_precedent == "":
		return "Pas de journal de la partie précédente."
	var fichier := FileAccess.open(journal_precedent, FileAccess.READ)
	if fichier == null:
		return "Journal illisible : %s" % journal_precedent
	var tout := fichier.get_as_text().split("\n")
	return "\n".join(tout.slice(maxi(tout.size() - lignes, 0)))


## Le plus récent des journaux, hors celui de cette partie (godot.log) :
## Godot renomme le précédent avec sa date au lancement.
func _dernier_journal() -> String:
	var dossier := DirAccess.open(DOSSIER)
	if dossier == null:
		return ""
	var plus_recent := ""
	var date := -1
	for nom in dossier.get_files():
		if not nom.ends_with(".log") or nom == "godot.log":
			continue
		var chemin := DOSSIER.path_join(nom)
		var quand := FileAccess.get_modified_time(chemin)
		if quand > date:
			date = quand
			plus_recent = chemin
	return plus_recent


## Les écrans et la course : un repère quand ils arrivent.
func _sur_noeud(noeud: Node) -> void:
	if noeud.get_parent() != get_tree().root:
		return
	reperer("écran : %s — %s" % [noeud.name, etat_memoire()])


func _poser_la_marque() -> void:
	var f := FileAccess.open(MARQUE, FileAccess.WRITE)
	if f != null:
		f.store_string(Time.get_datetime_string_from_system())


func _oter_la_marque() -> void:
	if FileAccess.file_exists(MARQUE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARQUE))
