class_name ItemManager
extends Node3D

## Tout ce qui touche aux objets une fois sur la piste : les boîtes, les
## bananes au sol, les carapaces en vol, et ce qu'il se passe quand un kart
## croise l'un d'eux.
##
## Les collisions se font à la distance et non par des Area3D : huit karts et
## une poignée d'objets, c'est quelques dizaines de soustractions par image,
## et c'est surtout ce qui permet de tout tester sans moteur physique — comme
## RaceSession, on passe les positions en paramètre au lieu de les lire.

signal objet_recu(entree: RaceEntry, objet: int)
signal objet_utilise(entree: RaceEntry, objet: int)
signal kart_touche(entree: RaceEntry)

## Rayon de ramassage d'une boîte. Généreux : une boîte frôlée qui ne donne
## rien est vécue comme une injustice.
const RAYON_BOITE := 1.7
## Rayon de collision entre un kart et un objet au sol ou en vol.
const RAYON_IMPACT := 1.3
## Délai avant qu'une boîte ramassée revienne, en secondes.
const REAPPARITION := 2.5
const BOITES_PAR_RANGEE := 4
const HAUTEUR_BOITE := 0.9

## Plus rapide que le kart le plus rapide (22 m/s × 1,48 en turbo palier 3) :
## une carapace qu'on rattrape n'est pas une arme.
const VITESSE_CARAPACE := 36.0
const DUREE_VERTE := 6.0
const DUREE_ROUGE := 8.0
const HAUTEUR_CARAPACE := 0.45
## Marge gardée entre une carapace et le mur sur lequel elle rebondit (ou le
## bord du bitume, pour la rouge qui suit la route).
const MARGE_BORD := 0.6
## Au-delà de cette distance du bord, une carapace verte sortie de la route
## est perdue : elle file dans le décor et disparaît.
const SORTIE_HORS_PISTE := 8.0
## En deçà de cette avance sur la piste, la carapace rouge quitte la route pour
## foncer droit sur sa cible.
const APPROCHE_ROUGE := 14.0

## Pendant ce délai, un objet ignore celui qui vient de le lancer : sans lui,
## la carapace partirait déjà au contact de son propre kart.
const GRACE_LANCEUR := 0.4
const RECUL_BANANE := 2.4
const AVANCE_CARAPACE := 2.2
## Au-delà, la plus ancienne banane disparaît : une piste jonchée de dizaines
## de bananes ne se joue plus.
const MAX_BANANES := 16

@export var session_path: NodePath
@export var table: ItemTable

## Faux sur un client en réseau : l'hôte décide des ramassages, des lancers
## et des chocs ; ici on ne fait qu'afficher ce qu'il envoie.
var autorite: bool = true

## Contre-la-montre : pas de boîtes sur la route, trois champignons au départ.
var contre_la_montre: bool = false

var boites: Array[Boite] = []
var bananes: Array[Banane] = []
var carapaces: Array[Carapace] = []
var rng := RandomNumberGenerator.new()

var _session: RaceSession
var _piste: TrackCurve
var _circuit: Track
var _materiaux: Dictionary = {}


class Boite:
	var position: Vector3
	var attente: float = 0.0
	var noeud: Node3D

	func disponible() -> bool:
		return attente <= 0.0


class Banane:
	var position: Vector3
	var lanceur: RaceEntry
	var age: float = 0.0
	var noeud: Node3D


class Carapace:
	var rouge: bool = false
	var position: Vector3
	var direction: Vector3
	var lanceur: RaceEntry
	var cible: RaceEntry
	var age: float = 0.0
	var noeud: Node3D


func _ready() -> void:
	var session := get_node_or_null(session_path) as RaceSession
	assert(session != null, "session_path doit pointer vers une RaceSession")
	rng.randomize()
	if session.entries.is_empty():
		await session.grille_prete
	var circuit := session.get_node(session.track_path) as Track
	preparer(session, circuit.rangees_objets)


## Branche le gestionnaire sur la course et pose les boîtes. Appelé par _ready ;
## les tests l'appellent directement, hors de l'arbre.
func preparer(session: RaceSession, rangees: PackedFloat32Array) -> void:
	_session = session
	_piste = session.entries[0].progress.track
	_circuit = session.circuit()
	if table == null:
		table = ItemTable.new()
	if contre_la_montre:
		for entree in session.entries:
			entree.inventaire.recevoir(ItemKind.TRIPLE_MUSHROOM, 0.0)
		return
	for f in rangees:
		poser_rangee(f * _piste.length)


