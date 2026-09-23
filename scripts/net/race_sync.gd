class_name RaceSync
extends Node

## Ce qui circule pendant une course en réseau. Ajouté par RaceLauncher à la
## scène de course, sous le même chemin sur toutes les machines — c'est ce
## que les appels RPC exigent.
##
## Le partage des rôles :
## - chaque joueur simule SON kart, et envoie où il est. Rien ne passe par
##   l'hôte avant de répondre au volant : le pilotage reste aussi vif qu'en
##   solo, quelle que soit la latence ;
## - l'hôte simule l'IA, arbitre les objets, le classement, les arrivées et
##   le départ, et renvoie à tous l'état de tous les karts ;
## - chaque machine affiche les karts qu'elle ne simule pas à partir de ces
##   états, avec un léger retard qui les lisse.
##
## Les karts s'identifient par leur place sur la grille (gid) : c'est le seul
## numéro qui vaut la même chose sur toutes les machines.

## Envois par seconde de l'état des karts, et du reste (classement, objets).
const FREQUENCE_KARTS := 30.0
const FREQUENCE_COURSE := 10.0
## Au-delà, le départ est donné même si une machine n'a pas fini de charger :
## un téléphone lent ne doit pas bloquer tout le monde.
const ATTENTE_CHARGEMENT_MAX := 10.0

var session: RaceSession
var objets: ItemManager

## gid -> RaceEntry, et gid -> peer id qui simule ce kart.
var entrees: Dictionary = {}
var proprietaires: Dictionary = {}
var tampons: Dictionary = {}

var _hote: bool = false
var _moi: int = 1
var _charges: Dictionary = {}
var _attente: float = 0.0
var _depart_donne: bool = false
var _horloge_karts: float = 0.0
var _horloge_course: float = 0.0


## Appelé par RaceLauncher avant l'entrée dans l'arbre.
func configurer(plan: Array, moi: int, hote: bool) -> void:
	_moi = moi
	_hote = hote
	for place in plan:
		var gid: int = place.gid
		var peer: int = place.peer
		# L'IA est simulée par l'hôte ; un humain par sa propre machine.
		proprietaires[gid] = peer if peer != 0 else 1
	for peer in proprietaires.values():
		_charges[peer] = false


func _ready() -> void:
	session = get_node("../Session") as RaceSession
	objets = get_node_or_null("../Objets") as ItemManager
	if session.entries.is_empty():
		await session.grille_prete
	for i in session.entries.size():
		var gid: int = session.cases_imposees[i]
		entrees[gid] = session.entries[i]
		tampons[gid] = SnapshotBuffer.new()
	multiplayer.peer_disconnected.connect(_sur_depart)
	if objets != null and _hote:
		objets.objet_recu.connect(_relayer_recu)
		objets.objet_utilise.connect(_relayer_utilise)
		objets.kart_touche.connect(_relayer_choc)
	if _hote:
		_sur_charge(1)
	else:
		_charge.rpc_id(1)


func _physics_process(delta: float) -> void:
	if entrees.is_empty() or not Reseau.actif():
		return
	if _hote and not _depart_donne:
		_attente += delta
		if _attente > ATTENTE_CHARGEMENT_MAX:
			_donner_le_depart()

	# La demande d'objet du joueur local part vers l'hôte, qui décide.
	if not _hote:
		var moi := _entree_locale()
		if moi != null and moi.kart.demande_objet:
			moi.kart.demande_objet = false
			_demande_objet.rpc_id(1, _gid_de(moi))

	_horloge_karts += delta
	if _horloge_karts >= 1.0 / FREQUENCE_KARTS:
		_horloge_karts = 0.0
		_envoyer_karts()

	if _hote:
		_horloge_course += delta
		if _horloge_course >= 1.0 / FREQUENCE_COURSE:
			_horloge_course = 0.0
			_classement.rpc(_photo_classement())
			if objets != null:
				_objets.rpc(objets.instantane())


func _process(_delta: float) -> void:
	var maintenant := _maintenant()
	for gid in entrees:
		if proprietaires[gid] == _moi:
			continue
		var tampon: SnapshotBuffer = tampons[gid]
		if tampon.est_vide():
			continue
		KartSnapshot.appliquer(tampon.echantillonner(maintenant), entrees[gid].kart)


func _maintenant() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


func _gid_de(entree: RaceEntry) -> int:
	for gid in entrees:
		if entrees[gid] == entree:
			return gid
	return -1


func _entree_locale() -> RaceEntry:
	return session.entries[0] if not session.entries.is_empty() else null


# --- Départ ----------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _charge() -> void:
	_sur_charge(multiplayer.get_remote_sender_id())


func _sur_charge(peer: int) -> void:
	if not _hote:
		return
	_charges[peer] = true
	if not _charges.values().has(false):
		_donner_le_depart()


func _donner_le_depart() -> void:
	if _depart_donne:
		return
	_depart_donne = true
	_depart.rpc()
	_depart()


@rpc("authority", "reliable")
func _depart() -> void:
	_depart_donne = true
	session.attente_depart = false


