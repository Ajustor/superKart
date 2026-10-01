extends Node

## Fait courir un tour au kart du joueur (confié à l'IA) et relève, deux fois
## par seconde, les appels de dessin et les triangles de l'image : ce que la
## scène demande à la carte graphique, indépendamment de sa puissance. Les
## comparer d'un circuit à l'autre dit lequel chargera le plus un téléphone.

const LIMITE := 40.0

var _session: RaceSession
var _temps := 0.0
var _prochain := 3.0
var _dessins: PackedInt32Array = []
var _triangles: PackedInt32Array = []
var _id := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_id = args[0] if not args.is_empty() else "circuit_01"
	var niveaux := {"haute": QualiteGraphique.Niveau.HAUTE, "moyenne": QualiteGraphique.Niveau.MOYENNE,
		"basse": QualiteGraphique.Niveau.BASSE}
	GameSettings.qualite = niveaux.get(args[1] if args.size() > 1 else "haute", QualiteGraphique.Niveau.HAUTE)
	GameSettings.tactile = GameSettings.Tactile.JAMAIS
	var reglage := RaceSetup.new()
	reglage.choisir_piste(TrackCatalog.par_id(_id))
	reglage.case_de_depart = 4
	var course := RaceLauncher.monter(reglage)
	get_tree().root.add_child.call_deferred(course)
	_session = course.get_node("Session")
	_session.id_piste = ""


func _physics_process(delta: float) -> void:
	if _session == null or _session.entries.is_empty():
		return
	_temps += delta
	var joueur := _session.entries[0]
	if not joueur.kart.pilote() is AIInput:
		var ia := AIInput.new()
		joueur.kart.add_child(ia)
		joueur.kart.changer_pilote(ia)
		_session.brancher_ia(ia)
		ia.track = joueur.progress.track
	if _temps >= _prochain:
		_prochain += 0.5
		_dessins.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_triangles.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	if joueur.tours_comptes >= 1 or _temps > LIMITE:
		_bilan()
		get_tree().quit()


func _bilan() -> void:
	print("%-18s dessins moy %4d  pire %4d   triangles moy %7d  pire %7d" % [_id,
		_moyenne(_dessins), _pire(_dessins), _moyenne(_triangles), _pire(_triangles)])


static func _moyenne(v: PackedInt32Array) -> int:
	var s := 0
	for x in v:
		s += x
	return s / maxi(v.size(), 1)


static func _pire(v: PackedInt32Array) -> int:
	var m := 0
	for x in v:
		m = maxi(m, x)
	return m
