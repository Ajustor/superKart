extends Node

## Fait courir huit IA sur un circuit, sans écran et en accéléré, et dit si
## le tracé se laisse rouler : temps de chacun, remises en piste, images
## passées presque à l'arrêt.
##
##   godot --headless --fixed-fps 60 --path . -s tools/essai_circuit.gd -- <id> [tours]
##
## (essai_circuit.gd ne fait que charger ce nœud à la première image : un
## script lancé par -s est compilé avant que les autoloads n'existent, et
## les scripts de la course en dépendent.)
##
## Un circuit sain : tout le monde arrive, les remises en piste restent
## rares, et les karts arrêtés le sont par un objet, pas par le décor.
##
## Pour trouver où ça coince, remises en piste et arrêts sont comptés par
## tranche de dix mètres le long du tracé.

const LIMITE := 600.0

var _session: RaceSession
var _precedent: Array[Vector3] = []
var _remises: Array[int] = []
var _arrets: Array[int] = []
var _ou: Dictionary = {}
var _arrets_ou: Dictionary = {}
var _temps := 0.0
## Durée réelle de chaque image, en ms. Lancé avec --fixed-fps, le moteur
## enchaîne les images sans attendre : c'est tout ce que coûte une image, la
## physique comme le reste. Les moniteurs de Performance, eux, ne se
## rafraîchissent qu'une fois par seconde.
var _images: PackedFloat32Array = []
var _derniere := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if not args.is_empty() else "circuit_01"
	var piste := TrackCatalog.par_id(id)
	if piste == null:
		printerr("circuit inconnu : %s" % id)
		get_tree().quit(1)
		return
	var reglage := RaceSetup.new()
	reglage.choisir_piste(piste)
	if args.size() > 1:
		reglage.tours = int(args[1])
	# Troisième argument facultatif : la cylindrée (50, 100 ou 150).
	if args.size() > 2:
		reglage.classe = Cylindree.NOMS.find("%scc" % args[2])
	var course := RaceLauncher.monter(reglage)
	get_tree().root.add_child.call_deferred(course)
	_session = course.get_node("Session")
	# Des temps d'IA n'ont rien à faire dans les records du joueur.
	_session.id_piste = ""
	print("%s — %s, %d tours, %s" % [piste.id, piste.nom, reglage.tours, Cylindree.nom(reglage.classe)])


func _physics_process(delta: float) -> void:
	if _session == null or _session.entries.is_empty():
		return
	if _precedent.is_empty():
		_brancher()
	_temps += delta
	var maintenant := Time.get_ticks_usec()
	if _session.en_course and _derniere > 0:
		_images.append((maintenant - _derniere) / 1000.0)
	_derniere = maintenant
	for i in _session.entries.size():
		var e := _session.entries[i]
		var p := e.kart.global_position
		if _session.en_course and not e.finished:
			if p.distance_to(_precedent[i]) > 6.0:
				_remises[i] += 1
				var ou := int(e.derniere_en_piste / 10.0) * 10
				_ou[ou] = int(_ou.get(ou, 0)) + 1
			if e.kart.motor.speed < 2.0 and e.kart.motor.state != KartMotor.State.STUNNED:
				_arrets[i] += 1
				var ici := int(e.progress.distance / 10.0) * 10
				_arrets_ou[ici] = int(_arrets_ou.get(ici, 0)) + 1
		_precedent[i] = p
	if _session.terminee or _temps > LIMITE:
		_bilan()
		get_tree().quit()


## Le kart du joueur est confié à l'IA, comme les autres.
func _brancher() -> void:
	for e in _session.entries:
		_precedent.append(e.kart.global_position)
		_remises.append(0)
		_arrets.append(0)
	var kart: Kart = _session.entries[0].kart
	var ia := AIInput.new()
	kart.add_child(ia)
	kart.changer_pilote(ia)
	_session.brancher_ia(ia)
	ia.track = _session.entries[0].progress.track


func _bilan() -> void:
	var longueur := _session.circuit().track_curve.length
	print("longueur %.0f m" % longueur)
	var arrives := 0
	for i in _session.entries.size():
		var e := _session.entries[i]
		if e.finished:
			arrives += 1
		print("  %-10s %s  remises %2d  arrêts %4d" % [e.kart.name,
			("%6.1f s" % e.temps_course) if e.finished else "  ---   ", _remises[i], _arrets[i]])
	var cles := _ou.keys()
	cles.sort()
	var lieux := PackedStringArray()
	for k in cles:
		lieux.append("%d m ×%d" % [k, _ou[k]])
	print("remises par endroit : %s" % (", ".join(lieux) if not lieux.is_empty() else "aucune"))
	var pires := _arrets_ou.keys()
	pires.sort_custom(func(a: int, b: int) -> bool: return _arrets_ou[a] > _arrets_ou[b])
	var arrets := PackedStringArray()
	for k in pires.slice(0, 6):
		arrets.append("%d m ×%d" % [k, _arrets_ou[k]])
	print("arrêts par endroit : %s" % (", ".join(arrets) if not arrets.is_empty() else "aucun"))
	print("durée d'une image (ms) : %s" % _resume(_images))
	print("ARRIVÉS %d/%d" % [arrives, _session.entries.size()])


## Moyenne, 95e centile et pire valeur.
func _resume(valeurs: PackedFloat32Array) -> String:
	if valeurs.is_empty():
		return "—"
	var tries := valeurs.duplicate()
	tries.sort()
	var somme := 0.0
	for v in tries:
		somme += v
	return "moy %.2f, 95e %.2f, pire %.1f" % [somme / tries.size(), tries[int(tries.size() * 0.95)], tries[tries.size() - 1]]
