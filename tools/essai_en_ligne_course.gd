extends Node

## Le corps de l'essai en ligne (voir tools/essai_en_ligne.gd).

var role := ""
var port := 8930
var coupe := false
var _session: RaceSession
var _lance := false
var _fini_ms := 0
var _manches := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if not args.is_empty() else "chef"
	port = int(args[1]) if args.size() > 1 else 8930
	coupe = args.has("coupe")
	GameSettings.chemin = "user://essai_en_ligne_%s.cfg" % role
	Reseau.erreur.connect(func(m: String) -> void: _journal("erreur : " + m))
	Reseau.deconnecte.connect(func(m: String) -> void: _journal("déconnecté : " + m))
	Reseau.podium.connect(func() -> void:
		_journal("podium : " + ", ".join(_points(Reseau.grand_prix)))
		_fini_ms = Time.get_ticks_msec())
	# Le chef arrive le premier : l'invité attend un peu.
	if role != "chef":
		await get_tree().create_timer(1.5).timeout
	Reseau.rejoindre("127.0.0.1", role.capitalize(), port)


func _journal(texte: String) -> void:
	print("[%s %5.1f s] %s" % [role, Time.get_ticks_msec() / 1000.0, texte])


func _process(_delta: float) -> void:
	if role == "chef" and not _lance and Reseau.lobby.joueurs.size() == 2:
		_lance = true
		_journal("salon : %s, chef %s, en ligne %s" % [", ".join(Reseau.lobby.noms()),
			Reseau.lobby.joueurs.get(Reseau.lobby.chef(), "?"), Reseau.en_ligne()])
		if coupe:
			Reseau.choisir_config("circuit_01", 1, Cylindree.Classe.CC100, 0)
		else:
			Reseau.choisir_config("grand_huit", 1)
		# Laisser le réglage arriver au serveur avant de lancer.
		get_tree().create_timer(0.5).timeout.connect(Reseau.lancer_course)
	var scene := get_tree().current_scene
	if scene != null and scene.has_node("Session") and scene.get_node("Session") != _session:
		_brancher(scene)
	if not coupe and _session != null and _session.terminee and _fini_ms == 0:
		_fini_ms = Time.get_ticks_msec()
		_journal("classement : " + ", ".join(_session.classement().map(func(e: RaceEntry) -> String:
			return "%d. %s %s" % [e.place_finale, _session.nom_reel(e), RaceTimer.format(e.temps_course)])))
	if _fini_ms > 0 and Time.get_ticks_msec() > _fini_ms + 2000:
		Reseau.quitter()
		get_tree().quit()
	if Time.get_ticks_msec() > 600000:
		_journal("trop long, abandon")
		get_tree().quit(1)


func _brancher(course: Node) -> void:
	_session = course.get_node("Session")
	_manches += 1
	_journal("course %d : %s, grille %s" % [_manches, Reseau.config.piste,
		" ".join(Array(_session.noms_reels).map(func(n: String) -> String: return n))])
	var kart: Kart = _session.entries[0].kart
	var ia := AIInput.new()
	kart.add_child(ia)
	kart.changer_pilote(ia)
	_session.brancher_ia(ia)
	ia.track = _session.entries[0].progress.track
	_session.depart.connect(func() -> void: _journal("départ"))


func _points(gp: GrandPrix) -> PackedStringArray:
	var lignes := PackedStringArray()
	for nom in gp.classement():
		lignes.append("%s %d" % [nom, gp.points[nom]])
	return lignes
