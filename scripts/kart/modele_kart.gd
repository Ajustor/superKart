class_name ModeleKart
extends RefCounted

## Les karts qu'on peut choisir au garage, et leurs couleurs. Chaque modèle
## retouche les caractéristiques du kart d'origine — celui sur lequel les
## circuits ont été validés — sans s'en éloigner beaucoup : un choix de
## style, pas un kart qui gagne à coup sûr.
##
## Ce qu'on gagne d'un côté se paie de l'autre :
## - vitesse : la vitesse de pointe ;
## - acceleration : la reprise, après un choc ou au départ ;
## - virage : le braquage, en adhérence comme en glisse ;
## - glisse : la vitesse de charge des mini-turbos ;
## - poids : les chocs. Un kart lourd perd moins contre un mur et pousse les
##   autres ; un léger se fait bousculer.

enum { STANDARD, FUSEE, PLUME, DERIVEUR, COSTAUD }

const MODELES := [
	{nom = "Standard", description = "Équilibré en tout.",
		vitesse = 1.0, acceleration = 1.0, virage = 1.0, glisse = 1.0, poids = 1.0,
		caisse = Vector3(1.0, 1.0, 1.0)},
	{nom = "Fusée", description = "La meilleure pointe, mais long à relancer.",
		vitesse = 1.04, acceleration = 0.8, virage = 1.0, glisse = 0.9, poids = 1.1,
		caisse = Vector3(0.94, 0.9, 1.12)},
	{nom = "Plume", description = "Vif au départ et dans les virages, pointe un peu basse.",
		vitesse = 0.97, acceleration = 1.3, virage = 1.08, glisse = 1.05, poids = 0.8,
		caisse = Vector3(0.9, 0.95, 0.9)},
	{nom = "Dériveur", description = "Charge ses mini-turbos bien plus vite.",
		vitesse = 0.99, acceleration = 0.95, virage = 1.0, glisse = 1.3, poids = 0.95,
		caisse = Vector3(1.04, 0.92, 1.0)},
	{nom = "Costaud", description = "Encaisse les murs et bouscule les autres.",
		vitesse = 1.02, acceleration = 0.88, virage = 0.97, glisse = 0.95, poids = 1.4,
		caisse = Vector3(1.12, 1.08, 1.05)},
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

## Les caractéristiques affichées au garage, de 0 à 1, dans cet ordre.
const JAUGES := ["Vitesse", "Accélération", "Maniabilité", "Glisse", "Poids"]


static func nombre() -> int:
	return MODELES.size()


static func modele(i: int) -> Dictionary:
	return MODELES[clampi(i, 0, MODELES.size() - 1)]


static func nom(i: int) -> String:
	return modele(i).nom


static func couleur(i: int) -> Color:
	return COULEURS[posmod(i, COULEURS.size())]


## Les caractéristiques de ce modèle, d'après `base`. Une copie : la
## ressource d'origine est partagée.
static func stats(base: KartStats, i: int) -> KartStats:
	var m := modele(i)
	var s := base.duplicate() as KartStats
	if i == STANDARD:
		return s
	s.max_speed *= m.vitesse
	s.acceleration *= m.acceleration
	s.turn_rate *= m.virage
	s.drift_turn_rate *= m.virage
	# Charger plus vite, c'est atteindre chaque palier plus tôt.
	var paliers := PackedFloat32Array()
	for p in s.drift_tiers:
		paliers.append(p / m.glisse)
	s.drift_tiers = paliers
	s.poids *= m.poids
	# Un kart lourd perd moins de vitesse contre un mur.
	s.wall_speed_loss = clampf(s.wall_speed_loss / sqrt(m.poids), 0.3, 0.95)
	return s


## Les jauges du garage, de 0 à 1 : chaque caractéristique ramenée à
## l'étendue qu'elle couvre d'un modèle à l'autre.
static func jauges(i: int) -> PackedFloat32Array:
	var m := modele(i)
	var cles := ["vitesse", "acceleration", "virage", "glisse", "poids"]
	var valeurs := PackedFloat32Array()
	for cle in cles:
		var mini := INF
		var maxi := -INF
		for autre in MODELES:
			mini = minf(mini, autre[cle])
			maxi = maxf(maxi, autre[cle])
		# Jamais vide : une jauge à zéro ferait croire à un défaut.
		valeurs.append(lerpf(0.2, 1.0, (m[cle] - mini) / maxf(maxi - mini, 0.0001)))
	return valeurs


## Repeint la carrosserie d'un kart (les pièces qui portent la couleur de son
## plancher), et donne à la caisse l'allure de son modèle. Les matériaux de
## la scène sont partagés entre toutes ses instances : on repeint avec des
## copies.
static func habiller(kart: Node3D, i: int, teinte: Color) -> void:
	var caisse := kart.get_node_or_null("Body") as Node3D
	if caisse == null:
		return
	caisse.scale = modele(i).caisse
	var plancher := caisse.get_node_or_null("Floor") as MeshInstance3D
	if plancher == null:
		return
	var origine := plancher.get_surface_override_material(0)
	if origine == null:
		return
	var peinture := origine.duplicate() as StandardMaterial3D
	peinture.albedo_color = teinte
	for piece in caisse.find_children("*", "MeshInstance3D", true, false):
		var mesh := piece as MeshInstance3D
		if mesh.get_surface_override_material(0) == origine:
			mesh.set_surface_override_material(0, peinture)


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
