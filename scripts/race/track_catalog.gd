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
	preload("res://resources/tracks/canyon_venteux_info.tres"),
	preload("res://resources/tracks/grotte_glacee_info.tres"),
	preload("res://resources/tracks/usine_engrenages_info.tres"),
	preload("res://resources/tracks/temple_jungle_info.tres"),
	preload("res://resources/tracks/base_lunaire_info.tres"),
	preload("res://resources/tracks/port_pirate_info.tres"),
	preload("res://resources/tracks/manoir_hante_info.tres"),
	preload("res://resources/tracks/citadelle_orages_info.tres"),
	preload("res://resources/tracks/coeur_terre_info.tres"),
	preload("res://resources/tracks/echelle_celeste_info.tres"),
	preload("res://resources/tracks/grand_huit_info.tres"),
	preload("res://resources/tracks/pic_lacets_info.tres"),
	preload("res://resources/tracks/saut_temporel_info.tres"),
	preload("res://resources/tracks/recif_bulles_info.tres"),
	preload("res://resources/tracks/lune_carnaval_info.tres"),
	preload("res://resources/tracks/terres_cubiques_info.tres"),
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
		nom = "Coupe Grand Air",
		couleur = Color(0.95, 0.3, 0.25),
		pistes = ["circuit_01", "jardin_champignon", "plage_palmiers", "mine_scintillante"],
	},
	{
		nom = "Coupe Bolide",
		couleur = Color(1.0, 0.8, 0.2),
		pistes = ["forteresse_lave", "ville_neon", "station_neiges", "ruban_celeste"],
	},
	{
		nom = "Coupe Aventure",
		couleur = Color(1.0, 0.55, 0.15),
		pistes = ["canyon_venteux", "grotte_glacee", "usine_engrenages", "temple_jungle"],
	},
	{
		nom = "Coupe Tempête",
		couleur = Color(0.55, 0.45, 1.0),
		pistes = ["base_lunaire", "port_pirate", "manoir_hante", "citadelle_orages"],
	},
	{
		nom = "Coupe Vertige",
		couleur = Color(0.3, 0.8, 0.9),
		pistes = ["grand_huit", "pic_lacets", "coeur_terre", "echelle_celeste"],
	},
	{
		nom = "Coupe Odyssée",
		couleur = Color(0.85, 0.35, 0.95),
		pistes = ["saut_temporel", "recif_bulles", "lune_carnaval", "terres_cubiques"],
	},
]


static func par_id(id: String) -> TrackInfo:
	for piste in PISTES + ARENES:
		if piste.id == id:
			return piste
	return null
