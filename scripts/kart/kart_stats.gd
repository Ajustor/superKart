class_name KartStats
extends Resource

## Tous les réglages de pilotage. Éditable moteur tournant :
## c'est le fichier qu'on triture pendant les sessions de réglage.

@export_group("Vitesse")
@export var max_speed: float = 22.0
@export var acceleration: float = 14.0
@export var brake_force: float = 26.0
@export var coast_friction: float = 6.0

@export_group("Braquage")
## Mesuré à pleine vitesse, plein braquage : 1,8 rad/s donne un rayon de
## 12,3 m, contre 9,3 m à 2,4. Baissé après une session de conduite — le kart
## tournait trop sec. L'épingle du circuit 1 a un rayon d'axe de 13,3 m : elle
## reste franchissable pied au plancher, mais de justesse.
@export var turn_rate: float = 1.8              ## rad/s à pleine vitesse

@export_group("Dérapage — tenue de route")
@export var min_drift_speed: float = 8.0
## La glisse façon Mario Kart 8 : trois régimes au stick, et le kart glisse
## de l'un à l'autre en douceur.
## - vers l'intérieur : le virage le plus serré (drift_turn_rate) ;
## - au neutre : à peu près le braquage à fond en adhérence ;
## - vers l'extérieur : une grande courbe, presque une ligne de vitesse.
##
## Joué en main : l'ancienne glisse tournait à 2,2 rad/s même au neutre (10 m
## de rayon contre 12,2 en adhérence) et le contre-braquage ne l'ouvrait qu'à
## 12 m — trop sec, et le stick ne changeait presque rien.
@export var drift_turn_rate: float = 2.3        ## rad/s, stick vers l'intérieur

## Part de drift_turn_rate au neutre et au contre-braquage maximal. À 22 m/s :
## 9,6 m vers l'intérieur, 12,3 m au neutre, 27 m vers l'extérieur.
@export var drift_rapport_neutre: float = 0.78
@export var drift_rapport_exterieur: float = 0.35

## Vitesse à laquelle la glisse suit le stick, en plages par seconde : passer
## de l'extérieur à l'intérieur prend 0,4 s. Sans ça, un stick qui tremble
## faisait zigzaguer la glisse.
@export var drift_modulation_vitesse: float = 5.0

## Durée de l'entrée en glisse, en secondes : la courbure y monte de
## drift_entree_debut à sa pleine valeur. Sans elle, la trajectoire tournait
## d'emblée à pleine vitesse ; ajoutée à l'angle de caisse, le kart semblait
## pivoter d'un quart de tour dès l'atterrissage du bond. Le rayon une fois
## la glisse installée, lui, ne change pas.
@export var drift_entree: float = 0.35
@export var drift_entree_debut: float = 0.45

## Durée du bond d'entrée en dérapage. La glisse commence à l'atterrissage.
@export var hop_duration: float = 0.20

## Hauteur du bond. Mesuré : avec la gravité ordinaire, le bond de 0,20 s
## montait à 12,5 cm — invisible derrière le kart, on croyait qu'il ne sautait
## pas. Le bond a donc sa propre gravité, plus forte : il monte franchement et
## retombe quand même pile au bout de hop_duration.
@export var hop_height: float = 0.35

## La charge du mini-turbo monte plus vite quand on serre le virage : braquer
## vers l'intérieur la fait monter à plein régime (1), contre-braquer au
## ralenti. C'est le cœur du dérapage de Mario Kart : la glisse serrée est
## plus difficile à tenir, elle rapporte plus vite.
@export var charge_au_contre_braquage: float = 0.55

@export_group("Dérapage — apparence")
## Ces trois-là ne touchent que l'angle affiché de la caisse, pas la
## trajectoire : c'est drift_turn_rate qui pilote le virage.
## Mesuré en jeu : à 30-55°, atteints en 0,2 s, la caisse se mettait en
## travers d'un coup et, avec la trajectoire qui tourne, le kart semblait
## partir à 90°. Comme dans Mario Kart, la caisse est d'autant plus en
## travers qu'on serre : 12° en contre-braquant, 30° en serrant à fond.
@export var drift_angle_min_deg: float = 12.0
@export var drift_angle_max_deg: float = 30.0
@export var drift_angle_rate_deg: float = 90.0 ## convergence de l'angle, deg/s

@export_group("Mini-turbo")
@export var drift_tiers: PackedFloat32Array = PackedFloat32Array([0.6, 1.5, 2.6])
@export var boost_durations: PackedFloat32Array = PackedFloat32Array([0.5, 1.0, 1.8])

## Un multiplicateur par palier, et non un seul pour les trois. Mesuré avant :
## les trois turbos poussaient tous à 29,70 m/s et seule la durée changeait,
## si bien qu'un palier 3 se sentait comme un palier 1 qui dure. Un palier plus
## haut doit pousser plus fort — c'est ce qui fait qu'on tient la glisse une
## seconde de plus au lieu de lâcher dès le premier éclair.
@export var boost_speed_multipliers: PackedFloat32Array = PackedFloat32Array([1.22, 1.33, 1.48])
@export var boost_decay_rate: float = 12.0      ## retour au plafond, u/s²

@export_group("Pénalités")
@export var offroad_speed_multiplier: float = 0.6
@export var stun_duration: float = 1.2

## Tours complets que fait la caisse pendant le tête-à-queue. Un seul : assez
## pour que la sanction se voie, pas assez pour qu'on perde le nord.
@export var stun_spin_turns: float = 1.0

## Freinage pendant le tête-à-queue, en u/s². Plus doux que le frein : le kart
## glisse encore un peu, il ne se plante pas sur place.
@export var stun_deceleration: float = 20.0

## Part de la vitesse perdue contre un mur pris de face. De biais, la perte
## suit l'angle : un mur frôlé ne coûte presque rien.
@export var wall_speed_loss: float = 0.7
## Masse relative, pour les chocs entre karts : le plus lourd pousse, le plus
## léger est poussé (voir ModeleKart).
@export var poids: float = 1.0

@export_group("Objets")
## Le champignon pousse comme un mini-turbo de palier 2, mais plus longtemps :
## c'est un objet qu'on a eu de la chance de tirer, il doit se sentir.
@export var mushroom_duration: float = 1.3
@export var mushroom_speed_multiplier: float = 1.4

@export_group("Saut")
@export var gravity: float = 30.0

## Multiplie l'impulsion des tremplins. Les cylindrées (Cylindree) le règlent
## avec la gravité pour que chaque saut garde la même trajectoire à toutes
## les vitesses : sinon, en 50cc, on tombait dans les trous.
@export var echelle_des_tremplins: float = 1.0

## Impulsion et gravité du bond, calées pour qu'il monte à hop_height et
## retombe au bout de hop_duration : l'atterrissage coïncide avec le début de
## la glisse. Dérivées plutôt qu'exportées : régler l'une sans l'autre
## recréerait un kart qui retombe en pleine glisse.
var hop_impulse: float:
	get: return 4.0 * hop_height / hop_duration

var hop_gravity: float:
	get: return 8.0 * hop_height / (hop_duration * hop_duration)

@export_group("Marche arrière")
@export var max_reverse_speed: float = 7.0
@export var reverse_acceleration: float = 9.0
