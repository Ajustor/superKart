class_name ModeleKart
extends RefCounted

## Le kart qu'on monte au garage, en trois pièces comme dans les jeux de kart :
## une carrosserie, des roues et un aileron. Chaque pièce retouche les
## caractéristiques du kart d'origine — celui sur lequel les circuits ont été
## validés — et les retouches se multiplient : une carrosserie rapide sur des
## roues rapides va plus vite encore, mais relance plus mal.
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
## L'allure suit : chaque pièce a sa forme (AtelierPieces), faite de formes
## simples en une seule maillage à couleurs de sommets, comme les pilotes.
## Quinze de chaque, des plus sages aux plus farfelues : une baignoire, un
## caddie, des roues en pizza, une cape de super-héros…

enum { STANDARD, FUSEE, PLUME, DERIVEUR, COSTAUD, BUGGY, BAIGNOIRE, CADDIE, SOUCOUPE, CITROUILLE, REQUIN,
	CHRONOMOBILE, HOT_DOG, TRACTEUR, CHAUVE_SOURIS }
enum { ROUES_STANDARD, SLICKS, MONSTRE, ROLLER, NEON, DONUTS, PIZZAS, PIERRE, VINYLES, BOUEES, COOKIES,
	ENGRENAGES, BLING, FROMAGES, WESTERN }
enum { BECQUET, GRAND_AILERON, AILETTES, VOILE, HELICE, PARASOL, AILES_ANGE, AILES_DRAGON, CAPE,
	DRAPEAU_PIRATE, BALLONS, PARABOLE, REACTEUR, NAGEOIRE, FEUX_ARTIFICE }

## Les clés des caractéristiques, dans l'ordre des jauges.
const CLES := ["vitesse", "acceleration", "virage", "glisse", "poids", "terrain"]
## Les caractéristiques affichées au garage, de 0 à 1, dans cet ordre.
const JAUGES := ["Vitesse", "Accélération", "Maniabilité", "Glisse", "Poids", "Tout-terrain"]

## Les carrosseries. `caisse` étire la caisse d'origine ; les formes propres à
## chacune sont dans AtelierPieces.
const CARROSSERIES := [
	{nom = "Standard", description = "Équilibré en tout.",
		vitesse = 1.0, acceleration = 1.0, virage = 1.0, glisse = 1.0, poids = 1.0, terrain = 1.0,
		caisse = Vector3(1.0, 1.0, 1.0)},
	{nom = "Fusée", description = "La meilleure pointe, mais long à relancer.",
		vitesse = 1.02, acceleration = 0.8, virage = 1.0, glisse = 0.9, poids = 1.1, terrain = 0.95,
		caisse = Vector3(0.94, 0.9, 1.12)},
	{nom = "Plume", description = "Vif au départ et dans les virages, pointe un peu basse.",
		vitesse = 0.985, acceleration = 1.3, virage = 1.08, glisse = 1.05, poids = 0.8, terrain = 1.0,
		caisse = Vector3(0.9, 0.95, 0.9)},
	{nom = "Dériveur", description = "Charge ses mini-turbos bien plus vite.",
		vitesse = 0.995, acceleration = 0.95, virage = 1.0, glisse = 1.3, poids = 0.95, terrain = 0.95,
		caisse = Vector3(1.04, 0.92, 1.0)},
	{nom = "Costaud", description = "Encaisse les murs et bouscule les autres.",
		vitesse = 1.01, acceleration = 0.88, virage = 0.97, glisse = 0.95, poids = 1.4, terrain = 1.05,
		caisse = Vector3(1.12, 1.08, 1.05)},
	{nom = "Buggy", description = "Taillé pour le sable et l'herbe, à l'aise partout.",
		vitesse = 0.99, acceleration = 1.1, virage = 1.0, glisse = 0.95, poids = 1.05, terrain = 1.3,
		caisse = Vector3(1.0, 1.05, 0.98)},
	{nom = "Baignoire", description = "Le bain moussant le plus rapide du quartier. Canard compris.",
		vitesse = 0.985, acceleration = 1.15, virage = 1.04, glisse = 1.1, poids = 0.95, terrain = 0.9,
		caisse = Vector3(1.0, 1.0, 1.0)},
	{nom = "Caddie", description = "Échappé du supermarché : il file entre les rayons comme entre les virages.",
		vitesse = 0.99, acceleration = 1.2, virage = 1.05, glisse = 0.95, poids = 0.75, terrain = 0.85,
		caisse = Vector3(0.95, 1.0, 1.0)},
	{nom = "Soucoupe", description = "Venue d'une galaxie lointaine, elle glisse comme sur un coussin d'air.",
		vitesse = 1.005, acceleration = 0.9, virage = 1.02, glisse = 1.1, poids = 0.9, terrain = 1.0,
		caisse = Vector3(1.0, 0.9, 1.0)},
	{nom = "Citrouille", description = "Un carrosse de conte de fées : il redevient potiron à minuit.",
		vitesse = 0.98, acceleration = 1.05, virage = 1.0, glisse = 1.05, poids = 1.2, terrain = 1.15,
		caisse = Vector3(1.0, 1.0, 1.0)},
	{nom = "Requin", description = "On va avoir besoin d'un plus grand circuit.",
		vitesse = 1.015, acceleration = 0.9, virage = 1.03, glisse = 0.95, poids = 1.1, terrain = 0.9,
		caisse = Vector3(1.0, 1.0, 1.05)},
	{nom = "Chronomobile", description = "À 88 miles à l'heure, on va voir du sérieux.",
		vitesse = 1.02, acceleration = 0.85, virage = 0.98, glisse = 1.05, poids = 1.05, terrain = 0.9,
		caisse = Vector3(1.05, 0.95, 1.05)},
	{nom = "Hot-dog", description = "Moutarde, ketchup et mini-turbos.",
		vitesse = 0.995, acceleration = 1.05, virage = 1.0, glisse = 1.0, poids = 1.15, terrain = 1.05,
		caisse = Vector3(1.0, 1.0, 1.05)},
	{nom = "Tracteur", description = "Le hors-piste ? Il le laboure.",
		vitesse = 0.98, acceleration = 1.0, virage = 0.97, glisse = 0.9, poids = 1.5, terrain = 1.4,
		caisse = Vector3(1.05, 1.1, 1.0)},
	{nom = "Chauve-souris", description = "Pas le kart qu'on mérite, mais celui dont on a besoin.",
		vitesse = 1.015, acceleration = 0.95, virage = 1.0, glisse = 1.0, poids = 1.2, terrain = 1.0,
		caisse = Vector3(1.02, 0.92, 1.08)},
]