## Une rangée de boîtes en travers de la route, à cette distance du départ.
func poser_rangee(distance: float) -> void:
	var etendue := _piste.half_width * 0.65
	for i in BOITES_PAR_RANGEE:
		var t := float(i) / float(maxi(BOITES_PAR_RANGEE - 1, 1))
		var boite := Boite.new()
		boite.position = _au_sol(distance, lerpf(-etendue, etendue, t), HAUTEUR_BOITE)
		boite.noeud = _visuel_boite()
		boite.noeud.position = boite.position
		add_child(boite.noeud)
		boites.append(boite)


func _physics_process(delta: float) -> void:
	if _session == null:
		return
	if not autorite:
		_prolonger_carapaces(delta)
		return
	var positions: Array[Vector3] = []
	for entree in _session.entries:
		positions.append(entree.kart.global_position)
	avancer(positions, delta)


func _process(delta: float) -> void:
	# Les boîtes tournent sur elles-mêmes : un cube immobile passe pour du décor.
	for boite in boites:
		if boite.noeud != null:
			boite.noeud.rotate_y(1.6 * delta)


## Une image de jeu. `positions` suit l'ordre de session.entries.
func avancer(positions: Array[Vector3], delta: float) -> void:
	var entrees := _session.entries
	for boite in boites:
		boite.attente = maxf(boite.attente - delta, 0.0)
		if boite.noeud != null:
			boite.noeud.visible = boite.disponible()

	for i in entrees.size():
		var entree := entrees[i]
		entree.inventaire.avancer(delta)
		_ramasser(entree, positions[i])
		if entree.kart.demande_objet:
			entree.kart.demande_objet = false
			var lance := entree.inventaire.utiliser()
			if lance != ItemKind.NONE:
				_lancer(entree, positions[i], lance)
				objet_utilise.emit(entree, lance)

	_avancer_carapaces(positions, delta)
	_avancer_bananes(positions, delta)
	_nourrir_ia(positions)


func _ramasser(entree: RaceEntry, point: Vector3) -> void:
	for boite in boites:
		if not boite.disponible() or point.distance_to(boite.position) > RAYON_BOITE:
			continue
		# La boîte disparaît même si l'emplacement est plein : c'est ce que
		# voient les autres, et ce qui empêche un kart de camper dessus.
		boite.attente = REAPPARITION
		if entree.inventaire.est_vide():
			var tire := table.tirer(maxi(entree.position, 1), _session.entries.size(), rng)
			if entree.inventaire.recevoir(tire):
				objet_recu.emit(entree, tire)
		return


func _lancer(entree: RaceEntry, point: Vector3, objet: int) -> void:
	var moteur := entree.kart.motor
	var avant := Vector3(sin(moteur.velocity_dir), 0.0, -cos(moteur.velocity_dir))
	match objet:
		ItemKind.MUSHROOM:
			moteur.boost_objet()
		ItemKind.BANANA:
			poser_banane(point - avant * RECUL_BANANE, entree)
		ItemKind.GREEN_SHELL:
			lancer_carapace(point + avant * AVANCE_CARAPACE, avant, entree, null)
		ItemKind.RED_SHELL:
			lancer_carapace(point + avant * AVANCE_CARAPACE, avant, entree, cible_devant(entree))


## Le concurrent classé juste devant, ou null pour celui qui mène : la
## carapace rouge d'un premier part tout droit, comme une verte.
func cible_devant(entree: RaceEntry) -> RaceEntry:
	for autre in _session.entries:
		if autre.position == entree.position - 1:
			return autre
	return null


func poser_banane(ou: Vector3, lanceur: RaceEntry) -> Banane:
	var d := _piste.distance_of(ou)
	var banane := Banane.new()
	banane.position = _au_sol(d, _piste.lateral_offset(ou), 0.25)
	banane.lanceur = lanceur
	banane.noeud = _visuel_banane()
	banane.noeud.position = banane.position
	add_child(banane.noeud)
	bananes.append(banane)
	while bananes.size() > MAX_BANANES:
		_retirer_banane(0)
	return banane


