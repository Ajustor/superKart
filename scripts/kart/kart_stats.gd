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
## Mesuré : à 2,1 rad/s, une glisse au braquage neutre décrivait un rayon de
## 14,0 m contre 12,2 m en adhérence — s'engager dans le dérapage élargissait
## la trajectoire au lieu de la resserrer, et il fallait tenir le braquage
## presque à fond pour y gagner quoi que ce soit. Monté à 2,6 pour que toute
## la plage de glisse tienne à l'intérieur du rayon d'adhérence, comme dans
## un Mario Kart où la glisse est la trajectoire rapide et la modulation un
## réglage fin, pas une condition.
@export var drift_turn_rate: float = 2.6        ## rad/s pendant la glisse

## Part de drift_turn_rate qui reste au contre-braquage maximal. C'est le
## plancher de la plage de modulation : à 0,68 le contre-braquage ouvre à
## 11,9 m, encore en deçà des 12,2 m de l'adhérence. Le descendre rendrait la
## glisse à nouveau plus large que de ne rien faire.
@export var drift_curvature_min: float = 0.68

## Monté de 0,15 à 0,20 s : l'impulsion en découle, et le saut passait de 8 cm,
## invisible, à 15 cm. Le début de la glisse coïncide toujours avec
## l'atterrissage, puisque hop_impulse est dérivée de cette durée.
@export var hop_duration: float = 0.20

@export_group("Dérapage — apparence")
## Ces trois-là ne touchent que l'angle affiché de la caisse, pas la
## trajectoire : c'est drift_turn_rate qui pilote le virage.
@export var drift_angle_min_deg: float = 30.0
@export var drift_angle_max_deg: float = 55.0
@export var drift_angle_rate_deg: float = 220.0 ## convergence de l'angle, deg/s

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

@export_group("Saut")
@export var gravity: float = 30.0

## Calé pour que l'atterrissage coïncide avec le début de la glisse.
## Dérivé plutôt qu'exporté : régler hop_duration sans réajuster cette
## valeur à la main recréerait un kart qui retombe en pleine glisse.
var hop_impulse: float:
	get: return gravity * hop_duration / 2.0

@export_group("Marche arrière")
@export var max_reverse_speed: float = 7.0
@export var reverse_acceleration: float = 9.0
