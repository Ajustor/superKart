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
var total: float = 0.0      ## distance parcourue depuis le départ, signée


## La distance de départ est donnée, jamais devinée : celui qui pose le kart
## la connaît. La redériver par projection revenait à interroger la courbe à
## l'endroit précis où elle est ambiguë — la couture — et un point posé un
## millimètre du mauvais côté offrait un tour complet.
func _init(track_curve: TrackCurve, start_distance: float) -> void:
	track = track_curve
	distance = track.wrap(start_distance)


func update(point: Vector3) -> void:
	var d := track.distance_of(point)

	# Le déplacement réel sur une boucle est le chemin le plus court, pas la
	# différence brute des coordonnées : sans ça, deux centimètres de
	# tremblement au-dessus de la ligne se lisent comme un tour complet, et le
	# compteur oscille pendant que le kart attend le départ, immobile.
	total += wrapf(d - distance, -track.length * 0.5, track.length * 0.5)
	distance = d

	# total part de zéro : le tour se compte sur ce qui a été roulé, pas sur la
	# position absolue. Deux karts sur une grille décalée doivent parcourir la
	# même distance pour boucler le même nombre de tours.
	#
	# Un kart qui recule avant même d'être parti reste au tour zéro : la
	# distance parcourue peut devenir négative, le numéro de tour non.
	lap = maxi(floori(total / track.length), 0)