func lancer_carapace(ou: Vector3, direction: Vector3, lanceur: RaceEntry, cible: RaceEntry) -> Carapace:
	var carapace := Carapace.new()
	carapace.rouge = cible != null
	carapace.cible = cible
	carapace.lanceur = lanceur
	carapace.direction = Vector3(direction.x, 0.0, direction.z).normalized()
	var d := _piste.distance_of(ou)
	carapace.position = _au_sol(d, _piste.lateral_offset(ou), HAUTEUR_CARAPACE)
	carapace.noeud = _visuel_carapace(carapace.rouge)
	carapace.noeud.position = carapace.position
	add_child(carapace.noeud)
	carapaces.append(carapace)
	return carapace


func _avancer_carapaces(positions: Array[Vector3], delta: float) -> void:
	var i := 0
	while i < carapaces.size():
		var c := carapaces[i]
		c.age += delta
		if c.age > (DUREE_ROUGE if c.rouge else DUREE_VERTE):
			_retirer_carapace(i)
			continue
		if not _deplacer(c, positions, delta) or _carapace_touche(c, positions):
			_retirer_carapace(i)
			continue
		i += 1


## Rend faux quand la carapace est perdue hors de la route.
func _deplacer(c: Carapace, positions: Array[Vector3], delta: float) -> bool:
	var d := _piste.distance_of(c.position)
	if c.cible != null:
		var ou_est_la_cible := positions[_session.entries.find(c.cible)]
		var avance := wrapf(c.cible.progress.distance - d, -_piste.length * 0.5, _piste.length * 0.5)
		var vise: Vector3
		if absf(avance) > APPROCHE_ROUGE:
			# Loin de sa cible, elle suit la route comme un kart : c'est le
			# circuit qui la guide, pas la ligne droite à travers le décor.
			vise = _piste.position_at(d + 8.0)
		else:
			vise = ou_est_la_cible
		var vers := vise - c.position
		vers.y = 0.0
		if vers.length_squared() > 0.0001:
			c.direction = vers.normalized()

	var ancien := _piste.lateral_offset_at(c.position, d)
	var suivante := c.position + c.direction * VITESSE_CARAPACE * delta
	var nd := _piste.distance_of(suivante)
	var ecart := _piste.lateral_offset_at(suivante, nd)
	var limite := _piste.half_width - MARGE_BORD
	if c.rouge and absf(ecart) > limite:
		# La rouge suit la route : le bord la renvoie, comme une bille sur une
		# bande. La verte, elle, ne rebondit que sur de vrais murs — sans mur,
		# elle quitte la route.
		var normale := _piste.right_at(nd) * signf(ecart)
		normale.y = 0.0
		normale = normale.normalized()
		if c.direction.dot(normale) > 0.0:
			c.direction = (c.direction - 2.0 * c.direction.dot(normale) * normale).normalized()
		ecart = clampf(ecart, -limite, limite)
	ecart = _rebondir_sur_les_murs(c, nd, ancien, ecart)
	if absf(ecart) > _piste.half_width + SORTIE_HORS_PISTE:
		return false
	c.position = _au_sol(nd, ecart, HAUTEUR_CARAPACE)
	if c.noeud != null:
		c.noeud.position = c.position
	return true


## Une carapace qui franchirait un mur du circuit entre deux images rebondit
## dessus. Rend l'écart corrigé.
func _rebondir_sur_les_murs(c: Carapace, distance: float, avant: float, apres: float) -> float:
	if _circuit == null:
		return apres
	for mur in _circuit.murs_en(distance):
		var cote := signf(avant - mur)
		if cote == 0.0 or signf(apres - mur) == cote:
			continue
		# La normale du mur, tournée vers le côté d'où vient la carapace.
		var normale := _piste.right_at(distance) * cote
		normale.y = 0.0
		normale = normale.normalized()
		if c.direction.dot(normale) < 0.0:
			c.direction = (c.direction - 2.0 * c.direction.dot(normale) * normale).normalized()
		return mur + cote * MARGE_BORD
	return apres


func _carapace_touche(c: Carapace, positions: Array[Vector3]) -> bool:
	for j in _session.entries.size():
		var entree := _session.entries[j]
		if entree == c.lanceur and c.age < GRACE_LANCEUR:
			continue
		if positions[j].distance_to(c.position) <= RAYON_IMPACT:
			_toucher(entree)
			return true
	# Une carapace qui rencontre une banane : les deux disparaissent. C'est ce
	# qui donne sa valeur défensive à la banane gardée derrière soi.
	for k in bananes.size():
		if bananes[k].position.distance_to(c.position) <= RAYON_IMPACT:
			_retirer_banane(k)
			return true
	return false


