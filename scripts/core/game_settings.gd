extends Node

## Réglages du joueur, chargés au lancement et écrits à chaque changement.
## Déclaré en autoload sous le nom `GameSettings` : le menu, la pause, le HUD
## et les commandes tactiles lisent tous la même instance.
##
## Pas de class_name : il entrerait en conflit avec le nom de l'autoload. Les
## tests chargent le script et l'instancient eux-mêmes, avec un fichier à eux,
## pour ne jamais écraser les réglages de celui qui les lance.

signal changed

enum Tactile { AUTO, TOUJOURS, JAMAIS }

const CHEMIN_PAR_DEFAUT := "user://reglages.cfg"
const BUS_EFFETS := &"Effets"
const BUS_MUSIQUE := &"Musique"

## Volumes linéaires, de 0 à 1 : c'est ce que montre un curseur. La conversion
## en décibels se fait au seul endroit où l'on parle au mixeur.
var volume_general: float = 0.8
var volume_effets: float = 1.0
var volume_musique: float = 0.6
var son_coupe: bool = false

var tactile: int = Tactile.AUTO

## Gaz tenus en permanence sur écran tactile : deux pouces ne suffisent pas à
## tenir l'accélérateur, braquer et déraper à la fois.
var acceleration_auto: bool = true

var vibrations: bool = true

## Diriger au joystick sur écran tactile ; sinon, deux flèches.
var joystick: bool = true

## La mini-carte en haut à droite pendant la course.
var mini_carte: bool = true

## Le compteur de performances (PerfOverlay), en haut de l'écran.
var afficher_fps: bool = false

## Voir QualiteGraphique.
var qualite: int = QualiteGraphique.Niveau.AUTO

## Le nom affiché aux autres joueurs en réseau.
var pseudo: String = ""

## La dernière adresse tapée pour rejoindre une partie.
var derniere_adresse: String = ""

## Sensibilité du joystick tactile : à 1,5, le pouce n'a à parcourir que les
## deux tiers du chemin pour braquer à fond.
const SENSIBILITE_MIN := 0.6
const SENSIBILITE_MAX := 1.8
var sensibilite_joystick: float = 1.0

## Les commandes changées par le joueur : action -> liste d'événements décrits
## (voir Touches). Vide : celles du projet.
var touches: Dictionary = {}

## La dernière course réglée dans le menu. Rejouer la reprend telle quelle.
var course := RaceSetup.new()

var chemin: String = CHEMIN_PAR_DEFAUT

## Meilleur temps de course par identifiant de circuit et nombre de tours :
## un record en un tour ne se compare pas à un record en cinq.
var _records: Dictionary = {}

## Meilleure place obtenue dans chaque coupe, par cylindrée (1 = or).
var _trophees: Dictionary = {}


func _ready() -> void:
	charger()
	appliquer()
	Touches.appliquer(touches)


