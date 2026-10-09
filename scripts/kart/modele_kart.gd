class_name ModeleKart
extends RefCounted

## Le kart qu'on monte au garage : un kart, des roues, une couleur.
## Chaque choix retouche les caractéristiques du kart d'origine — celui sur
## lequel les circuits ont été validés — et les retouches se multiplient : un
## moteur rapide sur des roues rapides va plus vite encore, mais relance plus
## mal.
##
## Ce qu'on gagne d'un côté se paie de l'autre :
## - vitesse : la vitesse de pointe ;
## - acceleration : la reprise, après un choc ou au départ ;
## - virage : le braquage, en adhérence comme en glisse ;
## - glisse : la vitesse de charge des mini-turbos ;
## - poids : les chocs. Un kart lourd perd moins contre un mur et pousse les
##   autres ; un léger se fait bousculer ;
## - terrain : ce qu'on garde de sa vitesse hors de la piste.
##
## Les sauts, eux, passent avec toutes les combinaisons : comme pour les
## cylindrées, la gravité suit la vitesse de pointe, et chaque saut garde sa
## parabole. La pointe se paie en virage : le braquage ne la suit pas.
##
## L'allure : le kart du Car Kit de Kenney (CC0, assets/kenney/LICENCE.txt),
## repeint à la couleur choisie, sur l'un de ses trains de roues. Le réglage
## moteur ne se voit pas : c'est ce qu'on a sous le capot. Les ailerons ne
## sont plus qu'un : « Aucun », gardé pour que les réglages enregistrés et le
## salon en réseau gardent leur forme.
##
## Une exception : le nuage magique (NuageMagique), sur lequel le pilote se
## tient debout. Ni caisse, ni roues, ni peinture : il est toujours doré, et
## roule comme s'il était monté sur les roues Standard.

enum { STANDARD, FUSEE, PLUME, DERIVEUR, COSTAUD, NUAGE }
enum { ROUES_STANDARD, SLICKS, MONSTRE, LEGERES }
enum { BECQUET }

## Les clés des caractéristiques, dans l'ordre des jauges.
const CLES := ["vitesse", "acceleration", "virage", "glisse", "poids", "terrain"]
## Les caractéristiques affichées au garage, de 0 à 1, dans cet ordre.
const JAUGES := ["Vitesse", "Accélération", "Maniabilité", "Glisse", "Poids", "Tout-terrain"]

## Les karts du garage (anciennement les carrosseries) : les réglages moteur
## du kart Kenney, puis le nuage magique. Toujours ajoutés en fin de liste :
## une sauvegarde garde ses indices.
const CARROSSERIES := [
	{nom = "Standard", description = "Équilibré en tout.",
		vitesse = 1.0, acceleration = 1.0, virage = 1.0, glisse = 1.0, poids = 1.0, terrain = 1.0},
	{nom = "Fusée", description = "La meilleure pointe, mais long à relancer.",
		vitesse = 1.02, acceleration = 0.8, virage = 1.0, glisse = 0.9, poids = 1.1, terrain = 0.95},
	{nom = "Plume", description = "Vif au départ et dans les virages, pointe un peu basse.",
		vitesse = 0.985, acceleration = 1.3, virage = 1.08, glisse = 1.05, poids = 0.8, terrain = 1.0},
	{nom = "Dériveur", description = "Charge ses mini-turbos bien plus vite.",
		vitesse = 0.995, acceleration = 0.95, virage = 1.0, glisse = 1.3, poids = 0.95, terrain = 0.95},
	{nom = "Costaud", description = "Encaisse les murs et bouscule les autres.",
		vitesse = 1.01, acceleration = 0.88, virage = 0.97, glisse = 0.95, poids = 1.4, terrain = 1.05},
	{nom = "Nuage magique", description = "Il flotte sur l'herbe et glisse comme un rêve, mais un rien le bouscule.",
		vitesse = 0.995, acceleration = 0.9, virage = 1.0, glisse = 1.25, poids = 0.75, terrain = 1.35},
]

