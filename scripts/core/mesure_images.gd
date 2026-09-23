class_name MesureImages
extends RefCounted

## La durée des dernières images, et ce qu'on en tire : les images par
## seconde, la pire image de la dernière seconde, et le nombre d'à-coups
## depuis le début. Séparé de l'affichage pour se tester sans écran.
##
## La pire image compte autant que la moyenne : 60 images par seconde dont
## une de 200 ms, ça se voit comme un gel, et la moyenne ne le dit pas.

## Au-delà, une image est un à-coup : on la sent, même quand la moyenne est bonne.
const A_COUP_MS := 50.0
## Fenêtre des mesures glissantes, en secondes.
const FENETRE := 1.0

var _durees: PackedFloat32Array = []
var _total := 0.0
var a_coups: int = 0


## Une image vient de se terminer, après `ms` millisecondes.
func ajouter(ms: float) -> void:
	_durees.append(ms)
	_total += ms
	if ms > A_COUP_MS:
		a_coups += 1
	while _durees.size() > 1 and _total - _durees[0] >= FENETRE * 1000.0:
		_total -= _durees[0]
		_durees.remove_at(0)


func images_par_seconde() -> float:
	return 1000.0 * _durees.size() / _total if _total > 0.0 else 0.0


func duree_moyenne() -> float:
	return _total / _durees.size() if not _durees.is_empty() else 0.0


func pire() -> float:
	var p := 0.0
	for d in _durees:
		p = maxf(p, d)
	return p


func remettre_a_zero() -> void:
	_durees.clear()
	_total = 0.0
	a_coups = 0
