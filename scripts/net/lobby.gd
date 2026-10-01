class_name Lobby
extends RefCounted

## Le salon d'une partie en réseau : qui est là, et comment la grille sera
## remplie. Ne connaît rien au réseau lui-même — l'hôte le tient à jour à
## chaque arrivée et départ, et l'envoie tel quel à tous. C'est aussi ce qui
## le rend testable sans ouvrir un seul port.

## Places sur la grille. Les humains en prennent jusqu'à ce nombre, l'IA
## complète le reste.
const PLACES := 8

## Les noms des pilotes IA, du plus rapide au plus lent : ce sont ceux de
## race.tscn, où AIKart1 est le meilleur.
const NOMS_IA: Array[String] = ["Turbo", "Zéphyr", "Piston", "Comète", "Bielle", "Rafale", "Gomme"]

## peer id -> nom affiché. L'ordre d'arrivée est gardé à part : un
## Dictionary garde bien l'ordre d'insertion, mais l'envoyer par le réseau
## et le relire ne le garantit pas partout.
var joueurs: Dictionary = {}
var ordre: Array[int] = []
## peer id -> [modele, couleur] : le kart choisi au garage (ModeleKart).
var vehicules: Dictionary = {}


func ajouter(peer: int, nom: String) -> String:
	var propre := nettoyer(nom)
	var final := propre
	var n := 2
	# Pas le nom d'un pilote IA non plus : les points d'une coupe se tiennent
	# par nom, un joueur « Turbo » partagerait ceux de l'IA.
	while noms().has(final) or NOMS_IA.has(final):
		final = "%s %d" % [propre, n]
		n += 1
	joueurs[peer] = final
	if not ordre.has(peer):
		ordre.append(peer)
	return final


func retirer(peer: int) -> void:
	joueurs.erase(peer)
	ordre.erase(peer)
	vehicules.erase(peer)


func choisir_vehicule(peer: int, modele: int, couleur: int) -> void:
	vehicules[peer] = [clampi(modele, 0, ModeleKart.nombre() - 1), posmod(couleur, ModeleKart.COULEURS.size())]


func vehicule(peer: int) -> Array:
	return vehicules.get(peer, [ModeleKart.STANDARD, 0])


func est_plein() -> bool:
	return joueurs.size() >= PLACES


## Le chef du salon : le premier arrivé encore là. C'est l'hôte quand il
## joue ; sur un serveur en ligne, qui n'a pas de pilote, c'est le premier
## joueur, et le suivant prend la main s'il s'en va. 0 : salon vide.
func chef() -> int:
	return ordre[0] if not ordre.is_empty() else 0


func noms() -> Array:
	return joueurs.values()


## Un pseudo sûr : pas vide, pas démesuré, sans retour à la ligne.
static func nettoyer(nom: String) -> String:
	var propre := nom.strip_edges().replace("\n", " ").left(16)
	return propre if propre != "" else "Pilote"


## Ce qu'on envoie aux clients : un tableau de [peer, nom, modele, couleur]
## dans l'ordre d'arrivée, que chacun relit avec `depuis_liste`.
func en_liste() -> Array:
	var liste := []
	for peer in ordre:
		var v := vehicule(peer)
		liste.append([peer, joueurs[peer], v[0], v[1]])
	return liste


func depuis_liste(liste: Array) -> void:
	joueurs.clear()
	ordre.clear()
	vehicules.clear()
	for ligne in liste:
		joueurs[int(ligne[0])] = str(ligne[1])
		ordre.append(int(ligne[0]))
		if ligne.size() >= 4:
			choisir_vehicule(int(ligne[0]), int(ligne[2]), int(ligne[3]))


## La grille de la course : une entrée par place, dans l'ordre des places
## (gid 0 = pole position). Chaque entrée dit qui la prend : un humain (son
## peer id et son nom) ou une IA (son niveau, 1 = la plus rapide).
##
## Les humains sont répartis au hasard sur la grille ; l'IA remplit les places
## restantes de la plus rapide, devant, à la plus lente — comme en solo.
func plan_de_course(rng: RandomNumberGenerator) -> Array:
	var places := range(PLACES)
	# Mélange de Fisher-Yates avec le générateur fourni : reproductible en test.
	for i in range(places.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = places[i]
		places[i] = places[j]
		places[j] = t

	var plan := []
	plan.resize(PLACES)
	var humains := ordre.slice(0, PLACES)
	for k in humains.size():
		var gid: int = places[k]
		var v := vehicule(humains[k])
		plan[gid] = {gid = gid, peer = humains[k], nom = joueurs[humains[k]], niveau_ia = 0,
			modele = v[0], couleur = v[1]}
	var niveau := 1
	for gid in PLACES:
		if plan[gid] == null:
			plan[gid] = {gid = gid, peer = 0, nom = NOMS_IA[niveau - 1], niveau_ia = niveau}
			niveau += 1
	return plan


## La grille d'une manche de coupe : les mêmes pilotes qu'un plan ordinaire,
## mais chacun repart de sa place d'arrivée à la course précédente. Ceux
## qui n'y étaient pas (un joueur parti, remplacé) ferment la grille.
func plan_de_coupe(gp: GrandPrix, rng: RandomNumberGenerator) -> Array:
	var base := plan_de_course(rng)
	if gp == null or gp.dernieres_places.is_empty():
		return base
	var pilotes := base.duplicate()
	pilotes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(gp.dernieres_places.get(a.nom, 99))
		var pb := int(gp.dernieres_places.get(b.nom, 99))
		if pa != pb:
			return pa < pb
		return int(a.gid) < int(b.gid))
	var plan := []
	for gid in pilotes.size():
		var place: Dictionary = pilotes[gid].duplicate()
		place.gid = gid
		plan.append(place)
	return plan