## Les trains de roues. `modele` : le fichier Kenney (vide : les roues du kart
## lui-même) ; `echelle` le ramène à la taille voulue ; `rayon`, en mètres
## une fois le kart à sa taille, pose la suspension.
const ROUES := [
	{nom = "Standard", description = "Des roues à tout faire.",
		vitesse = 1.0, acceleration = 1.0, virage = 1.0, glisse = 1.0, poids = 1.0, terrain = 1.0,
		modele = "", echelle = 1.0, rayon = 0.336},
	{nom = "Slicks", description = "Rapides et précis sur le bitume, perdus dans l'herbe.",
		vitesse = 1.008, acceleration = 0.95, virage = 1.03, glisse = 1.0, poids = 1.0, terrain = 0.8,
		modele = "wheel-racing", echelle = 0.7, rayon = 0.336},
	{nom = "Tout-terrain", description = "Rien ne les arrête hors piste ; lourdes à lancer.",
		vitesse = 0.992, acceleration = 0.9, virage = 0.98, glisse = 0.97, poids = 1.15, terrain = 1.35,
		modele = "wheel-dark", echelle = 0.85, rayon = 0.408},
	{nom = "Légères", description = "Petites et légères : une reprise éclair.",
		vitesse = 0.992, acceleration = 1.2, virage = 1.02, glisse = 1.08, poids = 0.9, terrain = 0.85,
		modele = "wheel-default", echelle = 0.6, rayon = 0.288},
]

const AILERONS := [
	{nom = "Aucun", description = "Rien à l'arrière.",
		vitesse = 1.0, acceleration = 1.0, virage = 1.0, glisse = 1.0, poids = 1.0, terrain = 1.0},
]

## Ancien nom des carrosseries : un kart d'avant la v1.9 n'avait qu'elles.
const MODELES := CARROSSERIES

## Les karts de l'IA, du deuxième au huitième : variés, mais tous à 1 % de la
## vitesse d'origine. Le classement de l'IA reste une affaire de pilote : un
## kart 4 % plus rapide gagnait 37 courses sur 40, même sur un pilote moyen.
## Aucun n'est très lourd non plus : un Costaud sur roues Monstre (poids 1,6)
## poussait les autres hors des routes sans mur.
## Fixés plutôt que tirés au sort, pour que chaque machine d'une partie en
## réseau habille l'IA de la même façon.
const KARTS_IA := [
	[STANDARD, SLICKS, BECQUET],
	[PLUME, SLICKS, BECQUET],
	[DERIVEUR, ROUES_STANDARD, BECQUET],
	[STANDARD, LEGERES, BECQUET],
	[DERIVEUR, SLICKS, BECQUET],
	[STANDARD, MONSTRE, BECQUET],
	[STANDARD, ROUES_STANDARD, BECQUET],
]

## Les couleurs de carrosserie. La première est celle d'origine du kart du
## joueur ; l'IA prend les autres, dans l'ordre.
const COULEURS: Array[Color] = [
	Color(0.20, 0.45, 0.85),  # bleu
	Color(0.78, 0.22, 0.20),  # rouge
	Color(0.20, 0.68, 0.30),  # vert
	Color(0.95, 0.78, 0.15),  # jaune
	Color(0.55, 0.30, 0.85),  # violet
	Color(0.95, 0.50, 0.12),  # orange
	Color(0.95, 0.45, 0.70),  # rose
	Color(0.16, 0.16, 0.19),  # noir
]
const NOMS_COULEURS := ["Bleu", "Rouge", "Vert", "Jaune", "Violet", "Orange", "Rose", "Noir"]


static var _bornes: Array = []


static func nombre() -> int:
	return CARROSSERIES.size()


static func nombre_roues() -> int:
	return ROUES.size()


static func nombre_ailerons() -> int:
	return AILERONS.size()


static func modele(i: int) -> Dictionary:
	return CARROSSERIES[clampi(i, 0, CARROSSERIES.size() - 1)]


static func roues(i: int) -> Dictionary:
	return ROUES[clampi(i, 0, ROUES.size() - 1)]


static func aileron(i: int) -> Dictionary:
	return AILERONS[clampi(i, 0, AILERONS.size() - 1)]


static func nom(i: int) -> String:
	return modele(i).nom


static func couleur(i: int) -> Color:
	return COULEURS[posmod(i, COULEURS.size())]


## Le nuage magique n'a ni roues ni peinture : le garage cache ces choix.
static func est_nuage(carrosserie: int) -> bool:
	return carrosserie == NUAGE


## Ce kart (ou la vitrine du garage) est-il habillé en nuage ?
static func sur_un_nuage(kart: Node) -> bool:
	return kart != null and est_nuage(int(kart.get_meta("carrosserie", STANDARD)))


## Le kart de l'IA numéro `n` (0 pour le premier adversaire) : carrosserie,
## roues, aileron.
static func kart_ia(n: int) -> Array:
	return KARTS_IA[posmod(n, KARTS_IA.size())]


