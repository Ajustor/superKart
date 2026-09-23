extends SceneTree

## Génère la courbe d'un des circuits dessinés ici, et l'enregistre en
## ressource. Comme build_track_01.gd : à lancer une fois, puis la courbe se
## retouche à la souris dans l'éditeur.
##
##   godot --headless --path . -s tools/build_track_curves.gd -- <id> [--force]
##   godot --headless --path . -s tools/shape_track_curve.gd -- <courbe> <rayon_min> <devers_max>
##
## Le second passage ouvre les virages trop serrés et relève les autres ; les
## éléments (murs, rampes, trous…) se placent ensuite, dans la scène du
## circuit, aux distances que donne tools/profil_circuit.gd.
##
## Les points sont donnés dans le sens de la marche, altitude comprise. Le
## premier est la ligne de départ : le dernier tronçon, qui y ramène, doit
## être droit, la grille s'y range.

const CIRCUITS := {
	# Un bord de mer : une ligne droite sur la plage, une dune qu'on
	# franchit d'un bond, un lacet autour du phare, et un bras de mer à
	# sauter avant de revenir.
	"plage_palmiers": [
		Vector3(0, 0, 0),
		Vector3(80, 0, 0),
		Vector3(140, 1, -25),
		Vector3(165, 3, -85),
		Vector3(145, 4, -145),
		Vector3(95, 1, -170),
		Vector3(40, 0, -150),
		Vector3(-5, 0, -175),
		Vector3(-35, 0, -230),
		Vector3(-15, 0, -285),
		Vector3(-75, 0, -300),
		Vector3(-120, 0, -250),
		Vector3(-130, 0, -165),
		Vector3(-130, 0, -85),
		Vector3(-105, 0, -30),
		Vector3(-55, 0, 0),
	],
	# Un château : des couloirs droits, des virages à angle droit, une montée
	# vers les remparts, une chicane là-haut, et une douve de lave à sauter.
	"forteresse_lave": [
		Vector3(0, 0, 0),
		Vector3(90, 0, 0),
		Vector3(125, 0, -30),
		Vector3(125, 2, -95),
		Vector3(100, 6, -135),
		Vector3(40, 10, -140),
		Vector3(5, 10, -120),
		Vector3(-35, 10, -145),
		Vector3(-75, 10, -122),
		Vector3(-112, 7, -148),
		Vector3(-140, 2, -125),
		Vector3(-145, 0, -45),
		Vector3(-105, 0, 0),
	],
	# Un ruban suspendu dans le vide, en huit : il passe sous lui-même au
	# centre, vingt mètres plus bas, et finit sa boucle ouest par un grand saut.
	"ruban_celeste": [
		Vector3(-40, 20, -40),
		Vector3(40, 20, 40),
		Vector3(100, 24, 95),
		Vector3(170, 30, 65),
		Vector3(185, 34, -20),
		Vector3(135, 38, -75),
		Vector3(60, 40, -60),
		Vector3(-60, 40, 60),
		Vector3(-130, 36, 70),
		Vector3(-175, 31, 5),
		Vector3(-160, 26, -80),
		Vector3(-105, 22, -110),
		Vector3(-65, 20, -75),
	],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if not args.is_empty() else ""
	if not CIRCUITS.has(id):
		printerr("circuits connus : %s" % ", ".join(CIRCUITS.keys()))
		quit(1)
		return
	var sortie := "res://resources/tracks/%s_curve.tres" % id
	if FileAccess.file_exists(sortie) and not "--force" in args:
		printerr("%s existe déjà, et a peut-être été retouché à la souris depuis." % sortie)
		printerr("Relancer avec  --force  pour l'écraser délibérément.")
		quit(1)
		return

	var points: Array = CIRCUITS[id]
	var courbe := Curve3D.new()
	var n := points.size()
	for i in n:
		var precedent: Vector3 = points[(i - 1 + n) % n]
		var suivant: Vector3 = points[(i + 1) % n]
		# Poignées façon Catmull-Rom, comme pour le circuit 1.
		var tangente := (suivant - precedent) / 6.0
		courbe.add_point(points[i], -tangente, tangente)
	courbe.add_point(points[0], -courbe.get_point_out(0), courbe.get_point_out(0))

	var err := ResourceSaver.save(courbe, sortie)
	if err != OK:
		printerr("échec de l'écriture de la courbe : %d" % err)
		quit(1)
		return
	print("%s écrit, longueur %.1f m" % [sortie, courbe.get_baked_length()])
	quit()
