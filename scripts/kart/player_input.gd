class_name PlayerInput
extends KartInput

## Lit le clavier, la manette et les commandes tactiles. Aucune allocation :
## on réutilise l'instance de KartCommand héritée de KartInput.
##
## Un appui bref ne se perd jamais. La physique ne lit les commandes qu'à
## chacun de ses pas ; sur un téléphone qui rame, un tap sur OBJET ou DRIFT
## peut commencer et finir entre deux pas, et is_action_just_pressed ne le
## voit alors pas du tout. Chaque appui est donc noté au moment où il arrive,
## et consommé au pas suivant.

## Les actions qui se jouent d'un tap : un appui compte, même relâché aussitôt.
const APPUIS_BREFS: Array[StringName] = [&"use_item", &"drift"]

## Appuis arrivés depuis le dernier pas de physique. Partagé : il n'y a qu'un
## joueur par machine, et les commandes tactiles le nourrissent sans avoir à
## trouver son kart.
static var _appuis: Dictionary = {}


## Les commandes tactiles appuient par Input.action_press, qui ne fait passer
## aucun événement par _input : elles préviennent ici.
static func noter_appui(action: StringName) -> void:
	if action in APPUIS_BREFS:
		_appuis[action] = true


func _ready() -> void:
	# Un appui fait dans le menu ne doit pas lancer un objet au départ.
	_appuis.clear()


func _input(event: InputEvent) -> void:
	for action in APPUIS_BREFS:
		if event.is_action_pressed(action):
			_appuis[action] = true


func _fill(_delta: float) -> void:
	command.steer = Input.get_axis(&"steer_left", &"steer_right")
	command.throttle = Input.get_action_strength(&"throttle")
	command.brake = Input.get_action_strength(&"brake")
	command.drift = Input.is_action_pressed(&"drift") or _appuis.has(&"drift")
	# Pas de is_action_just_pressed : il reste vrai tout le reste de l'image,
	# et deux pas de physique dans la même image lanceraient deux objets.
	command.use_item = _appuis.has(&"use_item")
	_appuis.clear()
