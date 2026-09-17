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
@export var turn_rate: float = 2.4              ## rad/s à pleine vitesse

@export_group("Dérapage — tenue de route")
@export var min_drift_speed: float = 8.0
@export var drift_turn_rate: float = 2.8        ## rad/s pendant la glisse
@export var hop_duration: float = 0.15

@export_group("Dérapage — apparence")
## Ces trois-là ne touchent que l'angle affiché de la caisse, pas la
## trajectoire : c'est drift_turn_rate qui pilote le virage.
@export var drift_angle_min_deg: float = 30.0
@export var drift_angle_max_deg: float = 55.0
@export var drift_angle_rate_deg: float = 220.0 ## convergence de l'angle, deg/s

@export_group("Mini-turbo")
@export var drift_tiers: PackedFloat32Array = PackedFloat32Array([0.6, 1.5, 2.6])
@export var boost_durations: PackedFloat32Array = PackedFloat32Array([0.5, 1.0, 1.8])
@export var boost_speed_multiplier: float = 1.35
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
