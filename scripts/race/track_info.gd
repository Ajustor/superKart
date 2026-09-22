class_name TrackInfo
extends Resource

## Fiche d'un circuit, telle que le menu la présente. Le circuit lui-même reste
## une scène : cette fiche dit seulement comment l'appeler et où le trouver.

## Identifiant stable, qui sert de clé aux records. Ne le change jamais sur un
## circuit publié : les records enregistrés sous l'ancien nom seraient perdus.
@export var id: String = ""
@export var nom: String = ""
@export_multiline var description: String = ""
@export var scene: PackedScene
@export_range(1, 9) var tours: int = 3