## Une caractéristique de la combinaison : le produit de ce qu'en dit chaque
## pièce.
## Le nuage n'a pas de roues : celles qu'on avait choisies n'y changent rien.
static func facteur(cle: String, carrosserie: int, train: int = ROUES_STANDARD, aile: int = BECQUET) -> float:
	if est_nuage(carrosserie):
		train = ROUES_STANDARD
	return float(modele(carrosserie)[cle]) * float(roues(train)[cle]) * float(aileron(aile)[cle])


## Les caractéristiques de cette combinaison, d'après `base`. Une copie : la
## ressource d'origine est partagée.
static func stats(base: KartStats, carrosserie: int, train: int = ROUES_STANDARD,
		aile: int = BECQUET) -> KartStats:
	var s := base.duplicate() as KartStats
	if carrosserie == STANDARD and train == ROUES_STANDARD and aile == BECQUET:
		return s
	var f := {}
	for cle in CLES:
		f[cle] = facteur(cle, carrosserie, train, aile)
	s.max_speed *= f.vitesse
	s.acceleration *= f.acceleration
	# Le braquage ne suit pas la vitesse : une combinaison rapide prend ses
	# virages plus large, c'est ce que coûte la pointe. Toutes restent sous
	# le rayon de l'épingle du circuit 1 (voir test_garage).
	s.turn_rate *= f.virage
	s.drift_turn_rate *= f.virage
	# Les sauts gardent leur parabole (voir Cylindree).
	s.gravity *= f.vitesse * f.vitesse
	s.echelle_des_tremplins *= f.vitesse
	# Charger plus vite, c'est atteindre chaque palier plus tôt ; et le
	# mini-turbo dure un peu plus, comme le mini-turbo des jeux de kart.
	var paliers := PackedFloat32Array()
	for p in s.drift_tiers:
		paliers.append(p / f.glisse)
	s.drift_tiers = paliers
	var durees := PackedFloat32Array()
	for d in s.boost_durations:
		durees.append(d * sqrt(f.glisse))
	s.boost_durations = durees
	s.poids *= f.poids
	# Un kart lourd perd moins de vitesse contre un mur.
	s.wall_speed_loss = clampf(s.wall_speed_loss / sqrt(f.poids), 0.3, 0.95)
	s.offroad_speed_multiplier = clampf(s.offroad_speed_multiplier * f.terrain, 0.3, 0.9)
	return s


## Les jauges du garage, de 0 à 1 : chaque caractéristique de la combinaison
## ramenée à l'étendue qu'elle couvre d'une combinaison à l'autre.
static func jauges(carrosserie: int, train: int = ROUES_STANDARD, aile: int = BECQUET) -> PackedFloat32Array:
	var bornes := _etendues()
	var valeurs := PackedFloat32Array()
	for k in CLES.size():
		var mini: float = bornes[k].x
		var maxi: float = bornes[k].y
		var v := facteur(CLES[k], carrosserie, train, aile)
		# Jamais vide : une jauge à zéro ferait croire à un défaut.
		valeurs.append(lerpf(0.15, 1.0, (v - mini) / maxf(maxi - mini, 0.0001)))
	return valeurs


## Le plus bas et le plus haut de chaque caractéristique, sur toutes les
## combinaisons.
static func _etendues() -> Array:
	if not _bornes.is_empty():
		return _bornes
	for cle in CLES:
		var mini := INF
		var maxi := -INF
		for c in CARROSSERIES.size():
			for r in ROUES.size():
				for a in AILERONS.size():
					var v := facteur(cle, c, r, a)
					mini = minf(mini, v)
					maxi = maxf(maxi, v)
		_bornes.append(Vector2(mini, maxi))
	return _bornes


# --- Allure ------------------------------------------------------------------

