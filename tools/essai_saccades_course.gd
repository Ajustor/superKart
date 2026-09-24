extends Node

## Une course rendue, le joueur confié à l'IA, où l'on mesure chaque image.
## Une image beaucoup plus longue que les autres est une saccade : on la note
## avec ce qui s'est passé juste avant (un objet lancé, une explosion, un
## choc, un saut…), pour savoir qui la provoque.
##
## Sans --headless : ce sont souvent le rendu et la compilation des shaders
## qui figent l'image, et un essai sans écran ne les voit pas. Avec
## --headless (et --fixed-fps 60), on ne voit que le coût processeur :
## physique, scripts, son.

## Une saccade : une image au moins SEUIL fois plus longue que la médiane,
## et d'au moins MINIMUM ms.
const SEUIL := 3.0
var MINIMUM := 40.0

var _session: RaceSession
var _duree := 60.0
var _images: PackedFloat32Array = []
var _derniere := 0
var _depuis := 0.0
var _evenements: Array = []
var _saccades: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.par_id(args[0] if not args.is_empty() else "circuit_01"))
	if args.size() > 1:
		_duree = float(args[1])
	# Sans écran (--headless), on ne mesure que le processeur : les pics sont
	# plus petits, le seuil aussi.
	if DisplayServer.get_name() == "headless":
		MINIMUM = 6.0
	var course := RaceLauncher.monter(reglage)
	_session = course.get_node("Session")
	_session.duree_decompte = 0.0
	_session.id_piste = ""
	get_tree().root.add_child.call_deferred(course)
	await get_tree().process_frame
	await get_tree().process_frame
	# Comme derrière l'écran de chargement ; « sans_chauffe » pour comparer.
	if not args.has("sans_chauffe"):
		var tour := TourDeChauffe.lancer(course)
		while tour != null and is_instance_valid(tour):
			await get_tree().process_frame
	var kart: Kart = _session.entries[0].kart
	var ia := AIInput.new()
	kart.add_child(ia)
	kart.changer_pilote(ia)
	_session.brancher_ia(ia)
	ia.track = _session.entries[0].progress.track
	var objets := course.get_node("Objets") as ItemManager
	objets.objet_utilise.connect(func(_e: RaceEntry, o: int) -> void: _noter("objet %s" % ItemKind.nom(o)))
	objets.objet_recu.connect(func(_e: RaceEntry, _o: int) -> void: _noter("boîte"))
	objets.kart_touche.connect(func(_e: RaceEntry) -> void: _noter("kart touché"))
	objets.kart_foudroye.connect(func(_e: RaceEntry) -> void: _noter("éclair"))
	objets.explosion.connect(func(_o: Vector3) -> void: _noter("explosion"))
	for e in _session.entries:
		e.kart.figure.connect(func() -> void: _noter("figure"))
		e.kart.motor.mini_turbo.connect(func(_p: int) -> void: _noter("mini-turbo"))
	_session.depart.connect(func() -> void: _noter("départ"))


func _noter(quoi: String) -> void:
	_evenements.append([_depuis, quoi])


func _process(delta: float) -> void:
	if _session == null:
		return
	var maintenant := Time.get_ticks_usec()
	if _derniere > 0:
		var ms := (maintenant - _derniere) / 1000.0
		_images.append(ms)
		if _images.size() > 30:
			var tries := _images.slice(-120)
			tries.sort()
			var mediane := tries[tries.size() / 2]
			if ms > maxf(mediane * SEUIL, MINIMUM):
				var avant := []
				for ev in _evenements:
					if _depuis - ev[0] < 0.3:
						avant.append(ev[1])
				_saccades.append("%6.2f s : %5.0f ms (médiane %.0f)  %s" % [_depuis, ms, mediane, ", ".join(avant)])
	_derniere = maintenant
	_depuis += delta
	if _depuis > _duree or _session.terminee:
		_bilan()
		get_tree().quit()


func _bilan() -> void:
	var tries := _images.duplicate()
	tries.sort()
	print("images : %d, médiane %.1f ms, 99e %.1f ms, pire %.0f ms" % [tries.size(),
		tries[tries.size() / 2], tries[int(tries.size() * 0.99)], tries[tries.size() - 1]])
	print("SACCADES %d" % _saccades.size())
	for s in _saccades:
		print("  " + s)
