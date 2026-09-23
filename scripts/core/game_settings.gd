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

## Volumes linéaires, de 0 à 1 : c'est ce que montre un curseur. La conversion
## en décibels se fait au seul endroit où l'on parle au mixeur.
var volume_general: float = 0.8
var volume_effets: float = 1.0
var son_coupe: bool = false

var tactile: int = Tactile.AUTO

## Gaz tenus en permanence sur écran tactile : deux pouces ne suffisent pas à
## tenir l'accélérateur, braquer et déraper à la fois.
var acceleration_auto: bool = true

var vibrations: bool = true

## La dernière course réglée dans le menu. Rejouer la reprend telle quelle.
var course := RaceSetup.new()

var chemin: String = CHEMIN_PAR_DEFAUT

## Meilleur temps de course par identifiant de circuit et nombre de tours :
## un record en un tour ne se compare pas à un record en cinq.
var _records: Dictionary = {}


func _ready() -> void:
	charger()
	appliquer()


func charger() -> void:
	var fichier := ConfigFile.new()
	# Un fichier absent n'est pas une erreur : c'est le premier lancement.
	if fichier.load(chemin) != OK:
		return
	volume_general = clampf(float(fichier.get_value("son", "general", volume_general)), 0.0, 1.0)
	volume_effets = clampf(float(fichier.get_value("son", "effets", volume_effets)), 0.0, 1.0)
	son_coupe = bool(fichier.get_value("son", "coupe", son_coupe))
	tactile = clampi(int(fichier.get_value("commandes", "tactile", tactile)), Tactile.AUTO, Tactile.JAMAIS)
	acceleration_auto = bool(fichier.get_value("commandes", "acceleration_auto", acceleration_auto))
	vibrations = bool(fichier.get_value("commandes", "vibrations", vibrations))
	_records.clear()
	if fichier.has_section("records"):
		for cle in fichier.get_section_keys("records"):
			_records[cle] = float(fichier.get_value("records", cle))


func sauver() -> void:
	var fichier := ConfigFile.new()
	fichier.set_value("son", "general", volume_general)
	fichier.set_value("son", "effets", volume_effets)
	fichier.set_value("son", "coupe", son_coupe)
	fichier.set_value("commandes", "tactile", tactile)
	fichier.set_value("commandes", "acceleration_auto", acceleration_auto)
	fichier.set_value("commandes", "vibrations", vibrations)
	for cle in _records:
		fichier.set_value("records", cle, _records[cle])
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
