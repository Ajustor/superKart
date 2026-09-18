class_name RaceProgress
extends RefCounted

## Transforme une position en progression de course. Le spec a renoncé aux
## checkpoints posés à la main : une distance cumulée le long de l'axe suffit,
## elle augmente en avançant et diminue en reculant, donc faire demi-tour ne
## permet pas de gagner un tour.
##
## Comme TrackCurve et KartMotor, cette classe ne connaît ni la scène ni les
## nœuds : on lui donne un point, elle met son état à jour.

var track: TrackCurve

var lap: int = 0
var distance: float = 0.0   ## position le long de l'axe, dans [0, length)
var total: float = 0.0      ## distance cumulée depuis le départ, signée

var _demarre: bool = false


func _init(track_curve: TrackCurve) -> void:
	track = track_curve


func update(point: Vector3) -> void:
	var d := track.distance_of(point)

	if not _demarre:
		_demarre = true
		distance = d
		total = d
		return

	# Le déplacement réel sur une boucle est le chemin le plus court, pas la
	# différence brute des coordonnées : sans ça, deux centimètres de
	# tremblement au-dessus de la ligne se lisent comme un tour complet, et le
	# compteur oscille pendant que le kart attend le départ, immobile.
	total += wrapf(d - distance, -track.length * 0.5, track.length * 0.5)
	distance = d

	# Un kart qui recule avant même d'être parti reste au tour zéro : la
	# distance cumulée peut devenir négative, le numéro de tour non.
	lap = maxi(floori(total / track.length), 0)
