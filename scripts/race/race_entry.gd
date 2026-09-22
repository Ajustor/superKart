class_name RaceEntry
extends RefCounted

## L'état de course d'un concurrent. Sorti de RaceSession quand la course est
## passée d'un kart à huit : chacun a sa progression, son chrono et sa place,
## et rien de tout ça ne doit se partager par accident.
##
## Comme RaceProgress et KartMotor, cette classe ne connaît pas l'arbre de
## scènes — elle détient une référence au kart, mais ne lit jamais sa position.

var kart: Kart
var progress: RaceProgress
var timer := RaceTimer.new()
var finished: bool = false

## Place au classement, 1 = premier. Zéro tant qu'aucun classement n'a été
## calculé : afficher « 0e » est une erreur visible, afficher « 1er » à tort
## ne l'est pas.
var position: int = 0

## Dernière distance à laquelle le kart roulait encore sur le bitume. Initialisée
## à la case de grille : sans ça, une sortie de route au premier virage
## renverrait à la ligne de départ un kart parti du fond.
var derniere_en_piste: float = 0.0

## Ligne de crue des tours comptés. Le numéro de tour de RaceProgress, lui,
## redescend quand le kart recule.
var tours_comptes: int = 0


func _init(pilote: Kart, piste: TrackCurve, depart: float) -> void:
	kart = pilote
	progress = RaceProgress.new(piste, depart)
	derniere_en_piste = piste.wrap(depart)