func charger() -> void:
	var fichier := ConfigFile.new()
	# Un fichier absent n'est pas une erreur : c'est le premier lancement.
	if fichier.load(chemin) != OK:
		return
	volume_general = clampf(float(fichier.get_value("son", "general", volume_general)), 0.0, 1.0)
	volume_effets = clampf(float(fichier.get_value("son", "effets", volume_effets)), 0.0, 1.0)
	volume_musique = clampf(float(fichier.get_value("son", "musique", volume_musique)), 0.0, 1.0)
	son_coupe = bool(fichier.get_value("son", "coupe", son_coupe))
	tactile = clampi(int(fichier.get_value("commandes", "tactile", tactile)), Tactile.AUTO, Tactile.JAMAIS)
	acceleration_auto = bool(fichier.get_value("commandes", "acceleration_auto", acceleration_auto))
	vibrations = bool(fichier.get_value("commandes", "vibrations", vibrations))
	joystick = bool(fichier.get_value("commandes", "joystick", joystick))
	sensibilite_joystick = clampf(float(fichier.get_value("commandes", "sensibilite", sensibilite_joystick)),
		SENSIBILITE_MIN, SENSIBILITE_MAX)
	touches.clear()
	if fichier.has_section("touches"):
		for action in fichier.get_section_keys("touches"):
			touches[action] = fichier.get_value("touches", action)
	mini_carte = bool(fichier.get_value("affichage", "mini_carte", mini_carte))
	afficher_fps = bool(fichier.get_value("affichage", "fps", afficher_fps))
	qualite = clampi(int(fichier.get_value("affichage", "qualite", qualite)),
		QualiteGraphique.Niveau.AUTO, QualiteGraphique.Niveau.BASSE)
	pseudo = str(fichier.get_value("reseau", "pseudo", pseudo))
	derniere_adresse = str(fichier.get_value("reseau", "adresse", derniere_adresse))
	course.classe = clampi(int(fichier.get_value("course", "cylindree", course.classe)),
		Cylindree.Classe.CC50, Cylindree.Classe.CC200)
	course.modele = clampi(int(fichier.get_value("garage", "modele", course.modele)), 0, ModeleKart.nombre() - 1)
	course.couleur = posmod(int(fichier.get_value("garage", "couleur", course.couleur)), ModeleKart.COULEURS.size())
	_trophees.clear()
	if fichier.has_section("trophees"):
		for cle in fichier.get_section_keys("trophees"):
			_trophees[cle] = int(fichier.get_value("trophees", cle))
	_records.clear()
	if fichier.has_section("records"):
		for cle in fichier.get_section_keys("records"):
			_records[cle] = float(fichier.get_value("records", cle))


func sauver() -> void:
	var fichier := ConfigFile.new()
	fichier.set_value("son", "general", volume_general)
	fichier.set_value("son", "effets", volume_effets)
	fichier.set_value("son", "musique", volume_musique)
	fichier.set_value("son", "coupe", son_coupe)
	fichier.set_value("commandes", "tactile", tactile)
	fichier.set_value("commandes", "acceleration_auto", acceleration_auto)
	fichier.set_value("commandes", "vibrations", vibrations)
	fichier.set_value("commandes", "joystick", joystick)
	fichier.set_value("commandes", "sensibilite", sensibilite_joystick)
	for action in touches:
		fichier.set_value("touches", action, touches[action])
	fichier.set_value("affichage", "mini_carte", mini_carte)
	fichier.set_value("affichage", "fps", afficher_fps)
	fichier.set_value("affichage", "qualite", qualite)
	fichier.set_value("reseau", "pseudo", pseudo)
	fichier.set_value("reseau", "adresse", derniere_adresse)
	fichier.set_value("course", "cylindree", course.classe)
	fichier.set_value("garage", "modele", course.modele)
	fichier.set_value("garage", "couleur", course.couleur)
	for cle in _records:
		fichier.set_value("records", cle, _records[cle])
	for cle in _trophees:
		fichier.set_value("trophees", cle, _trophees[cle])
	var err := fichier.save(chemin)
	if err != OK:
		push_warning("réglages non enregistrés (%s) : erreur %d" % [chemin, err])


## Pousse les réglages vers le mixeur, prévient ceux qui écoutent, et écrit le
## fichier. Chaque écran d'options appelle ceci après chaque geste : un réglage
## qui ne survit pas à la fermeture du jeu n'en est pas un.
func valider() -> void:
	appliquer()
	sauver()
	changed.emit()


func appliquer() -> void:
	var general := AudioServer.get_bus_index(&"Master")
	if general >= 0:
		AudioServer.set_bus_volume_db(general, volume_en_db(volume_general))
		AudioServer.set_bus_mute(general, son_coupe or volume_general <= 0.0)
	var effets := AudioServer.get_bus_index(BUS_EFFETS)
	if effets >= 0:
		AudioServer.set_bus_volume_db(effets, volume_en_db(volume_effets))
		AudioServer.set_bus_mute(effets, volume_effets <= 0.0)
	var musique := AudioServer.get_bus_index(BUS_MUSIQUE)
	if musique >= 0:
		AudioServer.set_bus_volume_db(musique, volume_en_db(volume_musique))
		AudioServer.set_bus_mute(musique, volume_musique <= 0.0)
	appliquer_graphismes()


