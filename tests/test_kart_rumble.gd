extends GutTest

## La secousse elle-même a besoin d'une manette branchée, donc d'un humain.
## Ce qui se teste, c'est la décision : quelle force pour quel turbo. Elle est
## sortie en fonction pure exactement pour ça.

var stats: KartStats


func before_each() -> void:
	stats = KartStats.new()


func test_pas_de_turbo_pas_de_secousse() -> void:
	assert_almost_eq(KartRumble.force_de_turbo(1.0, stats.boost_speed_multipliers), 0.0, 0.001,
		"sans turbo, la manette doit rester muette")


func test_la_secousse_suit_le_palier() -> void:
	var table := stats.boost_speed_multipliers
	var forces: Array[float] = []
	for m in table:
		forces.append(KartRumble.force_de_turbo(m, table))

	for i in range(1, forces.size()):
		assert_gt(forces[i], forces[i - 1],
			"le palier %d doit secouer plus fort que le précédent" % (i + 1))


func test_le_palier_le_plus_haut_secoue_a_fond() -> void:
	var table := stats.boost_speed_multipliers
	assert_almost_eq(KartRumble.force_de_turbo(table[table.size() - 1], table), 1.0, 0.001,
		"le meilleur turbo doit valoir la secousse maximale")


func test_la_force_reste_dans_les_bornes() -> void:
	var table := stats.boost_speed_multipliers
	for m in [-5.0, 0.0, 1.0, 1.25, 99.0]:
		var f := KartRumble.force_de_turbo(m, table)
		assert_between(f, 0.0, 1.0, "force hors bornes pour un multiplicateur de %f" % m)


func test_une_table_vide_ne_plante_pas() -> void:
	assert_almost_eq(KartRumble.force_de_turbo(1.4, PackedFloat32Array()), 0.0, 0.001,
		"un kart sans table de turbo ne doit pas faire tomber la manette")


func test_une_table_sans_turbo_reel_ne_secoue_pas() -> void:
	# Des multiplicateurs à 1.0 ne poussent pas : diviser par zéro serait la
	# façon la plus bête de planter sur un réglage pourtant légitime.
	assert_almost_eq(KartRumble.force_de_turbo(1.0, PackedFloat32Array([1.0, 1.0])), 0.0, 0.001)
