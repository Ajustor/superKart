class_name RaceSetup
extends RefCounted

## Ce que le joueur a choisi au menu : le circuit, le nombre de tours et sa
## case de départ. Rien ici ne touche à la scène — c'est RaceLauncher qui en
## tire une course.

## Case de départ tirée au sort au lancement de chaque course.
const CASE_ALEATOIRE := 0

## Nombre de karts sur la grille de race.tscn : le menu en tire la liste des
## cases proposées. RaceLauncher, lui, relit la scène.
const CONCURRENTS := 8

var piste: TrackInfo
var tours: int = 3

## 1 = pole position. CASE_ALEATOIRE pour laisser le sort décider.
var case_de_depart: int = CASE_ALEATOIRE


func _init() -> void:
	if not TrackCatalog.PISTES.is_empty():
		choisir_piste(TrackCatalog.PISTES[0])


func choisir_piste(info: TrackInfo) -> void:
	piste = info
	tours = info.tours


## La case réellement attribuée, de 1 à `concurrents`. Le tirage se fait ici
## et pas dans la session : la session reçoit une case, elle ne joue pas aux dés.
func case_effective(concurrents: int, rng: RandomNumberGenerator) -> int:
	if case_de_depart == CASE_ALEATOIRE:
		return rng.randi_range(1, concurrents)
	return clampi(case_de_depart, 1, concurrents)