const DOSSIER := "res://assets/kenney/karts/"
const KART := DOSSIER + "kart-oobi.glb"
## Le kart Kenney mesure 0,93 m de large : à cette échelle, il a la voie du
## kart d'origine, et ses roues de série 0,34 m de rayon.
const ECHELLE := 1.6
## Les roues du kart Kenney, dans son repère (l'avant vers +z), dans l'ordre
## des roues de la scène : avant gauche, avant droite, arrière gauche,
## arrière droite. Leur rayon y est de 0,21.
const ROUES_KENNEY := [
	["wheel-front-left", Vector3(0.277372, 0.209777, 0.323733)],
	["wheel-front-right", Vector3(-0.277372, 0.209777, 0.323733)],
	["wheel-back-left", Vector3(0.277372, 0.209777, -0.360607)],
	["wheel-back-right", Vector3(-0.277372, 0.209777, -0.360607)],
]
const RAYON_KENNEY := 0.209777
## Le pilote s'assoit là, dans le repère du kart Kenney, un peu plus grand
## que nature : de dos, sous la caméra de poursuite, sa tête et ses épaules
## doivent dépasser du dossier.
const SIEGE_KENNEY := Vector3(0.0, 0.2, -0.04)
const ECHELLE_PILOTE := 1.35
## Sur le nuage, le pilote se tient debout au centre, les pieds dans le haut
## de la ouate, à cette hauteur au-dessus du sol. Un peu plus petit qu'assis :
## debout à pleine taille, il cachait la route à la caméra de poursuite.
const PIEDS_SUR_LE_NUAGE := 0.5
const ECHELLE_PILOTE_DEBOUT := 1.1
## Les pièces du kart d'origine, faites de formes simples : on les cache.
const PIECES_D_ORIGINE := ["Floor", "Nose", "SidePodL", "SidePodR", "SeatBase", "SeatBack", "Engine", "Column"]

static var _scenes: Dictionary = {}
static var _peintures: Dictionary = {}


## Le kart Kenney tourné vers -z, comme les karts du jeu, et à leur taille.
static func repere_kenney() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * ECHELLE), Vector3.ZERO)


## Où s'assoit le pilote, dans le repère de la caisse (Body). Sur le nuage,
## il se tient debout en son centre, quelles que soient les roues.
static func siege(train: int = ROUES_STANDARD, carrosserie: int = STANDARD) -> Transform3D:
	var t := repere_kenney()
	if est_nuage(carrosserie):
		t.origin = Vector3.UP * PIEDS_SUR_LE_NUAGE
		t.basis = t.basis.scaled(Vector3.ONE * ECHELLE_PILOTE_DEBOUT)
		return t
	t.origin = t * SIEGE_KENNEY + Vector3.UP * _surelevation(train)
	t.basis = t.basis.scaled(Vector3.ONE * ECHELLE_PILOTE)
	return t


## De grandes roues lèvent la caisse d'autant.
static func _surelevation(train: int) -> float:
	return float(roues(train).rayon) - RAYON_KENNEY * ECHELLE


static func _scene(chemin: String) -> PackedScene:
	if not _scenes.has(chemin):
		_scenes[chemin] = load(chemin)
	return _scenes[chemin]


## Habille un kart (ou la vitrine du garage) : le kart Kenney dans la caisse,
## peint de `teinte`, sur le train de roues choisi. La suspension apprend le
## rayon des roues. Se rappelle autant qu'on veut (le garage le fait à chaque
## choix).
##
## Le nuage magique remplace la caisse (`Body/Nuage` au lieu de
## `Body/Kenney`) et cache les jantes : les nœuds des roues restent, la
## suspension en a besoin, posés comme des roues Standard.
static func habiller(kart: Node3D, carrosserie: int, teinte: Color, train: int = ROUES_STANDARD,
		_aile: int = BECQUET) -> void:
	var caisse := kart.get_node_or_null("Body") as Node3D
	if caisse == null:
		return
	var nuage := est_nuage(carrosserie)
	if nuage:
		train = ROUES_STANDARD
	kart.set_meta("train", train)
	kart.set_meta("carrosserie", clampi(carrosserie, 0, CARROSSERIES.size() - 1))
	for nom_piece in PIECES_D_ORIGINE:
		var piece := caisse.get_node_or_null(nom_piece) as Node3D
		if piece != null:
			piece.visible = false
	var chassis := caisse.get_node_or_null("Kenney") as Node3D
	if chassis == null:
		chassis = _scene(KART).instantiate() as Node3D
		chassis.name = "Kenney"
		caisse.add_child(chassis)
		# Ses roues et son pilote extraterrestre : les roues sont celles de
		# la scène (la suspension les fait tourner), le pilote est Personnage.
		for r in ROUES_KENNEY:
			(chassis.find_child(r[0], true, false) as Node3D).visible = false
		(chassis.find_child("character", true, false) as Node3D).visible = false
	chassis.transform = repere_kenney()
	chassis.position.y = _surelevation(train)
	chassis.visible = not nuage
	var corps := chassis.find_child("kart-oobi", true, false) as MeshInstance3D
	corps.material_override = peinture(teinte)
	var le_nuage := caisse.get_node_or_null("Nuage") as Node3D
	if nuage and le_nuage == null:
		le_nuage = NuageMagique.new()
		le_nuage.name = "Nuage"
		caisse.add_child(le_nuage)
	if le_nuage != null:
		le_nuage.visible = nuage
	_monter_les_roues(kart, train, chassis, not nuage)
	# Le pilote suit la hauteur de la caisse ; sur le nuage, il se lève.
	var pilote := caisse.get_node_or_null("Pilote") as Node3D
	if pilote != null:
		pilote.transform = siege(train, carrosserie)
		Personnage.jouer(pilote, Personnage.animation_de(kart))


