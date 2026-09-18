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