func _avancer_bananes(positions: Array[Vector3], delta: float) -> void:
	var i := 0
	while i < bananes.size():
		var b := bananes[i]
		b.age += delta
		var touchee := false
		for j in _session.entries.size():
			var entree := _session.entries[j]
			if entree == b.lanceur and b.age < GRACE_LANCEUR:
				continue
			if positions[j].distance_to(b.position) <= RAYON_IMPACT:
				_toucher(entree)
				touchee = true
				break
		if touchee:
			_retirer_banane(i)
		else:
			i += 1


func _toucher(entree: RaceEntry) -> void:
	if entree.kart.motor.stun():
		kart_touche.emit(entree)


## Dit à chaque IA ce qu'elle tient et où elle en est au classement : elle
## décide seule, mais ne peut pas le deviner.
func _nourrir_ia(positions: Array[Vector3]) -> void:
	for i in _session.entries.size():
		var entree := _session.entries[i]
		var cerveau := entree.kart.pilote() as AIInput
		if cerveau == null:
			continue
		cerveau.objet_pret = entree.inventaire.objet if entree.inventaire.pret() else ItemKind.NONE
		cerveau.en_tete = entree.position == 1
		cerveau.ecart_poursuivant = INF
		for autre in _session.entries:
			if autre.position == entree.position + 1:
				cerveau.ecart_poursuivant = entree.progress.total - autre.progress.total


# --- Réseau ------------------------------------------------------------------
# L'hôte photographie ce qui est sur la piste ; les clients s'y conforment.
# Les boîtes ne bougent pas : un masque de bits suffit à dire lesquelles sont
# là. Bananes et carapaces sont peu nombreuses, on envoie leurs positions.

func instantane() -> Dictionary:
	var masque := 0
	for i in boites.size():
		if boites[i].disponible():
			masque |= 1 << i
	var b := PackedVector3Array()
	for banane in bananes:
		b.append(banane.position)
	var c := PackedVector3Array()
	var directions := PackedVector3Array()
	var rouges := PackedByteArray()
	for carapace in carapaces:
		c.append(carapace.position)
		directions.append(carapace.direction)
		rouges.append(1 if carapace.rouge else 0)
	return {boites = masque, bananes = b, carapaces = c, directions = directions, rouges = rouges}


## `avance` : l'âge de la photo, en secondes. Les carapaces ont roulé
## pendant ce temps-là ; on les montre où elles sont maintenant.
func appliquer_instantane(etat: Dictionary, avance: float = 0.0) -> void:
	var masque: int = etat.get("boites", 0)
	for i in boites.size():
		boites[i].attente = 0.0 if masque & (1 << i) else REAPPARITION
		if boites[i].noeud != null:
			boites[i].noeud.visible = boites[i].disponible()

	var b: PackedVector3Array = etat.get("bananes", PackedVector3Array())
	while bananes.size() > b.size():
		_retirer_banane(bananes.size() - 1)
	for i in b.size():
		if i >= bananes.size():
			var nouvelle := Banane.new()
			nouvelle.noeud = _visuel_banane()
			add_child(nouvelle.noeud)
			bananes.append(nouvelle)
		bananes[i].position = b[i]
		bananes[i].noeud.position = b[i]

	var c: PackedVector3Array = etat.get("carapaces", PackedVector3Array())
	var rouges: PackedByteArray = etat.get("rouges", PackedByteArray())
	var directions: PackedVector3Array = etat.get("directions", PackedVector3Array())
	# Une carapace qui change de couleur à la même place de la liste est une
	# autre carapace : on refait son visuel.
	for i in range(carapaces.size() - 1, -1, -1):
		if i >= c.size() or carapaces[i].rouge != (rouges[i] == 1):
			_retirer_carapace(i)
	for i in c.size():
		if i >= carapaces.size():
			var nouvelle := Carapace.new()
			nouvelle.rouge = rouges[i] == 1
			nouvelle.noeud = _visuel_carapace(nouvelle.rouge)
			add_child(nouvelle.noeud)
			carapaces.append(nouvelle)
		carapaces[i].direction = directions[i] if i < directions.size() else Vector3.ZERO
		carapaces[i].position = c[i] + carapaces[i].direction * VITESSE_CARAPACE * avance
		carapaces[i].noeud.position = carapaces[i].position


