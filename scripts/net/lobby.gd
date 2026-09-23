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


func ajouter(peer: int, nom: String) -> String:
	var propre := nettoyer(nom)
	var final := propre
	var n := 2
	while noms().has(final):
		final = "%s %d" % [propre, n]
		n += 1
	joueurs[peer] = final
	if not ordre.has(peer):
		ordre.append(peer)
	return final


func retirer(peer: int) -> void:
	joueurs.erase(peer)
	ordre.erase(peer)


func est_plein() -> bool:
	return joueurs.size() >= PLACES


func noms() -> Array:
	return joueurs.values()


## Un pseudo sûr : pas vide, pas démesuré, sans retour à la ligne.
static func nettoyer(nom: String) -> String:
	var propre := nom.strip_edges().replace("\n", " ").left(16)
	return propre if propre != "" else "Pilote"


## Ce qu'on envoie aux clients : un tableau de [peer, nom] dans l'ordre
## d'arrivée, que chacun relit avec `depuis_liste`.
func en_liste() -> Array:
	var liste := []
	for peer in ordre:
		liste.append([peer, joueurs[peer]])
	return liste


func depuis_liste(liste: Array) -> void:
	joueurs.clear()
	ordre.clear()
	for paire in liste:
		joueurs[int(paire[0])] = str(paire[1])
		ordre.append(int(paire[0]))


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
		plan[gid] = {gid = gid, peer = humains[k], nom = joueurs[humains[k]], niveau_ia = 0}
	var niveau := 1
	for gid in PLACES:
		if plan[gid] == null:
			plan[gid] = {gid = gid, peer = 0, nom = NOMS_IA[niveau - 1], niveau_ia = niveau}
			niveau += 1
	return plan
