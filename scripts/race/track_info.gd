class_name TrackInfo
extends Resource

## Fiche d'un circuit, telle que le menu la présente. Le circuit lui-même reste
## une scène : cette fiche dit seulement comment l'appeler et où le trouver.
##
## Le chemin de la scène, et non la scène : la fiche la chargeait avec elle,
## si bien que lire le catalogue chargeait tous les circuits dès le menu. Le
## circuit se charge maintenant quand on le court, derrière l'écran de
## chargement (EcranChargement), dans un fil à part.

## Identifiant stable, qui sert de clé aux records. Ne le change jamais sur un
## circuit publié : les records enregistrés sous l'ancien nom seraient perdus.
@export var id: String = ""
@export var nom: String = ""
@export_multiline var description: String = ""
@export_file("*.tscn") var chemin_scene: String = ""

## La scène du circuit, chargée à la première demande (puis gardée en cache
## par Godot).
var scene: PackedScene:
	get:
		if chemin_scene == "":
			return null
		return load(chemin_scene) as PackedScene
@export_range(1, 9) var tours: int = 3
