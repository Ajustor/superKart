class_name AIInput
extends KartInput

## Pilote automatique. Elle vise un point de la ligne de course situé à une
## demi-seconde de trajet devant elle, mesure l'écart entre son cap et la
## direction de ce point, et en tire un braquage.
##
## Elle passe par le même KartCommand que le joueur, donc elle est enfermée
## dans la même physique : elle ne peut pas prendre un virage que le joueur ne
## pourrait pas prendre, et elle dérape pour de vrai, avec les mêmes étincelles.
##
## Tous les angles sont des caps boussole — positif vers la droite — comme dans
## KartMotor et TrackCurve. Aucune rotation Godot n'apparaît ici.

## Durée de trajet qui sépare le kart de son point de mire. Plus elle est
## grande, plus l'IA anticipe et plus ses trajectoires sont propres.
@export var aim_time: float = 0.45

## Distance de mire minimale, en mètres. Sans elle, un kart à l'arrêt viserait
## ses propres roues et ne démarrerait jamais.
@export var aim_minimum: float = 6.0

## Écart de cap, en degrés, au-delà duquel l'IA braque à fond.
@export var full_steer_angle_deg: float = 20.0

## Rayon du virage visé, en mètres, en deçà duquel l'IA engage le dérapage.
##
## Sur la sévérité du virage, et non sur son propre écart de cap. Mesuré :
## avec l'ancienne règle, l'écart de cap de l'IA culminait à 16,2° dans
## l'épingle contre un seuil de 32°, donc elle ne dérapait jamais — et plus
## elle suivait bien sa ligne, moins elle dérapait, ce qui est exactement
## l'inverse de ce qu'on veut. Un joueur dérape parce qu'il voit arriver le
## virage, pas parce qu'il a déjà raté sa trajectoire.
@export var drift_entry_radius: float = 22.0

## Rayon au-delà duquel elle lâche une glisse en cours. Plus large que
## l'entrée, pour ne pas battre de l'aile à la frontière du virage.
##
## Balayé sur track_01, trois tours à chaque fois : 34 m donne 0,42 s de charge
## et 6,77 m d'écart, 42 m donne 0,50 s et 7,40 m, 50 m donne 0,55 s et 8,00 m,
## 60 m atteint enfin le palier 1 mais à 9,21 m — hors d'une piste qui en fait
## 9,00. On garde la glisse la plus longue qui reste sur le bitume.
@export var drift_exit_radius: float = 42.0

## Palier de mini-turbo visé avant de lâcher, de 1 à 3. Une IA gourmande tient
## la glisse plus longtemps et sort plus vite — c'est un des quatre leviers de
## difficulté, et le seul qui se voie à l'œil nu.
@export var drift_release_tier: int = 2

## Décalage constant par rapport à la ligne idéale, en mètres vers la droite.
## Une IA qui vise systématiquement à côté pilote mal sans jamais être bridée.
@export var lateral_bias: float = 0.0

## Intervalle entre deux décisions, en secondes. Zéro veut dire une décision
## par image. Au-delà, l'IA tient sa commande précédente : elle braque en
## retard plutôt que mollement, ce qui est la façon dont un humain rate un
## virage.
@export var reaction_delay: float = 0.0

## Contre-braquage maximal que l'IA s'autorise pendant une glisse, en part
## d'inversion. Le moteur casse la glisse au-delà de -0,8 : mesuré sur
## track_01, l'épingle fait 18 m de rayon quand le dérapage en décrit 8,5 à
## 11, donc l'IA sur-tournait, contre-braquait à fond et cassait sa propre
## glisse en six images — jamais un seul mini-turbo encaissé. Un pilote
## contre-braque dans la glisse, pas assez fort pour la perdre.
##
## Ramené de -0,7 à -0,4 quand le contre-braquage a ouvert la glisse presque en
## ligne droite (KartStats.drift_rapport_exterieur) : -0,4 donne aujourd'hui
## la courbe que -0,7 donnait avant, et l'IA, réglée sur celle-là, ne se
## mettait plus à zigzaguer dans ses glisses.
const CONTRE_BRAQUAGE_MAX := -0.4

## Renseignés par la session avant chaque image. Les lire soi-même coûterait
## une projection de plus par kart, et global_position interdirait de tester
## cette classe hors de l'arbre.
var track: TrackCurve
var distance: float = 0.0
var position := Vector3.ZERO

## Renseignés par ItemManager : l'objet prêt dans l'emplacement (NONE sinon),
## si l'IA mène la course, et l'avance qu'elle a sur son poursuivant, en mètres.
var objet_pret: int = ItemKind.NONE
var en_tete: bool = false
var ecart_poursuivant: float = INF
## L'objet est tenu derrière le kart (voir ItemManager).
var objet_tenu: bool = false
var _tenu_depuis: float = 0.0

## Écart, en mètres, sous lequel une IA en tête lâche la banane qu'elle garde
## en protection : le poursuivant est assez près pour rouler dessus.
const ALERTE_POURSUIVANT := 12.0

var _depuis_decision: float = 0.0
var _steer_decide: float = 0.0
var _drift_decide: bool = false
var _jamais_decide: bool = true


## Distance de mire le long de l'axe : là où l'IA regarde.
func distance_visee() -> float:
	return distance + maxf(kart.motor.speed * aim_time, aim_minimum)


