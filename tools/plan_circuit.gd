extends SceneTree

## Le plan d'un circuit vu du ciel, en image : la route colorée selon
## l'altitude (bleu en bas, rouge en haut), un point blanc tous les 100 m et
## gris tous les 50 m depuis la ligne de départ (en vert), et, si l'on donne
## l'identifiant d'un circuit plutôt qu'une courbe, ses éléments : trous en
## noir, rampes et tremplins en cyan, tunnels en marron, obstacles en
## magenta, glace en blanc, vent et courants en jaune, anneaux en or.
##
##   godot --headless --path . -s tools/plan_circuit.gd -- <id ou courbe.tres> <sortie.png>

const TAILLE := 900
const MARGE := 30.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage : -- <id ou courbe.tres> <sortie.png>")
		quit(1)
		return
	var source: String = args[0]
	var piste: Track = null
	var courbe: Curve3D
	if source.ends_with(".tres"):
		courbe = load(source)
	else:
		courbe = load("res://resources/tracks/%s_curve.tres" % source)
		var scene := load("res://scenes/tracks/%s.tscn" % source) as PackedScene
		if scene != null:
			piste = scene.instantiate() as Track
	var c := TrackCurve.new(courbe, 9.0)
	var mini := Vector2(INF, INF)
	var maxi := Vector2(-INF, -INF)
	var bas := INF
	var haut := -INF
	var d := 0.0
	while d < c.length:
		var p := c.position_at(d)
		mini = mini.min(Vector2(p.x, p.z))
		maxi = maxi.max(Vector2(p.x, p.z))
		bas = minf(bas, p.y)
		haut = maxf(haut, p.y)
		d += 2.0
	var etendue := maxf(maxi.x - mini.x, maxi.y - mini.y) + MARGE * 2.0
	var echelle := float(TAILLE) / etendue
	var image := Image.create(TAILLE, TAILLE, false, Image.FORMAT_RGB8)
	image.fill(Color(0.12, 0.12, 0.14))
	var vers_image := func(p: Vector3) -> Vector2i:
		return Vector2i(int((p.x - mini.x + MARGE) * echelle), int((p.z - mini.y + MARGE) * echelle))
	# Du plus bas au plus haut : la route du dessus se dessine par-dessus.
	var points := []
	d = 0.0
	while d < c.length:
		points.append(d)
		d += 0.5
	points.sort_custom(func(a: float, b: float) -> bool: return c.position_at(a).y < c.position_at(b).y)
	var rayon := maxi(int(9.0 * echelle), 1)
	for e: float in points:
		var p := c.position_at(e)
		var t := (p.y - bas) / maxf(haut - bas, 0.01)
		_disque(image, vers_image.call(p), rayon, Color(t, 0.25, 1.0 - t).lerp(Color.WHITE, 0.1))
	if piste != null:
		piste.track_curve = c
		for element in piste.get_children():
			var f := element as TrackFeature
			if f == null:
				continue
			var teinte := Color.TRANSPARENT
			if f is TrackGap:
				teinte = Color.BLACK
			elif f is TrackTunnel:
				teinte = Color(0.55, 0.35, 0.15)
			elif f is TrackRamp or f is TrackJump:
				teinte = Color.CYAN
			elif f is TrackObstacle:
				teinte = Color.MAGENTA
			elif f is TrackVerglas:
				teinte = Color.WHITE
			elif f is TrackCourant:
				teinte = Color.YELLOW
			elif f is TrackAnneau:
				teinte = Color(1.0, 0.7, 0.0)
			elif f is TrackBoost:
				teinte = Color(0.2, 0.4, 1.0)
			if teinte.a == 0.0:
				continue
			var e := f.debut
			while e <= f.debut + f.longueur:
				_disque(image, vers_image.call(c.position_at(e)), maxi(rayon / 2, 1), teinte)
				e += 1.0
		piste.free()
	d = 0.0
	while d < c.length:
		var blanc := int(round(d)) % 100 == 0
		_disque(image, vers_image.call(c.position_at(d)), 3 if blanc else 2, Color.WHITE if blanc else Color.GRAY)
		d += 50.0
	_disque(image, vers_image.call(c.position_at(0.0)), 5, Color.GREEN)
	_disque(image, vers_image.call(c.position_at(15.0)), 3, Color.GREEN)
	image.save_png(args[1])
	print("%s : %.0f m, altitude %.0f à %.0f m, %.0f × %.0f m" % [args[1], c.length, bas, haut,
		maxi.x - mini.x, maxi.y - mini.y])
	quit()


func _disque(image: Image, centre: Vector2i, rayon: int, couleur: Color) -> void:
	for y in range(-rayon, rayon + 1):
		for x in range(-rayon, rayon + 1):
			if x * x + y * y > rayon * rayon:
				continue
			var p := centre + Vector2i(x, y)
			if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				image.set_pixelv(p, couleur)
