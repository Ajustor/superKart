class_name KartSpring
extends RefCounted

## Un amortisseur de roue : un ressort, un frottement, une butée.
##
## Comme KartMotor, cette classe ne connaît ni la scène ni les nœuds : on lui
## donne la distance au sol et un pas de temps, elle rend une longueur. C'est
## ce qui permet de tester le rebond, l'amortissement et les butées sans lancer
## le moteur de rendu ni poser une seule roue.
##
## Elle ne décide de rien d'autre que d'une longueur. Le kart avance comme
## avant : la suspension raconte le relief, elle ne le pilote pas.

## Longueur au repos, roue pendante, en mètres.
var rest_length: float

## Débattement total, en mètres. La roue ne peut pas remonter plus haut que
## `rest_length - travel` : au-delà, le pneu touche le châssis.
var travel: float

## Raideur du ressort, en 1/s². Plus c'est haut, plus la caisse résiste.
var stiffness: float

## Frottement de l'amortisseur, en 1/s. Sans lui le kart rebondirait sans fin,
## ce qui est très exactement le défaut d'une suspension sans amortisseur.
var damping: float

## Longueur courante, entre `rest_length - travel` et `rest_length`.
var length: float

## Vitesse de la roue dans son fourreau, en m/s. Positive quand elle se détend.
var velocity: float = 0.0

## Vrai quand le rayon a touché quelque chose à cette image.
var grounded: bool = false


func _init(longueur_repos: float, debattement: float, raideur: float,
		frottement: float) -> void:
	rest_length = longueur_repos
	travel = debattement
	stiffness = raideur
	damping = frottement
	length = longueur_repos


## Longueur la plus courte atteignable : au-delà, le pneu touche le châssis.
func min_length() -> float:
	return maxf(rest_length - travel, 0.0)


## Tassement, de 0 (roue pendante) à 1 (butée). C'est ce que lit l'affichage.
func compression() -> float:
	if travel <= 0.0001:
		return 0.0
	return clampf((rest_length - length) / travel, 0.0, 1.0)


## Avance d'un pas. `distance_au_sol` est mesurée depuis l'ancrage, le long du
## fourreau ; passer INF veut dire que la roue ne touche rien.
##
## La roue vise le sol quand elle le touche et sa pleine extension sinon, et
## elle y va comme une masse au bout d'un ressort — pas d'un coup. C'est cette
## inertie qui donne le tassement en sortie de bosse et la détente en saut.
func step(distance_au_sol: float, delta: float) -> void:
	grounded = distance_au_sol < rest_length
	var vise := rest_length
	if grounded:
		vise = clampf(distance_au_sol, min_length(), rest_length)

	var acceleration := stiffness * (vise - length) - damping * velocity
	velocity += acceleration * delta
	length += velocity * delta

	# Les butées ne renvoient rien : une suspension qui rebondit sur sa butée
	# ferait sauter le kart à chaque compression complète.
	if length <= min_length():
		length = min_length()
		velocity = maxf(velocity, 0.0)
	elif length >= rest_length:
		length = rest_length
		velocity = minf(velocity, 0.0)


## Remet l'amortisseur détendu et immobile. Sert aux remises en piste : une
## roue qui garde sa vitesse au moment où le kart est téléporté fait tressauter
## la caisse à l'arrivée.
func reset() -> void:
	length = rest_length
	velocity = 0.0
	grounded = false
