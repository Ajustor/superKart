class_name RaceLauncher
extends RefCounted

## Monte une course à partir des choix du menu, puis la lance.
##
## La scène est modifiée AVANT d'entrer dans l'arbre : aucun _ready n'a encore
## tourné, donc on peut y remplacer le circuit et régler la session sans que
## rien n'ait eu le temps de lire l'ancien. Lancée seule depuis l'éditeur,
## race.tscn garde son circuit et ses valeurs par défaut.

const SCENE_COURSE := "res://scenes/race.tscn"
const SCENE_MENU := "res://scenes/ui/main_menu.tscn"


static func lancer(arbre: SceneTree, reglage: RaceSetup) -> void:
	arbre.paused = false
	arbre.change_scene_to_node(monter(reglage))


static func retour_au_menu(arbre: SceneTree) -> void:
	arbre.paused = false
	arbre.change_scene_to_file(SCENE_MENU)


## Rend la course prête à entrer dans l'arbre. Séparé de `lancer` pour pouvoir
## être testé sans changer de scène.
static func monter(reglage: RaceSetup, rng: RandomNumberGenerator = null) -> Node:
	var course := (load(SCENE_COURSE) as PackedScene).instantiate()

	if reglage.piste != null and reglage.piste.scene != null:
		var ancienne := course.get_node("Track")
		var nouvelle := reglage.piste.scene.instantiate()
		ancienne.replace_by(nouvelle)
		nouvelle.name = "Track"
		ancienne.free()

	var session := course.get_node("Session") as RaceSession
	session.lap_count = maxi(reglage.tours, 1)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	session.case_du_joueur = reglage.case_effective(session.kart_paths.size(), rng)
	session.id_piste = reglage.piste.id if reglage.piste != null else ""
	return course
