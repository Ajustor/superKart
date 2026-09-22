class_name TrackCatalog
extends RefCounted

## Les circuits proposés au menu, dans l'ordre où il les affiche. Ajouter un
## circuit, c'est écrire sa fiche et l'ajouter ici — rien d'autre.

const PISTES: Array[TrackInfo] = [
	preload("res://resources/tracks/track_01_info.tres"),
]


static func par_id(id: String) -> TrackInfo:
	for piste in PISTES:
		if piste.id == id:
			return piste
	return null
