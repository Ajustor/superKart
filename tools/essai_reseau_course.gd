extends Node

## Le corps de l'essai réseau (voir tools/essai_reseau.gd), chargé à la
## première image : à ce moment, les autoloads existent.

const PORT := 8920

var role := ""
var coupe := false
var _session: RaceSession
var _fin_de_manche_ms := 0
var _lance := false
var _fini_ms := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if not args.is_empty() else "hote"
	coupe = args.size() > 1 and args[1] == "coupe"
	GameSettings.chemin = "user://essai_reseau_%s.cfg" % role


func _journal(texte: String) -> void:
	print("[%s %5.1f s] %s" % [role, Time.get_ticks_msec() / 1000.0, texte])


func _process(_delta: float) -> void:
	if _fin():
		get_tree().quit()


## Un passage de la boucle ; vrai quand l'essai est fini.
func _fin() -> bool:
	var reseau = Reseau
	var current_scene := get_tree().current_scene
	if not has_meta("demarre"):
		set_meta("demarre", true)
		reseau.erreur.connect(func(m: String) -> void: _journal("erreur : " + m))
		reseau.podium.connect(func() -> void:
			_journal("podium : " + ", ".join(_points(reseau.grand_prix)))
			_fini_ms = Time.get_ticks_msec())
		if role == "hote":
			reseau.heberger("Hôte", PORT)
		else:
			reseau.rejoindre("127.0.0.1", "Client", PORT)

	if role == "hote" and not _lance and reseau.lobby.joueurs.size() == 2:
		_lance = true
		_journal("salon complet, lancement")
		if coupe:
			reseau.choisir_config("circuit_01", 1, Cylindree.Classe.CC100, 0)
			reseau.config.tours_coupe = 1
		else:
			reseau.choisir_config("circuit_01", 1)
		reseau.lancer_course()

	if current_scene != null and current_scene.has_node("Session") \
			and current_scene.get_node("Session") != _session:
		_brancher(current_scene)

	if coupe and _session != null and _session.terminee and _fin_de_manche_ms == 0:
		_fin_de_manche_ms = Time.get_ticks_msec()
		var ordre := PackedStringArray()
		for e in _session.classement():
			ordre.append(_session.nom_reel(e))
		_journal("fin de manche : " + ", ".join(ordre))
	if coupe and role == "hote" and _fin_de_manche_ms > 0 and _fini_ms == 0 \
			and Time.get_ticks_msec() > _fin_de_manche_ms + 2000:
		_fin_de_manche_ms = -1
		var ordre := PackedStringArray()
		for e in _session.classement():
			ordre.append(_session.nom_reel(e))
		reseau.manche_suivante(ordre)
	if coupe:
		if _fini_ms > 0 and Time.get_ticks_msec() > _fini_ms + 3000:
			reseau.quitter()
			return true
		return Time.get_ticks_msec() > 400000

	if _session != null and _session.terminee and _fini_ms == 0:
		_fini_ms = Time.get_ticks_msec()
		var lignes := _session.classement().map(func(e: RaceEntry) -> String:
			return "%d. %s %s" % [e.place_finale, e.nom, RaceTimer.format(e.temps_course)])
		_journal("classement : " + ", ".join(lignes))
	if _fini_ms > 0 and Time.get_ticks_msec() > _fini_ms + 3000:
		reseau.quitter()
		return true
	return Time.get_ticks_msec() > 180000


func _points(gp: GrandPrix) -> PackedStringArray:
	var lignes := PackedStringArray()
	for nom in gp.classement():
		lignes.append("%s %d" % [nom, gp.points[nom]])
	return lignes


func _brancher(course: Node) -> void:
	_session = course.get_node("Session")
	_fin_de_manche_ms = 0
	var reseau = Reseau
	if coupe and reseau.grand_prix != null:
		var grille := PackedStringArray()
		for i in _session.entries.size():
			grille.append("%s:%d" % [_session.noms_reels[i], _session.cases_imposees[i] + 1])
		_journal("manche %d (%s), %s, vitesse max %.1f — grille %s" % [reseau.grand_prix.manche + 1,
			reseau.config.piste, Cylindree.nom(reseau.grand_prix.classe),
			_session.entries[0].kart.stats.max_speed, " ".join(grille)])
		if reseau.grand_prix.manche > 0:
			_journal("points : " + ", ".join(_points(reseau.grand_prix)))
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
