class_name TrackCatalog
extends RefCounted

## Les circuits proposés au menu, dans l'ordre où il les affiche. Ajouter un
## circuit, c'est écrire sa fiche et l'ajouter ici — rien d'autre.

const PISTES: Array[TrackInfo] = [
	preload("res://resources/tracks/track_01_info.tres"),
	preload("res://resources/tracks/jardin_champignon_info.tres"),
	preload("res://resources/tracks/plage_palmiers_info.tres"),
	preload("res://resources/tracks/mine_scintillante_info.tres"),
	preload("res://resources/tracks/forteresse_lave_info.tres"),
	preload("res://resources/tracks/ville_neon_info.tres"),
	preload("res://resources/tracks/station_neiges_info.tres"),
	preload("res://resources/tracks/ruban_celeste_info.tres"),
]

## Les arènes du mode bataille : des anneaux larges et fermés, où l'on ne
## fait pas la course. Hors de PISTES : elles n'ont rien à faire au menu des
## courses ni dans les coupes.
const ARENES: Array[TrackInfo] = [
	preload("res://resources/tracks/arene_ovale_info.tres"),
]

## Les coupes du Grand Prix : quatre circuits chacune, du plus doux au plus
## redoutable. Le menu les affiche dans cet ordre ; leur index sert de clé
## aux trophées, ne les réordonne pas.
const COUPES := [
	{
		nom = "Coupe Champignon",
		couleur = Color(0.95, 0.3, 0.25),
		pistes = ["circuit_01", "jardin_champignon", "plage_palmiers", "mine_scintillante"],
	},
	{
		nom = "Coupe Étoile",
		couleur = Color(1.0, 0.8, 0.2),
		pistes = ["forteresse_lave", "ville_neon", "station_neiges", "ruban_celeste"],
	},
]


static func par_id(id: String) -> TrackInfo:
	for piste in PISTES + ARENES:
		if piste.id == id:
			return piste
	return null