## Le point de mire, sur la ligne de course, devant le kart. Le biais latéral
## s'applique à ce point et non à la distance : viser à côté ne veut pas dire
## viser plus loin.
func point_vise() -> Vector3:
	var ou := distance_visee()
	return track.racing_line_at(ou) + track.right_at(ou) * lateral_bias


func _fill(delta: float) -> void:
	_depuis_decision += delta
	if _jamais_decide or _depuis_decision >= reaction_delay:
		_jamais_decide = false
		_depuis_decision = 0.0
		_steer_decide = _braquage()
		_drift_decide = _veut_deraper()

	command.throttle = 1.0
	_objet(delta)
	command.drift = _drift_decide
	command.steer = _brider_pour_tenir_la_glisse(_steer_decide)


## En tête, une banane ou une carapace verte reste derrière le kart, en
## bouclier ; elle part vers l'arrière quand un poursuivant approche. Le reste
## part dès que c'est prêt.
func _objet(delta: float) -> void:
	if objet_tenu:
		_tenu_depuis += delta
		# Tenu au moins le temps d'un vrai maintien : relâché trop tôt, le
		# lâcher compterait pour un appui bref, et la verte partirait devant.
		command.item_held = veut_garder_derriere() or _tenu_depuis < ItemManager.SEUIL_TAPE + 0.05
		command.throw_back = true
		return
	_tenu_depuis = 0.0
	if veut_garder_derriere():
		command.use_item = true
		command.item_held = true
	elif veut_utiliser_objet():
		command.use_item = true


func veut_garder_derriere() -> bool:
	return en_tete and ecart_poursuivant >= ALERTE_POURSUIVANT \
		and objet_pret in [ItemKind.BANANA, ItemKind.FAKE_BOX, ItemKind.GREEN_SHELL]


## La politique d'objets de la spec, volontairement simple : utiliser dès que
## c'est prêt, sauf garder une banane en protection quand on est en tête, et la
## lâcher quand un poursuivant approche.
func veut_utiliser_objet() -> bool:
	if objet_pret == ItemKind.NONE:
		return false
	if (objet_pret == ItemKind.BANANA or objet_pret == ItemKind.FAKE_BOX) and en_tete:
		return ecart_poursuivant < ALERTE_POURSUIVANT
	return true


## Écart de cap entre la direction du kart et celle du point de mire, en
## radians, ramené dans [-PI, PI]. Positif = la cible est à droite.
func ecart_de_cap() -> float:
	var vers := point_vise() - position
	vers.y = 0.0
	if vers.length_squared() < 0.0001:
		return 0.0
	var cap_voulu := atan2(vers.x, -vers.z)
	return wrapf(cap_voulu - kart.motor.heading, -PI, PI)


func _braquage() -> float:
	var plein := deg_to_rad(full_steer_angle_deg)
	return clampf(ecart_de_cap() / plein, -1.0, 1.0)


## Rabote le contre-braquage tant qu'on veut garder la glisse. Appliqué après
## la décision et non dedans : quand l'IA veut sortir, elle contre-braque
## librement, et c'est justement ce qui la fait sortir vite.
func _brider_pour_tenir_la_glisse(braquage: float) -> float:
	if not _drift_decide or kart.motor.state != KartMotor.State.DRIFT:
		return braquage
	var sens := float(kart.motor.drift_dir)
	if sens == 0.0:
		return braquage
	return maxf(braquage * sens, CONTRE_BRAQUAGE_MAX) * sens


## Distance à laquelle on juge la sévérité du virage. Bien plus courte que la
## mire du braquage, et pour une raison mesurée : à 0,45 s d'anticipation,
## l'IA visait déjà 10 m après l'apex quand ses roues entraient dans l'épingle.
## Elle engageait donc la glisse à 399 m sur un rayon vu de 17,8 m, et la
## relâchait à 411 m parce que sa mire lisait 35,9 m — six images de glisse,
## pile au moment où il aurait fallu la tenir.
##
## Le braquage doit regarder loin, la glisse doit regarder où l'on est. Seule
## l'entrée anticipe, d'une longueur de saut : le temps de décoller, et la
## glisse commence quand le virage commence.
func _distance_de_decision() -> float:
	if kart.motor.state == KartMotor.State.GRIP:
		return distance + kart.motor.speed * kart.stats.hop_duration
	return distance


## Le dérapage se décide comme le joueur appuie : un booléen, rien de plus.
## Le moteur reste seul juge de ce qu'il en fait — c'est lui qui exige un
## braquage suffisant à l'entrée et qui verrouille le sens de la glisse.
func _veut_deraper() -> bool:
	if kart.motor.speed < kart.stats.min_drift_speed:
		return false

	var rayon := track.radius_at(_distance_de_decision())

	# Le saut fait partie de l'engagement : un joueur garde la gâchette
	# enfoncée pendant qu'il décolle. En repassant par le seuil d'entrée,
	# étroit, l'IA le ratait d'une image et retombait en adhérence — trois
	# sauts par tour, pas une seule glisse.
	if kart.motor.state == KartMotor.State.HOP:
		return rayon < drift_exit_radius

	if kart.motor.state == KartMotor.State.DRIFT:
		# Une glisse tenue en ligne droite finit dans le décor, et une glisse
		# lâchée trop tôt ne rapporte rien : on sort au premier des deux.
		var palier := kart.motor.tier_for_charge(kart.motor.drift_charge)
		return palier < drift_release_tier and rayon < drift_exit_radius

	return rayon < drift_entry_radius
