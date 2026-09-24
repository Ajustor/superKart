class_name Cylindree
extends RefCounted

## Les trois cylindrées, comme dans Mario Kart : même circuit, même kart, mais
## tout va moins vite en 50cc. La 150cc est le réglage d'origine, celui sur
## lequel les circuits ont été validés : les deux autres n'en sont que des
## réductions.
##
## La vitesse de pointe et l'accélération changent. Le braquage reste le
## même : à vitesse moindre, les virages se prennent plus serrés, c'est ce qui
## rend la petite cylindrée plus facile.
##
## Les sauts, eux, doivent passer partout : un kart plus lent qui quitte une
## rampe retombait dans le trou qu'elle enjambe. La gravité suit donc le carré
## du facteur de vitesse, et l'impulsion des tremplins le facteur lui-même :
## chaque trajectoire reste la même parabole, parcourue plus lentement.

enum Classe { CC50, CC100, CC150, CC200 }

const NOMS := ["50cc", "100cc", "150cc", "200cc"]

## Part de la vitesse de pointe et de l'accélération de la 150cc.
const VITESSE := [0.78, 0.89, 1.0, 1.18]

## Allure des karts de l'IA, relativement au joueur : en 50cc, ils laissent un
## peu de marge ; en 150cc, ils roulent avec les mêmes armes que lui.
const ALLURE_IA := [0.95, 0.975, 1.0, 1.0]


static func nom(classe: int) -> String:
	return NOMS[clampi(classe, 0, NOMS.size() - 1)]


## Les caractéristiques d'un kart dans cette cylindrée. Une copie : la
## ressource d'origine est partagée par tous les karts, et par les tests.
static func stats(base: KartStats, classe: int, ia: bool) -> KartStats:
	var s := base.duplicate() as KartStats
	var facteur: float = VITESSE[clampi(classe, 0, VITESSE.size() - 1)]
	if ia:
		facteur *= ALLURE_IA[clampi(classe, 0, ALLURE_IA.size() - 1)]
	s.max_speed *= facteur
	s.acceleration *= facteur
	s.gravity *= facteur * facteur
	s.echelle_des_tremplins *= facteur
	# Plus vite que la 150cc, le braquage suit : sans ça, un rayon de braquage
	# de 14 m ne passait plus les épingles de 12,5 m. Les virages gardent leur
	# forme, ils défilent seulement plus vite. En dessous, on garde le braquage
	# de la 150cc : c'est ce qui rend la petite cylindrée plus facile.
	if facteur > 1.0:
		s.turn_rate *= facteur
		s.drift_turn_rate *= facteur
	return s


## Règle chaque kart de la course, avant son entrée dans l'arbre : le moteur
## se construit à partir de ses caractéristiques dans _ready.
static func appliquer(course: Node, classe: int) -> void:
	if classe == Classe.CC150:
		return
	for enfant in course.get_children():
		var kart := enfant as Kart
		if kart != null and kart.stats != null:
			kart.stats = stats(kart.stats, classe, kart.get_node_or_null("AIInput") != null)
