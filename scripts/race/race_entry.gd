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

## Nom affiché au classement et à l'écran de résultats.
var nom: String = ""

## Piloté par un humain, ici ou sur une autre machine. La mini-carte les
## distingue de l'IA.
var humain: bool = false

## Temps de course cumulé, décompte exclu. S'arrête à l'arrivée.
var temps_course: float = 0.0

## Ordre d'arrivée, 1 = vainqueur. Zéro tant que la ligne n'est pas franchie
## pour la dernière fois : c'est lui, et non la distance parcourue, qui classe
## ceux qui ont fini — un kart arrivé deuxième continue de rouler et finirait
## sinon par dépasser le vainqueur au classement.
var place_finale: int = 0

## Case occupée sur la grille, 0 = pole position. Classe les concurrents tant
## que personne n'a bougé.
var case_de_grille: int = 0

## L'emplacement d'objet. Ici plutôt que sur le kart : c'est un état de course,
## qui se vide et se remplit selon les règles de la course, pas de la physique.
var inventaire := KartInventory.new()

## Vrai depuis qu'un tremplin l'a fait décoller, jusqu'à ce qu'il retouche le
## sol. En vol, survoler le vide n'est pas une sortie de route.
var en_vol: bool = false

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
