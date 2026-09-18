extends SceneTree

## Génère la courbe du circuit 1 et l'enregistre en ressource.
## Lancer une seule fois :
##   godot --headless --script tools/build_track_01.gd
## La courbe reste ensuite éditable à la souris dans l'éditeur.

const SORTIE := "res://resources/tracks/track_01_curve.tres"

## Circuit côtier : une boucle large et rapide, avec une véritable épingle
## sur la portion nord (la plus lente du tour) pour donner au dérapage de
## quoi s'exprimer, et le reste de la boucle qui reste franchissable à pleine
## vitesse. Les points sont donnés dans le sens de la marche ; les poignées
## sont calculées pour lisser le tout.
##
## L'épingle (points 4-6) a été réglée par recherche de paramètres plutôt que
## deviné : un triangle symétrique (écart 80 m entre l'entrée et la sortie,
## apex poussé de 30 m) donne un rayon minimal d'environ 11,7 m au sommet —
## dans la fenêtre visée de 10-13 m, sans à-coup sur le lacet.
const POINTS: Array[Vector3] = [
	Vector3(0, 0, -120),
	Vector3(90, 0, -110),
	Vector3(140, 0, -40),
	Vector3(120, 0, 40),
	Vector3(30, 0, 60),
	Vector3(-10, 0, 90),
	Vector3(-50, 0, 60),
	Vector3(-130, 0, 10),
	Vector3(-110, 0, -70),
	Vector3(-50, 0, -120),
]


func _init() -> void:
	var courbe := Curve3D.new()
	var n := POINTS.size()
	for i in n:
		var precedent := POINTS[(i - 1 + n) % n]
		var suivant := POINTS[(i + 1) % n]
		# Poignées façon Catmull-Rom : la tangente en un point suit la corde
		# entre ses deux voisins, ce qui donne une boucle lisse et fermée.
		var tangente := (suivant - precedent) / 6.0
		courbe.add_point(POINTS[i], -tangente, tangente)
	# On referme explicitement en répétant le premier point.
	courbe.add_point(POINTS[0], -courbe.get_point_out(0), courbe.get_point_out(0))

	DirAccess.make_dir_recursive_absolute("res://resources/tracks")
	var err := ResourceSaver.save(courbe, SORTIE)
	if err != OK:
		printerr("échec de l'écriture de la courbe : %d" % err)
		quit(1)
		return
	print("circuit 1 écrit, longueur %.1f m" % courbe.get_baked_length())
	quit()
