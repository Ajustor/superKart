extends SceneTree

## Le profil d'une courbe de circuit, pour y placer murs, rampes et trous :
##
##   godot --headless --path . -s tools/profil_circuit.gd -- <courbe> [pas]
##
## Tous les `pas` mètres : la position, le rayon du virage (signé : positif à
## droite), le dévers et la pente. Puis les lignes droites, où poser une
## rampe ; et les endroits où deux portions du tracé se frôlent. Là, le point
## le plus proche de la courbe peut sauter d'une portion à l'autre : le
## classement et les remises en piste se tromperaient de tronçon. Un pont
## doit passer assez haut pour que ça n'arrive pas.

## En deçà, deux portions éloignées le long du tracé sont trop proches.
const FROLE := 26.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var courbe: Curve3D = load(args[0] if not args.is_empty() else "res://resources/tracks/track_01_curve.tres")
	var pas: float = float(args[1]) if args.size() > 1 else 10.0
	var c := TrackCurve.new(courbe, 9.0)
	print("longueur %.1f m, rayon le plus serré %.1f m" % [c.length, TrackSmoother.rayon_le_plus_serre(courbe)])
	print("   d      x      y      z   rayon  dévers  pente")
	var d := 0.0
	while d < c.length:
		var p := c.position_at(d)
		var virage := c.turn_at(d)
		var rayon := c.radius_at(d)
		print("%5.0f %6.1f %6.1f %6.1f %7s %5.1f° %5.1f%%" % [d, p.x, p.y, p.z,
			("%+.0f" % (rayon * signf(virage))) if rayon < 400.0 else "droit",
			rad_to_deg(c.tilt_at(d)), c.slope_at(d) * 100.0])
		d += pas

	print("\nlignes droites (rayon > 150 m sur au moins 40 m) :")
	var debut := -1.0
	d = 0.0
	while d <= c.length:
		var droit := c.radius_at(d) > 150.0 and d < c.length
		if droit and debut < 0.0:
			debut = d
		elif not droit and debut >= 0.0:
			if d - debut >= 40.0:
				print("  %4.0f → %4.0f m (%3.0f m)" % [debut, d, d - debut])
			debut = -1.0
		d += 2.0

	print("\nportions qui se frôlent (moins de %.0f m, à plus de 80 m le long du tracé) :" % FROLE)
	var vus := 0
	d = 0.0
	while d < c.length:
		var p := c.position_at(d)
		var pire := INF
		var ou := 0.0
		var e := 0.0
		while e < c.length:
			var le_long := absf(wrapf(e - d, -c.length * 0.5, c.length * 0.5))
			if le_long > 80.0:
				var ecart := p.distance_to(c.position_at(e))
				if ecart < pire:
					pire = ecart
					ou = e
			e += 4.0
		if pire < FROLE:
			var q := c.position_at(ou)
			print("  %4.0f m et %4.0f m : %.1f m (dont %.1f m de hauteur)" % [d, ou, pire, absf(p.y - q.y)])
			vus += 1
		d += 4.0
	if vus == 0:
		print("  aucune")
	quit()