## Rayon, largeur et couleurs de chaque train de roues. `voie` les écarte de
## la caisse.
const ROUES := [
	{nom = "Standard", description = "Des roues à tout faire.",
		vitesse = 1.0, acceleration = 1.0, virage = 1.0, glisse = 1.0, poids = 1.0, terrain = 1.0,
		rayon = 0.17, largeur = 0.15, jante = 0.07, voie = 0.0,
		pneu = Color(0.09, 0.09, 0.1), couleur_jante = Color(0.82, 0.83, 0.86)},
	{nom = "Slicks", description = "Rapides et précis sur le bitume, perdus dans l'herbe.",
		vitesse = 1.008, acceleration = 0.95, virage = 1.03, glisse = 1.0, poids = 1.0, terrain = 0.8,
		rayon = 0.16, largeur = 0.22, jante = 0.1, voie = 0.02,
		pneu = Color(0.07, 0.07, 0.08), couleur_jante = Color(0.95, 0.75, 0.2)},
	{nom = "Monstre", description = "Rien ne les arrête hors piste ; lourdes à lancer.",
		vitesse = 0.992, acceleration = 0.9, virage = 0.98, glisse = 0.97, poids = 1.15, terrain = 1.35,
		rayon = 0.24, largeur = 0.22, jante = 0.1, voie = 0.05,
		pneu = Color(0.12, 0.11, 0.1), couleur_jante = Color(0.8, 0.2, 0.18)},
	{nom = "Roller", description = "Petites et légères : une reprise éclair.",
		vitesse = 0.992, acceleration = 1.2, virage = 1.02, glisse = 1.08, poids = 0.9, terrain = 0.85,
		rayon = 0.12, largeur = 0.1, jante = 0.07, voie = 0.0,
		pneu = Color(0.92, 0.92, 0.9), couleur_jante = Color(0.2, 0.75, 0.8)},
	{nom = "Néon", description = "Elles chargent vite les mini-turbos, mais glissent hors piste.",
		vitesse = 1.0, acceleration = 1.05, virage = 1.0, glisse = 1.1, poids = 1.0, terrain = 0.9,
		rayon = 0.17, largeur = 0.15, jante = 0.12, voie = 0.0,
		pneu = Color(0.1, 0.1, 0.25), couleur_jante = Color(1.0, 0.3, 0.9)},
	{nom = "Donuts", description = "Glacés, saupoudrés de vermicelles, et étonnamment vifs.",
		vitesse = 0.992, acceleration = 1.1, virage = 1.0, glisse = 1.05, poids = 1.0, terrain = 0.9,
		rayon = 0.17, largeur = 0.16, jante = 0.06, voie = 0.01,
		pneu = Color(0.85, 0.6, 0.35), couleur_jante = Color(0.97, 0.5, 0.72)},
	{nom = "Pizzas", description = "Bien grasses : la glisse vient toute seule.",
		vitesse = 1.0, acceleration = 1.0, virage = 0.99, glisse = 1.08, poids = 1.05, terrain = 0.95,
		rayon = 0.17, largeur = 0.12, jante = 0.135, voie = 0.0,
		pneu = Color(0.86, 0.62, 0.3), couleur_jante = Color(0.85, 0.25, 0.12)},
	{nom = "Pierre", description = "Taillées à l'âge de pierre : lourdes, mais rien ne les arrête.",
		vitesse = 0.992, acceleration = 0.85, virage = 1.0, glisse = 0.95, poids = 1.25, terrain = 1.3,
		rayon = 0.19, largeur = 0.17, jante = 0.045, voie = 0.02,
		pneu = Color(0.55, 0.53, 0.5), couleur_jante = Color(0.3, 0.29, 0.28)},
	{nom = "Vinyles", description = "Elles tournent à 33 tours, précises sur le bitume.",
		vitesse = 1.004, acceleration = 1.0, virage = 1.02, glisse = 1.0, poids = 0.95, terrain = 0.8,
		rayon = 0.17, largeur = 0.06, jante = 0.065, voie = 0.03,
		pneu = Color(0.05, 0.05, 0.06), couleur_jante = Color(0.85, 0.2, 0.2)},
	{nom = "Bouées", description = "Gonflées pour la plage : légères, un peu flottantes en virage.",
		vitesse = 0.992, acceleration = 1.05, virage = 0.99, glisse = 1.1, poids = 0.85, terrain = 1.0,
		rayon = 0.18, largeur = 0.14, jante = 0.08, voie = 0.02,
		pneu = Color(0.95, 0.3, 0.25), couleur_jante = Color(0.97, 0.97, 0.97)},
	{nom = "Cookies", description = "Aux pépites de chocolat : un vrai coup de fourchette à l'accélérateur.",
		vitesse = 0.996, acceleration = 1.15, virage = 1.0, glisse = 1.0, poids = 0.95, terrain = 0.9,
		rayon = 0.17, largeur = 0.1, jante = 0.0, voie = 0.0,
		pneu = Color(0.76, 0.55, 0.3), couleur_jante = Color(0.25, 0.14, 0.08)},
	{nom = "Engrenages", description = "Mécanique de précision : elles mordent le hors-piste.",
		vitesse = 1.004, acceleration = 0.95, virage = 1.0, glisse = 1.0, poids = 1.1, terrain = 1.15,
		rayon = 0.16, largeur = 0.14, jante = 0.09, voie = 0.01,
		pneu = Color(0.72, 0.56, 0.24), couleur_jante = Color(0.35, 0.3, 0.25)},
	{nom = "Bling", description = "Jantes dorées, pour frimer dans la ligne droite.",
		vitesse = 1.006, acceleration = 0.97, virage = 1.01, glisse = 1.0, poids = 1.05, terrain = 0.85,
		rayon = 0.17, largeur = 0.13, jante = 0.14, voie = 0.01,
		pneu = Color(0.08, 0.08, 0.09), couleur_jante = Color(1.0, 0.8, 0.25)},
	{nom = "Fromages", description = "Des meules bien affinées : elles tiennent la route comme le chemin.",
		vitesse = 0.996, acceleration = 1.0, virage = 0.99, glisse = 1.0, poids = 1.1, terrain = 1.1,
		rayon = 0.18, largeur = 0.16, jante = 0.0, voie = 0.01,
		pneu = Color(0.98, 0.8, 0.3), couleur_jante = Color(0.82, 0.62, 0.18)},
	{nom = "Western", description = "Des roues de diligence, tout droit du Far West.",
		vitesse = 0.996, acceleration = 1.05, virage = 0.99, glisse = 1.05, poids = 1.0, terrain = 1.05,
		rayon = 0.2, largeur = 0.08, jante = 0.04, voie = 0.02,
		pneu = Color(0.45, 0.3, 0.15), couleur_jante = Color(0.3, 0.2, 0.1)},
]

