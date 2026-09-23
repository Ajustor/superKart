class_name SnapshotBuffer
extends RefCounted

## Les derniers états reçus d'un kart distant, et de quoi en tirer une
## position lisse. On affiche le kart avec un léger retard — le temps que le
## paquet suivant arrive — et on interpole entre les deux qui encadrent cet
## instant. Sans ce retard, chaque paquet en avance ou en retard se verrait
## comme un à-coup.

## Retard d'affichage, en secondes : environ trois paquets à 30 par seconde.
const RETARD := 0.1
## Au-delà, faute de nouvelles, on n'extrapole plus : on attend.
const EXTRAPOLATION_MAX := 0.25
const CAPACITE := 20

var _temps: PackedFloat64Array = []
var _etats: Array[PackedFloat32Array] = []


func ajouter(instant: float, etat: PackedFloat32Array) -> void:
	# Un paquet arrivé en retard sur un plus récent est jeté : le réseau ne
	# garantit pas l'ordre, et remonter le temps ferait reculer le kart.
	if not _temps.is_empty() and instant <= _temps[_temps.size() - 1]:
		return
	_temps.append(instant)
	_etats.append(etat)
	while _temps.size() > CAPACITE:
		_temps.remove_at(0)
		_etats.remove_at(0)


func est_vide() -> bool:
	return _etats.is_empty()


func dernier() -> PackedFloat32Array:
	return _etats[_etats.size() - 1] if not _etats.is_empty() else PackedFloat32Array()


## L'état à montrer à `maintenant`, affiché avec RETARD de décalage.
func echantillonner(maintenant: float) -> PackedFloat32Array:
	if _etats.is_empty():
		return PackedFloat32Array()
	var cible := maintenant - RETARD
	if cible <= _temps[0]:
		return _etats[0]
	for i in range(_temps.size() - 1):
		if cible <= _temps[i + 1]:
			var t := (cible - _temps[i]) / maxf(_temps[i + 1] - _temps[i], 0.0001)
			return KartSnapshot.melanger(_etats[i], _etats[i + 1], t)
	var retard := minf(cible - _temps[_temps.size() - 1], EXTRAPOLATION_MAX)
	return KartSnapshot.prolonger(dernier(), retard)