## Chez un client, entre deux photos de l'hôte, les carapaces continuent tout
## droit : à 36 m/s, une carapace figée un trentième de seconde ferait des
## bonds d'un mètre. La photo suivante corrige virages et rebonds.
func _prolonger_carapaces(delta: float) -> void:
	for c in carapaces:
		c.position += c.direction * VITESSE_CARAPACE * delta
		if c.noeud != null:
			c.noeud.position = c.position


## Un point de la chaussée, à `hauteur` au-dessus du bitume, dévers compris.
func _au_sol(distance: float, lateral: float, hauteur: float) -> Vector3:
	return _piste.position_at(distance) \
		+ _piste.right_at(distance) * lateral \
		+ _piste.up_at(distance) * hauteur


func _retirer_banane(index: int) -> void:
	var b := bananes[index]
	if b.noeud != null:
		b.noeud.queue_free()
	bananes.remove_at(index)


func _retirer_carapace(index: int) -> void:
	var c := carapaces[index]
	if c.noeud != null:
		c.noeud.queue_free()
	carapaces.remove_at(index)


# --- Apparence ---------------------------------------------------------------
# Des primitives et des couleurs franches : c'est la silhouette et la couleur
# qui doivent dire de quel objet il s'agit, à trente mètres et en plein virage.

func _materiau(couleur: Color, emission: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var cle := "%s/%s/%s" % [couleur.to_html(), emission, transparent]
	if _materiaux.has(cle):
		return _materiaux[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 0.4
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = couleur
		m.emission_energy_multiplier = emission
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materiaux[cle] = m
	return m


func _visuel_boite() -> Node3D:
	var racine := Node3D.new()
	var cube := MeshInstance3D.new()
	var forme := BoxMesh.new()
	forme.size = Vector3(1.1, 1.1, 1.1)
	cube.mesh = forme
	cube.material_override = _materiau(Color(0.35, 0.75, 1.0, 0.75), 0.6, true)
	# Posé sur un coin : c'est la silhouette que tout le monde reconnaît.
	cube.rotation = Vector3(deg_to_rad(35.0), 0.0, deg_to_rad(45.0))
	racine.add_child(cube)
	var signe := Label3D.new()
	signe.text = "?"
	signe.font_size = 96
	signe.pixel_size = 0.008
	signe.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	signe.modulate = Color(1, 1, 1)
	signe.outline_size = 16
	signe.no_depth_test = false
	racine.add_child(signe)
	return racine


func _visuel_banane() -> Node3D:
	var racine := Node3D.new()
	var corps := MeshInstance3D.new()
	var forme := CapsuleMesh.new()
	forme.radius = 0.16
	forme.height = 0.8
	corps.mesh = forme
	corps.material_override = _materiau(Color(1.0, 0.86, 0.15))
	corps.rotation = Vector3(0.0, 0.0, deg_to_rad(70.0))
	racine.add_child(corps)
	var queue := MeshInstance3D.new()
	var tige := CylinderMesh.new()
	tige.top_radius = 0.04
	tige.bottom_radius = 0.05
	tige.height = 0.18
	queue.mesh = tige
	queue.material_override = _materiau(Color(0.35, 0.25, 0.1))
	queue.position = Vector3(0.36, 0.2, 0.0)
	racine.add_child(queue)
	return racine


func _visuel_carapace(rouge: bool) -> Node3D:
	var racine := Node3D.new()
	var dome := MeshInstance3D.new()
	var forme := SphereMesh.new()
	forme.radius = 0.42
	forme.height = 0.55
	dome.mesh = forme
	var couleur := Color(0.9, 0.12, 0.1) if rouge else Color(0.15, 0.75, 0.2)
	dome.material_override = _materiau(couleur, 0.3)
	racine.add_child(dome)
	var bord := MeshInstance3D.new()
	var anneau := TorusMesh.new()
	anneau.inner_radius = 0.34
	anneau.outer_radius = 0.46
	bord.mesh = anneau
	bord.material_override = _materiau(Color(0.97, 0.97, 0.95))
	bord.position = Vector3(0.0, -0.08, 0.0)
	racine.add_child(bord)
	return racine
