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

	# Un saut de plus d'une demi-longueur entre deux relevés ne peut pas être
	# un vrai déplacement : c'est la ligne qu'on vient de franchir.
	var pas := d - distance
	if pas < -track.length * 0.5:
		lap += 1
	elif pas > track.length * 0.5:
		lap -= 1

	distance = d
	total = float(lap) * track.length + d