## La résolution 3D vaut pour tout le jeu ; ombres, lueur et brouillard pour
## la scène en cours. Une course qui démarre les règle elle-même
## (RaceLauncher) : elle n'est pas encore dans l'arbre quand on la monte.
func appliquer_graphismes() -> void:
	if not is_inside_tree():
		return
	var fenetre := get_tree().root
	fenetre.scaling_3d_scale = QualiteGraphique.echelle_3d(qualite)
	if get_tree().current_scene != null:
		QualiteGraphique.appliquer_a(get_tree().current_scene, qualite)


## linear_to_db(0) vaut -inf, que le mixeur n'aime pas : le silence passe par
## la coupure du bus, et le plancher reste un nombre.
static func volume_en_db(lineaire: float) -> float:
	return maxf(linear_to_db(clampf(lineaire, 0.0, 1.0)), -80.0)


## Montre-t-on les commandes à l'écran ? En automatique, dès que l'appareil a
## un écran tactile : un portable Windows tactile en profite aussi, et il garde
## son clavier.
func tactile_actif() -> bool:
	match tactile:
		Tactile.TOUJOURS:
			return true
		Tactile.JAMAIS:
			return false
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


static func cle_de_record(id_piste: String, tours: int) -> String:
	return "%s_%dt" % [id_piste, tours]


## Meilleur temps enregistré, ou une valeur négative s'il n'y en a pas.
func record(id_piste: String, tours: int) -> float:
	return float(_records.get(cle_de_record(id_piste, tours), -1.0))


## Enregistre le temps s'il bat le record, et dit si c'est le cas.
func proposer_record(id_piste: String, tours: int, temps: float) -> bool:
	if temps <= 0.0:
		return false
	var actuel := record(id_piste, tours)
	if actuel > 0.0 and temps >= actuel:
		return false
	_records[cle_de_record(id_piste, tours)] = temps
	sauver()
	return true


static func cle_de_trophee(coupe: int, classe: int) -> String:
	return "coupe%d_%s" % [coupe, Cylindree.nom(classe)]


## Meilleure place obtenue dans cette coupe et cette cylindrée : 1, 2 ou 3
## pour un trophée, 0 si le podium n'a jamais été atteint.
func trophee(coupe: int, classe: int) -> int:
	return int(_trophees.get(cle_de_trophee(coupe, classe), 0))


## Garde la place si elle est sur le podium et meilleure que la précédente,
## et dit si c'est le cas.
func proposer_trophee(coupe: int, classe: int, place: int) -> bool:
	if place < 1 or place > 3:
		return false
	var actuel := trophee(coupe, classe)
	if actuel > 0 and place >= actuel:
		return false
	_trophees[cle_de_trophee(coupe, classe)] = place
	sauver()
	return true


## La 200cc : l'or dans toutes les coupes en 150cc.
func debloque_200cc() -> bool:
	return _or_partout(Cylindree.Classe.CC150)


## Le miroir : l'or dans toutes les coupes en 100cc.
func debloque_miroir() -> bool:
	return _or_partout(Cylindree.Classe.CC100)


func _or_partout(classe: int) -> bool:
	for i in TrackCatalog.COUPES.size():
		if trophee(i, classe) != 1:
			return false
	return true


## Remplace une touche et l'enregistre (voir Touches.remplacer).
func changer_touche(action: StringName, nouveau: InputEvent) -> void:
	for changee in Touches.remplacer(action, nouveau):
		touches[String(changee)] = Touches.decrire_action(changee)
	sauver()


## Les commandes d'origine, pour toutes les actions.
func reinitialiser_touches() -> void:
	touches.clear()
	Touches.appliquer(touches)
	sauver()