# --- État des karts ----------------------------------------------------------------

func _envoyer_karts() -> void:
	var paquet := PackedFloat32Array()
	for gid in entrees:
		var proprietaire: int = proprietaires[gid]
		if proprietaire == _moi:
			paquet.append_array(KartSnapshot.capturer(gid, entrees[gid].kart))
		elif _hote and not tampons[gid].est_vide():
			# L'hôte relaie aux autres ce que chaque client lui envoie.
			paquet.append_array(tampons[gid].dernier())
	if paquet.is_empty():
		return
	if _hote:
		_karts.rpc(paquet)
	else:
		_karts.rpc_id(1, paquet)


@rpc("any_peer", "unreliable_ordered")
func _karts(paquet: PackedFloat32Array) -> void:
	var expediteur := multiplayer.get_remote_sender_id()
	var maintenant := _maintenant()
	for etat in KartSnapshot.decouper(paquet):
		var gid := int(etat[KartSnapshot.GID])
		if not proprietaires.has(gid) or proprietaires[gid] == _moi:
			continue
		# Un client ne peut parler que pour son propre kart : il ne déplace
		# pas les autres, même par erreur.
		if _hote and proprietaires[gid] != expediteur:
			continue
		tampons[gid].ajouter(maintenant, etat)


# --- Classement, arrivées, objets tenus --------------------------------------------

func _photo_classement() -> Array:
	var photo := []
	for gid in entrees:
		var e: RaceEntry = entrees[gid]
		photo.append([gid, e.position, e.tours_comptes, e.finished, e.place_finale, e.temps_course,
			e.inventaire.objet, e.inventaire.charges, e.inventaire.roulette])
	return photo


@rpc("authority", "unreliable_ordered")
func _classement(photo: Array) -> void:
	for ligne in photo:
		var e: RaceEntry = entrees.get(int(ligne[0]))
		if e == null:
			continue
		e.position = int(ligne[1])
		if bool(ligne[3]) and not e.finished:
			session.appliquer_arrivee(e, int(ligne[4]), float(ligne[5]))
		e.inventaire.objet = int(ligne[6])
		e.inventaire.charges = int(ligne[7])
		e.inventaire.roulette = float(ligne[8])


@rpc("authority", "unreliable_ordered")
func _objets(etat: Dictionary) -> void:
	if objets != null:
		objets.appliquer_instantane(etat)


# --- Objets : demandes et effets ------------------------------------------------------

@rpc("any_peer", "reliable")
func _demande_objet(gid: int) -> void:
	if not _hote or proprietaires.get(gid, -1) != multiplayer.get_remote_sender_id():
		return
	entrees[gid].kart.demande_objet = true


func _relayer_recu(entree: RaceEntry, objet: int) -> void:
	_vers_proprietaire(entree, "recu", objet)


func _relayer_utilise(entree: RaceEntry, objet: int) -> void:
	_vers_proprietaire(entree, "utilise", objet)


func _relayer_choc(entree: RaceEntry) -> void:
	_vers_proprietaire(entree, "choc", ItemKind.NONE)


## L'hôte a décidé d'un effet sur un kart simulé ailleurs : c'est à la
## machine qui le simule de l'appliquer, sans quoi le champignon pousserait
## une copie qui ne roule pas.
func _vers_proprietaire(entree: RaceEntry, quoi: String, objet: int) -> void:
	var gid := _gid_de(entree)
	var peer: int = proprietaires.get(gid, 1)
	if peer != _moi:
		_effet.rpc_id(peer, gid, quoi, objet)


@rpc("authority", "reliable")
func _effet(gid: int, quoi: String, objet: int) -> void:
	var e: RaceEntry = entrees.get(gid)
	if e == null or objets == null:
		return
	match quoi:
		"recu":
			objets.objet_recu.emit(e, objet)
		"utilise":
			if objet == ItemKind.MUSHROOM:
				e.kart.motor.boost_objet()
			objets.objet_utilise.emit(e, objet)
		"choc":
			if e.kart.motor.stun():
				objets.kart_touche.emit(e)


# --- Départs en cours de course -----------------------------------------------------

## Un joueur s'en va : l'hôte reprend son kart et le confie à l'IA, plutôt que
## de laisser un kart figé au milieu de la piste.
func _sur_depart(peer: int) -> void:
	if not _hote:
		return
	_charges.erase(peer)
	for gid in proprietaires.keys():
		if proprietaires[gid] != peer:
			continue
		proprietaires[gid] = 1
		var e: RaceEntry = entrees[gid]
		var cerveau := e.kart.pilote() as AIInput
		if cerveau == null:
			cerveau = AIInput.new()
			e.kart.add_child(cerveau)
			e.kart.changer_pilote(cerveau)
		session.brancher_ia(cerveau)
		e.kart.simule = true
		e.kart.controle_actif = session.en_course
	# Si c'était le dernier que l'on attendait pour partir, on part.
	if not _depart_donne and not _charges.values().has(false):
		_donner_le_depart()
