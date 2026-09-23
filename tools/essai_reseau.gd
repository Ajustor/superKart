extends SceneTree

## Essai du multijoueur à deux instances, sans écran ni joueur :
##
##   godot --headless --path . -s tools/essai_reseau.gd -- hote   &
##   godot --headless --path . -s tools/essai_reseau.gd -- client
##
## L'hôte ouvre une partie, le client la rejoint sur 127.0.0.1, l'hôte lance
## une course d'un tour ; chaque kart humain est confié à l'IA pour aller au
## bout. Chacun écrit le départ, les objets de son joueur, les arrivées et le
## classement final : les deux journaux doivent donner le même classement et
## les mêmes temps.
##
## En temps réel, sans --fixed-fps : l'hôte finirait sa course avant que le
## client ait fini de charger la sienne.

const PORT := 8920

var role := ""
var _session: RaceSession
var _lance := false
var _fini_ms := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if not args.is_empty() else "hote"
	root.get_node("GameSettings").chemin = "user://essai_reseau_%s.cfg" % role


func _journal(texte: String) -> void:
	print("[%s %5.1f s] %s" % [role, Time.get_ticks_msec() / 1000.0, texte])


func _process(_delta: float) -> bool:
	var reseau = root.get_node("Reseau")
	if not has_meta("demarre"):
		set_meta("demarre", true)
		reseau.erreur.connect(func(m: String) -> void: _journal("erreur : " + m))
		if role == "hote":
			reseau.heberger("Hôte", PORT)
		else:
			reseau.rejoindre("127.0.0.1", "Client", PORT)

	if role == "hote" and not _lance and reseau.lobby.joueurs.size() == 2:
		_lance = true
		_journal("salon complet, lancement")
		reseau.choisir_config("circuit_01", 1)
		reseau.lancer_course()

	if _session == null and current_scene != null and current_scene.has_node("Session"):
		_brancher(current_scene)

	if _session != null and _session.terminee and _fini_ms == 0:
		_fini_ms = Time.get_ticks_msec()
		var lignes := _session.classement().map(func(e: RaceEntry) -> String:
			return "%d. %s %s" % [e.place_finale, e.nom, RaceTimer.format(e.temps_course)])
		_journal("classement : " + ", ".join(lignes))
	if _fini_ms > 0 and Time.get_ticks_msec() > _fini_ms + 3000:
		reseau.quitter()
		return true
	return Time.get_ticks_msec() > 180000


func _brancher(course: Node) -> void:
	_session = course.get_node("Session")
	var kart: Kart = _session.entries[0].kart
	var ia := AIInput.new()
	kart.add_child(ia)
	kart.changer_pilote(ia)
	_session.brancher_ia(ia)
	ia.track = _session.entries[0].progress.track
	_session.depart.connect(func() -> void: _journal("départ"))
	_session.arrivee.connect(func(e: RaceEntry) -> void:
		_journal("arrivée de %s, %de" % [e.nom, e.place_finale]))
	var objets: ItemManager = course.get_node("Objets")
	var moi := _session.entries[0]
	objets.objet_recu.connect(func(e: RaceEntry, o: int) -> void:
		if e == moi: _journal("je reçois : " + ItemKind.nom(o)))
	objets.kart_touche.connect(func(e: RaceEntry) -> void:
		if e == moi: _journal("je suis touché"))
