class_name Personnage
extends RefCounted

## Les pilotes qu'on assoit dans les karts : les Mini Characters de Kenney
## (CC0, assets/kenney/LICENCE.txt), au volant (leur animation « drive »).
##
## Un pilote ne change rien au kart : c'est un choix d'allure, et le ton de
## son klaxon.

const DOSSIER := "res://assets/kenney/pilotes/"

const PERSONNAGES := [
	{nom = "Théo", modele = "character-male-a", origine = "Le cerveau de l'écurie : il a calculé chaque virage.", klaxon = 1.05},
	{nom = "Gus", modele = "character-male-b", origine = "Mécano depuis toujours, il entend un boulon desserré à cent mètres.", klaxon = 0.75},
	{nom = "Max", modele = "character-male-c", origine = "Agent de la circulation… qui ne respecte aucune limite de vitesse.", klaxon = 0.9},
	{nom = "Victor", modele = "character-male-d", origine = "Il court en costume trois-pièces, et ne froisse jamais rien.", klaxon = 0.85},
	{nom = "Léon", modele = "character-male-e", origine = "Bricoleur du dimanche : son kart tient avec du ruban adhésif.", klaxon = 0.95},
	{nom = "Sami", modele = "character-male-f", origine = "Toujours en retard, donc toujours à fond.", klaxon = 1.15},
	{nom = "Inès", modele = "character-female-a", origine = "Rien ne l'arrête, surtout pas un virage serré.", klaxon = 1.25},
	{nom = "Lou", modele = "character-female-b", origine = "Elle a appris à conduire avant de savoir marcher.", klaxon = 1.4},
	{nom = "Nina", modele = "character-female-c", origine = "Sa casquette ne s'envole jamais, même à pleine vitesse.", klaxon = 1.3},
	{nom = "Claire", modele = "character-female-d", origine = "Directrice d'écurie : elle a toujours un plan.", klaxon = 1.1},
	{nom = "Mei", modele = "character-female-e", origine = "Championne de glisse : ses mini-turbos sont toujours violets.", klaxon = 1.35},
	{nom = "Zoé", modele = "character-female-f", origine = "Sac au dos, prête à partir à l'aventure au premier feu vert.", klaxon = 1.2},
]

enum { THEO, GUS, MAX, VICTOR, LEON, SAMI, INES, LOU, NINA, CLAIRE, MEI, ZOE }

## L'animation jouée au volant.
const ANIMATION := "drive"

static var _scenes: Dictionary = {}


static func nombre() -> int:
	return PERSONNAGES.size()


static func donnees(i: int) -> Dictionary:
	return PERSONNAGES[clampi(i, 0, PERSONNAGES.size() - 1)]


static func nom(i: int) -> String:
	return donnees(i).nom


static func origine(i: int) -> String:
	return donnees(i).origine


static func hauteur_klaxon(i: int) -> float:
	return float(donnees(i).klaxon)


static func scene(i: int) -> PackedScene:
	var chemin: String = DOSSIER + str(donnees(i).modele) + ".glb"
	if not _scenes.has(chemin):
		_scenes[chemin] = load(chemin)
	return _scenes[chemin]


## Les pilotes de l'IA : ceux que personne n'a pris, dans l'ordre, puis on
## recommence.
static func libres(pris: Array) -> Array[int]:
	var reste: Array[int] = []
	for i in nombre():
		if not pris.has(i):
			reste.append(i)
	if reste.is_empty():
		for i in nombre():
			reste.append(i)
	return reste


## Assoit le pilote `i` dans le kart (ou la vitrine du garage), sur le siège
## du kart Kenney : remplace celui qui y était, et règle le klaxon.
static func habiller(kart: Node3D, i: int) -> void:
	var caisse := kart.get_node_or_null("Body") as Node3D
	if caisse == null:
		return
	var ancien := caisse.get_node_or_null("Pilote")
	if ancien != null:
		caisse.remove_child(ancien)
		ancien.free()
	var pilote := scene(i).instantiate() as Node3D
	pilote.name = "Pilote"
	pilote.set_meta("personnage", clampi(i, 0, nombre() - 1))
	var train := ModeleKart.ROUES_STANDARD
	if kart.has_meta("train"):
		train = int(kart.get_meta("train"))
	pilote.transform = ModeleKart.siege(train)
	var anim := pilote.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var conduit := anim != null and anim.has_animation(ANIMATION)
	if conduit:
		anim.get_animation(ANIMATION).loop_mode = Animation.LOOP_LINEAR
		anim.autoplay = ANIMATION
	caisse.add_child(pilote)
	if conduit and anim.is_inside_tree():
		anim.play(ANIMATION)
	if kart is Kart:
		(kart as Kart).hauteur_klaxon = hauteur_klaxon(i)


## Le pilote assis dans ce kart, -1 s'il n'y en a pas.
static func pilote_de(kart: Node3D) -> int:
	var pilote := kart.get_node_or_null("Body/Pilote")
	return int(pilote.get_meta("personnage", -1)) if pilote != null else -1
