extends GutTest

## Kart n'a pas besoin de l'arbre de scènes pour ce qui est testé ici :
## respawn_at ne touche à aucun nœud enfant, ne fait pas de get_node et
## n'appelle pas move_and_slide.


func _kart_hors_arbre() -> Kart:
	var kart := Kart.new()
	kart.stats = KartStats.new()
	kart.motor = KartMotor.new(kart.stats)
	return kart


func test_respawn_ne_remplace_pas_le_moteur() -> void:
	var kart := _kart_hors_arbre()
	var avant := kart.motor

	kart.respawn_at(Transform3D())

	assert_eq(kart.motor, avant,
		"la caméra et les visuels gardent une référence au moteur : le remplacer les détacherait en silence")
	kart.free()


func test_respawn_remet_le_moteur_a_neuf() -> void:
	var kart := _kart_hors_arbre()
	kart.motor.speed = 18.0
	kart.motor.boost_timer = 1.0
	kart.motor.on_offroad = true

	kart.respawn_at(Transform3D())

	assert_eq(kart.motor.speed, 0.0)
	assert_eq(kart.motor.boost_timer, 0.0)
	assert_false(kart.motor.on_offroad)
	kart.free()


func test_respawn_oriente_le_kart_dans_le_sens_demande() -> void:
	var kart := _kart_hors_arbre()
	# Un quart de tour au sens de Godot, donc vers la droite.
	var cible := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(5, 1, -3))

	kart.respawn_at(cible)

	assert_almost_eq(kart.motor.heading, PI * 0.5, 0.001,
		"le moteur compte à la boussole : ce quart de tour Godot vaut +90° pour lui")
	assert_almost_eq(kart.position.x, 5.0, 0.001)
	kart.free()
