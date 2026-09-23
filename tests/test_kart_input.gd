extends GutTest

## Une source qui n'écrit qu'un seul champ, pour prouver que la classe de base
## remet bien les autres à neuf. C'est toute la raison d'être de poll() : une
## sous-classe qui oublie un champ ne doit pas hériter de la frame précédente.
class SourcePartielle extends KartInput:
	var valeur: float = 0.0

	func _fill(_delta: float) -> void:
		command.steer = valeur


func test_un_champ_non_ecrit_ne_garde_pas_la_valeur_precedente() -> void:
	var source := SourcePartielle.new()
	source.valeur = 1.0

	# Comme si une frame précédente avait laissé ces valeurs en place.
	source.command.throttle = 0.8
	source.command.brake = 0.4
	source.command.drift = true
	source.command.use_item = true

	var cmd := source.poll(1.0 / 60.0)

	assert_eq(cmd.steer, 1.0, "le champ que la sous-classe écrit passe bien")
	assert_eq(cmd.throttle, 0.0, "un champ non écrit revient à neuf")
	assert_eq(cmd.brake, 0.0)
	assert_false(cmd.drift, "y compris les booléens")
	assert_false(cmd.use_item)
	source.free()


func test_poll_renvoie_toujours_la_meme_instance() -> void:
	var source := SourcePartielle.new()
	var premier := source.poll(1.0 / 60.0)
	var second := source.poll(1.0 / 60.0)
	assert_eq(premier, second,
		"la commande est réutilisée d'une frame à l'autre : aucune allocation dans la boucle")
	source.free()


# --- Appuis brefs ------------------------------------------------------------------

func _joueur() -> PlayerInput:
	var p := PlayerInput.new()
	add_child_autofree(p)
	return p


## Sur un téléphone qui rame, un tap commence et finit entre deux pas de
## physique : au moment de lire, le bouton est déjà relâché.
func test_un_tap_tactile_entre_deux_pas_n_est_pas_perdu() -> void:
	var p := _joueur()
	Input.action_press(&"use_item")
	PlayerInput.noter_appui(&"use_item")
	Input.action_release(&"use_item")
	assert_true(p.poll(1.0 / 60.0).use_item, "l'objet part quand même")
	assert_false(p.poll(1.0 / 60.0).use_item, "et une seule fois")


func test_un_appui_clavier_bref_est_retenu() -> void:
	var p := _joueur()
	var appui := InputEventAction.new()
	appui.action = &"drift"
	appui.pressed = true
	p._input(appui)
	assert_true(p.poll(1.0 / 60.0).drift, "le saut de dérapage part")
	assert_false(p.poll(1.0 / 60.0).drift, "puis rien : le bouton n'est plus tenu")


func test_un_appui_fait_au_menu_ne_lance_rien_au_depart() -> void:
	PlayerInput.noter_appui(&"use_item")
	var p := _joueur()
	assert_false(p.poll(1.0 / 60.0).use_item)


func test_seuls_les_appuis_brefs_sont_retenus() -> void:
	var p := _joueur()
	PlayerInput.noter_appui(&"throttle")
	assert_eq(p.poll(1.0 / 60.0).throttle, 0.0, "les gaz se tiennent, ils ne se tapent pas")