## Le matériau du châssis repeint : le gris-bleu de sa carrosserie prend la
## teinte, les détails jaunes restent. Partagé entre tous les karts d'une
## même couleur.
static func peinture(teinte: Color) -> ShaderMaterial:
	var cle := teinte.to_html(false)
	if not _peintures.has(cle):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/kart_peint.gdshader")
		m.set_shader_parameter("teinte", teinte)
		m.set_shader_parameter("palette", load(DOSSIER + "kart-oobi_colormap.png"))
		_peintures[cle] = m
	return _peintures[cle]


## La teinte d'un kart habillé (la vitrine du garage, les tests).
static func teinte_de(kart: Node3D) -> Color:
	var corps := kart.get_node_or_null("Body/Kenney/kart-oobi") as MeshInstance3D
	if corps == null or corps.material_override == null:
		return Color.TRANSPARENT
	return (corps.material_override as ShaderMaterial).get_shader_parameter("teinte")


## Les roues : leur forme, leur place (celle des roues du kart Kenney), leur
## hauteur (une roue plus grande se monte plus haut, pour toucher le même
## sol). La suspension apprend leur rayon : c'est lui qui la pose au sol.
static func _monter_les_roues(kart: Node3D, train: int, chassis: Node3D, visibles: bool = true) -> void:
	var r := roues(train)
	var rayon: float = r.rayon
	var suspension := kart.get_node_or_null("Suspension") as KartSuspension
	var pendant := 0.195
	if suspension != null:
		suspension.wheel_radius = rayon
		pendant = suspension.rest_length - suspension.travel * 0.5
	var train_de_roues := kart.get_node_or_null("Wheels") as Node3D
	if train_de_roues == null:
		return
	var repere := repere_kenney()
	var n := 0
	for roue in train_de_roues.get_children():
		var r3 := roue as Node3D
		if r3 == null or n >= ROUES_KENNEY.size():
			continue
		var kenney: Array = ROUES_KENNEY[n]
		n += 1
		var place: Vector3 = repere * (kenney[1] as Vector3)
		# L'ancre de la suspension : la roue pend dessous, de la longueur du
		# ressort au repos, et touche alors le sol.
		r3.position = Vector3(place.x, rayon + pendant, place.z)
		for nom_cache in ["Tire", "Hub"]:
			var cache := r3.get_node_or_null(nom_cache) as Node3D
			if cache != null:
				cache.visible = false
		var jante := r3.get_node_or_null("Jante") as MeshInstance3D
		if jante == null:
			jante = MeshInstance3D.new()
			jante.name = "Jante"
			r3.add_child(jante)
		jante.visible = visibles
		var gauche := place.x < 0.0
		if str(r.modele) == "":
			# Les roues du kart, chacune tournée vers l'extérieur.
			jante.mesh = (chassis.find_child(kenney[0], true, false) as MeshInstance3D).mesh
			jante.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * ECHELLE), Vector3.ZERO)
		else:
			jante.mesh = _maillage_de_roue(str(r.modele))
			var echelle := ECHELLE * float(r.echelle)
			# Centrées sur leur axe : on les pousse vers l'extérieur de la
			# moitié de leur largeur, la jante côté dehors.
			var largeur := 0.4 * echelle
			jante.transform = Transform3D(
				Basis(Vector3.UP, PI if gauche else 0.0).scaled(Vector3.ONE * echelle),
				Vector3((-1.0 if gauche else 1.0) * largeur * 0.5, 0.0, 0.0))


static func _maillage_de_roue(modele: String) -> Mesh:
	var cle := "roue_" + modele
	if not _scenes.has(cle):
		var n := _scene(DOSSIER + modele + ".glb").instantiate()
		_scenes[cle] = (n.find_child(modele, true, false) as MeshInstance3D).mesh
		n.free()
	return _scenes[cle]


## Les couleurs de l'IA : celles de la palette que personne n'a prises, dans
## l'ordre, puis on recommence.
static func couleurs_libres(prises: Array) -> Array[int]:
	var libres: Array[int] = []
	for c in COULEURS.size():
		if not prises.has(c):
			libres.append(c)
	if libres.is_empty():
		for c in COULEURS.size():
			libres.append(c)
	return libres