const AILERONS := [
	{nom = "Becquet", description = "Discret, il ne change rien.",
		vitesse = 1.0, acceleration = 1.0, virage = 1.0, glisse = 1.0, poids = 1.0, terrain = 1.0},
	{nom = "Grand aileron", description = "Plaque le kart : un peu de pointe et de tenue, moins de reprise.",
		vitesse = 1.003, acceleration = 0.95, virage = 1.03, glisse = 1.0, poids = 1.03, terrain = 1.0},
	{nom = "Ailettes", description = "Légères : de la reprise, au prix d'un rien de pointe.",
		vitesse = 0.997, acceleration = 1.06, virage = 1.02, glisse = 1.0, poids = 0.95, terrain = 1.0},
	{nom = "Voile", description = "Prend le vent en glisse : des mini-turbos plus rapides.",
		vitesse = 0.997, acceleration = 1.0, virage = 1.0, glisse = 1.08, poids = 1.0, terrain = 1.05},
	{nom = "Hélice", description = "Elle brasse l'air : les mini-turbos durent, la reprise un peu moins.",
		vitesse = 1.003, acceleration = 0.97, virage = 1.0, glisse = 1.05, poids = 1.0, terrain = 1.0},
	{nom = "Parasol", description = "Pour la course comme pour la sieste.",
		vitesse = 0.997, acceleration = 1.02, virage = 1.0, glisse = 1.03, poids = 1.0, terrain = 1.05},
	{nom = "Ailes d'ange", description = "Légères comme une plume. Ou deux cents.",
		vitesse = 0.997, acceleration = 1.05, virage = 1.0, glisse = 1.0, poids = 0.92, terrain = 1.0},
	{nom = "Ailes de dragon", description = "Pour qui veut voler la vedette.",
		vitesse = 1.003, acceleration = 0.97, virage = 1.0, glisse = 1.05, poids = 1.05, terrain = 1.0},
	{nom = "Cape", description = "Les super-héros en portent toujours une, même quand on le leur déconseille.",
		vitesse = 1.002, acceleration = 1.0, virage = 1.02, glisse = 1.0, poids = 1.0, terrain = 0.97},
	{nom = "Drapeau pirate", description = "À l'abordage ! Une reprise de flibustier.",
		vitesse = 1.0, acceleration = 1.03, virage = 1.0, glisse = 1.02, poids = 1.0, terrain = 0.97},
	{nom = "Ballons", description = "De quoi faire décoller une maison. Ou un kart, presque.",
		vitesse = 0.997, acceleration = 1.04, virage = 0.99, glisse = 1.0, poids = 0.9, terrain = 1.0},
	{nom = "Parabole", description = "Capte la trajectoire idéale en haute définition.",
		vitesse = 1.0, acceleration = 0.98, virage = 1.03, glisse = 1.0, poids = 1.02, terrain = 1.0},
	{nom = "Réacteur", description = "Une poussée de jet… et un peu de mal à tourner.",
		vitesse = 1.003, acceleration = 1.04, virage = 0.995, glisse = 0.97, poids = 1.05, terrain = 1.0},
	{nom = "Nageoire", description = "Pour filer dans les virages comme un poisson dans l'eau.",
		vitesse = 1.0, acceleration = 1.0, virage = 1.01, glisse = 1.04, poids = 1.0, terrain = 0.96},
	{nom = "Feux d'artifice", description = "Le bouquet final, avant même l'arrivée.",
		vitesse = 1.003, acceleration = 1.03, virage = 1.0, glisse = 0.98, poids = 1.0, terrain = 0.98},
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
	[REQUIN, BOUEES, NAGEOIRE],
	[SOUCOUPE, NEON, PARABOLE],
	[CHRONOMOBILE, ROLLER, AILETTES],
	[CITROUILLE, SLICKS, HELICE],
	[CHAUVE_SOURIS, DONUTS, CAPE],
	[BAIGNOIRE, BLING, FEUX_ARTIFICE],
	[HOT_DOG, WESTERN, DRAPEAU_PIRATE],
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


static var _pieces: Dictionary = {}
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


## Le kart de l'IA numéro `n` (0 pour le premier adversaire) : carrosserie,
## roues, aileron.
static func kart_ia(n: int) -> Array:
	return KARTS_IA[posmod(n, KARTS_IA.size())]


## Une caractéristique de la combinaison : le produit de ce qu'en dit chaque
## pièce.
static func facteur(cle: String, carrosserie: int, train: int = ROUES_STANDARD, aile: int = BECQUET) -> float:
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

## Repeint la carrosserie d'un kart (les pièces qui portent la couleur de son
## plancher), lui donne la forme de sa carrosserie, monte ses roues et son
## aileron. Les matériaux de la scène sont partagés entre toutes ses
## instances : on repeint avec des copies. Se rappelle autant qu'on veut
## (le garage le fait à chaque choix).
static func habiller(kart: Node3D, carrosserie: int, teinte: Color, train: int = ROUES_STANDARD,
		aile: int = BECQUET) -> void:
	var caisse := kart.get_node_or_null("Body") as Node3D
	if caisse == null:
		return
	caisse.scale = modele(carrosserie).caisse
	_peindre(caisse, teinte)
	_poser(caisse, "Carrosserie", _piece("c%d" % carrosserie, teinte, AtelierPieces.carrosserie.bind(carrosserie)))
	_poser(caisse, "Aileron", _piece("a%d" % aile, teinte, AtelierPieces.aileron.bind(aile)))
	_monter_les_roues(kart, train)


static func _peindre(caisse: Node3D, teinte: Color) -> void:
	var plancher := caisse.get_node_or_null("Floor") as MeshInstance3D
	if plancher == null:
		return
	if not plancher.has_meta("peinture_origine"):
		plancher.set_meta("peinture_origine", plancher.get_surface_override_material(0))
	var origine := plancher.get_meta("peinture_origine") as StandardMaterial3D
	if origine == null:
		return
	var peinture := origine.duplicate() as StandardMaterial3D
	peinture.albedo_color = teinte
	for piece in caisse.find_children("*", "MeshInstance3D", true, false):
		var mesh := piece as MeshInstance3D
		var actuel := mesh.get_surface_override_material(0)
		if actuel == origine or (actuel != null and actuel.has_meta("peinture")):
			mesh.set_surface_override_material(0, peinture)
	peinture.set_meta("peinture", true)


static func _poser(caisse: Node3D, nom_noeud: String, maillage: Mesh) -> void:
	var noeud := caisse.get_node_or_null(nom_noeud) as MeshInstance3D
	if noeud == null:
		noeud = MeshInstance3D.new()
		noeud.name = nom_noeud
		caisse.add_child(noeud)
	noeud.mesh = maillage


static func _piece(cle: String, teinte: Color, faire: Callable) -> Mesh:
	var cle_teinte := "%s_%s" % [cle, teinte.to_html(false)]
	if not _pieces.has(cle_teinte):
		var a := Personnage.Atelier.new()
		faire.call(a, teinte)
		_pieces[cle_teinte] = a.maillage() if not a.sommets.is_empty() else null
	return _pieces[cle_teinte]


## Les roues : leur forme, leur hauteur (une roue plus grande se monte plus
## haut, pour toucher le même sol) et leur voie. La suspension apprend leur
## rayon : c'est lui qui la pose au sol.
static func _monter_les_roues(kart: Node3D, train: int) -> void:
	var r := roues(train)
	var maillage := _piece("r%d" % train, Color.BLACK, AtelierPieces.roue.bind(train))
	var rayon: float = r.rayon
	var suspension := kart.get_node_or_null("Suspension") as KartSuspension
	var rayon_origine := 0.17
	if suspension != null:
		if not suspension.has_meta("rayon_origine"):
			suspension.set_meta("rayon_origine", suspension.wheel_radius)
		rayon_origine = suspension.get_meta("rayon_origine")
		suspension.wheel_radius = rayon
	var train_de_roues := kart.get_node_or_null("Wheels") as Node3D
	if train_de_roues == null:
		return
	for roue in train_de_roues.get_children():
		var r3 := roue as Node3D
		if r3 == null:
			continue
		if not r3.has_meta("position_origine"):
			r3.set_meta("position_origine", r3.position)
		var origine: Vector3 = r3.get_meta("position_origine")
		r3.position = Vector3(origine.x + signf(origine.x) * float(r.voie),
			origine.y + rayon - rayon_origine, origine.z)
		var pneu := r3.get_node_or_null("Tire") as MeshInstance3D
		if pneu != null:
			pneu.mesh = maillage
			pneu.set_surface_override_material(0, null)
		var moyeu := r3.get_node_or_null("Hub") as Node3D
		if moyeu != null:
			moyeu.visible = false


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
