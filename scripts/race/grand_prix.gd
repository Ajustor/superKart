class_name GrandPrix
extends RefCounted

## Une coupe en cours : quatre courses à la suite, les points du barème
## s'additionnent, et le classement final monte sur le podium.
##
## Vit dans RaceSetup, d'une course à l'autre : chaque manche est une course
## ordinaire que RaceLauncher monte à neuf ; la coupe ne fait que choisir le
## circuit, ranger la grille et tenir les comptes.

var coupe: int = 0
var classe: int = Cylindree.Classe.CC150

## Index de la course à courir, de 0 à manches() - 1. Égal à manches() une
## fois la dernière comptée.
var manche: int = 0

## Total des points par nom de pilote.
var points: Dictionary = {}

## Place de chacun à la dernière course : départage les égalités.
var dernieres_places: Dictionary = {}


func _init(index_coupe: int = 0, cylindree: int = Cylindree.Classe.CC150) -> void:
	coupe = clampi(index_coupe, 0, TrackCatalog.COUPES.size() - 1)
	classe = cylindree


func nom() -> String:
	return TrackCatalog.COUPES[coupe].nom


func manches() -> int:
	return TrackCatalog.COUPES[coupe].pistes.size()


func piste() -> TrackInfo:
	return TrackCatalog.par_id(TrackCatalog.COUPES[coupe].pistes[mini(manche, manches() - 1)])


func terminee() -> bool:
	return manche >= manches()


## Compte une course terminée : chacun marque les points de sa place. Ceux qui
## n'ont pas franchi la ligne prennent la place qu'ils occupaient — le joueur
## n'attend pas les derniers pour passer à la suite.
func compter(ordre_d_arrivee: PackedStringArray) -> void:
	if terminee():
		return
	for i in ordre_d_arrivee.size():
		var pilote := ordre_d_arrivee[i]
		points[pilote] = int(points.get(pilote, 0)) + RaceScoring.points_pour(i + 1)
		dernieres_places[pilote] = i + 1
	manche += 1


## Les noms, du premier au dernier de la coupe. À égalité de points, le
## mieux placé à la dernière course passe devant.
func classement() -> PackedStringArray:
	var noms: Array = points.keys()
	noms.sort_custom(func(a: String, b: String) -> bool:
		if points[a] != points[b]:
			return points[a] > points[b]
		return int(dernieres_places.get(a, 99)) < int(dernieres_places.get(b, 99)))
	return PackedStringArray(noms)


## Place dans la coupe, 1 pour le premier ; 0 pour un inconnu.
func place_de(pilote: String) -> int:
	return classement().find(pilote) + 1


## Les cases de départ (0 = pole) dans l'ordre de `noms`, rangées selon le
## classement de la coupe : le meneur part en tête. Vide avant la première
## course, où c'est le choix du joueur qui compte.
func cases(noms: PackedStringArray) -> Array[int]:
	var cases_: Array[int] = []
	if manche == 0 or points.is_empty():
		return cases_
	var ordre := classement()
	var suivante := ordre.size()
	for pilote in noms:
		var i := ordre.find(pilote)
		if i < 0:
			i = suivante
			suivante += 1
		cases_.append(i)
	return cases_
