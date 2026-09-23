class_name SnapshotBuffer
extends RefCounted

## Les derniers états reçus d'un kart distant, et de quoi en tirer une
## position à montrer.
##
## Chaque état arrive avec son instant de capture, ramené à l'horloge locale.
## On montre le kart là où il est MAINTENANT selon toute vraisemblance : le
## dernier état reçu, prolongé du temps qu'il a mis à venir, en ligne droite
## ou en virage selon ce que faisaient les deux derniers. Afficher le passé
## avec un retard fixe, comme avant, ajoutait ce retard au trajet réseau : un
## kart que l'on voyait côte à côte avait en vérité deux longueurs d'avance.
##
## Quand un nouvel état contredit la prédiction — l'autre a freiné, tourné —
## le kart ne saute pas à sa nouvelle place : l'écart est rattrapé en
## quelques images. Au-delà d'ECART_MAX, on saute : c'est une remise en piste.

## Au-delà, faute de nouvelles, on ne prolonge plus : on attend.
const EXTRAPOLATION_MAX := 0.3
## Vitesse de rattrapage d'une erreur de prédiction, par seconde : l'écart est
## divisé par e toutes les 1/LISSAGE secondes.
const LISSAGE := 15.0
const ECART_MAX := 5.0
## Rotation au-delà de laquelle on ne croit plus l'estimation : un choc ou une
## remise en piste entre deux états, pas un virage.
const ROTATION_MAX := 4.0
const CAPACITE := 20

## Retard d'affichage volontaire, en secondes. Zéro : on prédit le présent.
## Un retard montre des positions sûres, interpolées, mais en retard d'autant.
var retard: float = 0.0

var _temps: PackedFloat64Array = []
var _etats: Array[PackedFloat32Array] = []
var _ecart := Vector3.ZERO
var _ecart_depuis: float = 0.0


## `maintenant` sert à lisser le passage de l'ancienne prédiction à la
## nouvelle ; sans lui, on considère que l'état arrive à l'instant même où il
## a été pris.
func ajouter(instant: float, etat: PackedFloat32Array, maintenant: float = -1.0) -> void:
	# Un paquet arrivé en retard sur un plus récent est jeté : remonter le
	# temps ferait reculer le kart.
	if not _temps.is_empty() and instant <= _temps[_temps.size() - 1]:
		return
	if maintenant < 0.0:
		maintenant = instant
	var avant := Vector3.ZERO
	var avait := not _etats.is_empty()
	if avait:
		avant = KartSnapshot.position(_brut(maintenant)) + _ecart_a(maintenant)
	_temps.append(instant)
	_etats.append(etat)
	while _temps.size() > CAPACITE:
		_temps.remove_at(0)
		_etats.remove_at(0)
	if not avait:
		return
	var ecart := avant - KartSnapshot.position(_brut(maintenant))
	_ecart = ecart if ecart.length() <= ECART_MAX else Vector3.ZERO
	_ecart_depuis = maintenant


func est_vide() -> bool:
	return _etats.is_empty()


func dernier() -> PackedFloat32Array:
	return _etats[_etats.size() - 1] if not _etats.is_empty() else PackedFloat32Array()


func dernier_instant() -> float:
	return _temps[_temps.size() - 1] if not _temps.is_empty() else 0.0


## L'état à montrer à `maintenant`.
func echantillonner(maintenant: float) -> PackedFloat32Array:
	if _etats.is_empty():
		return PackedFloat32Array()
	var r := _brut(maintenant)
	var ecart := _ecart_a(maintenant)
	if ecart != Vector3.ZERO:
		r[KartSnapshot.PX] += ecart.x
		r[KartSnapshot.PY] += ecart.y
		r[KartSnapshot.PZ] += ecart.z
	return r


func _ecart_a(maintenant: float) -> Vector3:
	return _ecart * exp(-LISSAGE * maxf(maintenant - _ecart_depuis, 0.0))


## La position vraisemblable, sans lissage.
func _brut(maintenant: float) -> PackedFloat32Array:
	var cible := maintenant - retard
	if cible <= _temps[0]:
		return _etats[0]
	for i in range(_temps.size() - 1):
		if cible <= _temps[i + 1]:
			var t := (cible - _temps[i]) / maxf(_temps[i + 1] - _temps[i], 0.0001)
			return KartSnapshot.melanger(_etats[i], _etats[i + 1], t)
	var duree := minf(cible - dernier_instant(), EXTRAPOLATION_MAX)
	return KartSnapshot.prolonger(dernier(), duree, _rotation())


## La vitesse de rotation du kart, tirée des deux derniers états.
func _rotation() -> float:
	var n := _etats.size()
	if n < 2:
		return 0.0
	var dt := _temps[n - 1] - _temps[n - 2]
	if dt <= 0.0 or dt > 0.25:
		return 0.0
	var w := angle_difference(_etats[n - 2][KartSnapshot.CAP_MARCHE], _etats[n - 1][KartSnapshot.CAP_MARCHE]) / dt
	return w if absf(w) <= ROTATION_MAX else 0.0
