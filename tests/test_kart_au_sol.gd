extends GutTest

## Ni roue ni caisse ne passent sous la route : la roue délestée, la caisse
## qui tangue et s'incline en glisse, le tonneau d'une figure qui touche le
## sol. Un vrai kart, habillé, sur une dalle plate dont le dessus est y = 0.

## La tolérance : 5 mm sous le sol, pas plus.
const TOLERANCE := 0.005

var kart: Kart
var temoin: Temoin


class Pilote:
	extends KartInput

	var gaz := 1.0
	var volant := 0.0

	func _fill(_delta: float) -> void:
		command.throttle = gaz
		command.steer = volant


## Enfant du kart, il passe après lui et ses visuels à chaque image : il
## relève le point le plus bas des jantes et de la caisse dessinée.
class Temoin:
	extends Node

	var jantes := INF
	var caisse := INF

	func _process(_delta: float) -> void:
		var k := get_parent() as Kart
		# Une roue est ronde : la boîte d'une jante qui tourne descend sous
		# elle, jusqu'à r(√2 - 1) au quart de tour. Son point le plus bas est
		# son centre moins son rayon, en travers de son axe.
		var rayon := k.suspension.wheel_radius
		for roue in k.get_node("Wheels").get_children():
			var r3 := roue as Node3D
			if not (r3.get_node("Jante") as Node3D).is_visible_in_tree():
				continue
			var axe := r3.global_basis.x.normalized()
			jantes = minf(jantes, r3.global_position.y - rayon * sqrt(maxf(1.0 - axe.y * axe.y, 0.0)))
		caisse = minf(caisse, Temoin.le_plus_bas(k.get_node("Body/Kenney")))

	## Le point le plus bas des maillages visibles de `noeud`.
	static func le_plus_bas(noeud: Node) -> float:
		var y := INF
		for m in noeud.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if not mi.is_visible_in_tree() or mi.mesh == null:
				continue
			var boite := mi.get_aabb()
			for i in 8:
				y = minf(y, (mi.global_transform * boite.get_endpoint(i)).y)
		return y


func _dalle() -> void:
	var sol := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(600, 1, 600)
	forme.shape = boite
	forme.position.y = -0.5
	sol.add_child(forme)
	add_child_autofree(sol)


## Un kart habillé sur ces roues, posé et immobile, puis le témoin.
func _kart(roues: int = ModeleKart.ROUES_STANDARD) -> Pilote:
	_dalle()
	kart = (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate() as Kart
	ModeleKart.habiller(kart, ModeleKart.STANDARD, ModeleKart.couleur(0), roues)
	add_child_autofree(kart)
	var pilote := Pilote.new()
	pilote.gaz = 0.0
	kart.changer_pilote(pilote)
	kart.respawn_at(Transform3D(Basis(), Vector3(0, 0.05, 0)))
	await wait_seconds(0.6)
	temoin = Temoin.new()
	kart.add_child(temoin)
	return pilote


func test_une_roue_delestee_ne_passe_pas_sous_le_sol() -> void:
	var pilote := await _kart()
	kart.motor.speed = 20.0
	pilote.gaz = 1.0
	pilote.volant = 1.0
	await wait_seconds(1.0)
	assert_gt(temoin.jantes, -TOLERANCE, "jante à %.3f m sous le sol" % -temoin.jantes)


## Glisse à fond d'un côté, nez plongé au freinage, sur ces roues.
func _glisse(sens: int, roues: int) -> void:
	await _kart(roues)
	var suspension := kart.suspension
	var visuels := kart.get_node("Visuals") as KartVisuals
	for i in 40:
		kart.motor.state = KartMotor.State.DRIFT
		kart.motor.drift_dir = sens
		# Le nez plonge au freinage : l'avant en butée, l'arrière détendu.
		for r in 4:
			var ressort: KartSpring = suspension._springs[r]
			ressort.length = ressort.min_length() if r < 2 else ressort.rest_length
		suspension._asseoir_la_caisse()
		visuels._process(1.0 / 60.0)
		temoin._process(0.0)
	await wait_process_frames(1)


func test_la_caisse_ne_passe_pas_sous_le_sol_en_glisse() -> void:
	for roues in [ModeleKart.ROUES_STANDARD, ModeleKart.LEGERES]:
		for sens in [-1, 1]:
			await _glisse(sens, roues)
			assert_gt(temoin.caisse, -TOLERANCE, "caisse à %.3f m sous le sol (roues %d, sens %d)"
				% [-temoin.caisse, roues, sens])
			kart.queue_free()
			await wait_process_frames(2)


func test_une_figure_au_sol_reste_au_dessus_du_sol() -> void:
	await _kart()
	kart.figure.emit()
	await wait_seconds(KartVisuals.DUREE_FIGURE + 0.1)
	assert_gt(temoin.caisse, -TOLERANCE, "caisse à %.3f m sous le sol" % -temoin.caisse)
	assert_gt(temoin.jantes, -TOLERANCE, "jante à %.3f m sous le sol" % -temoin.jantes)


func test_au_repos_rien_ne_bouge() -> void:
	# Mesuré avant le correctif : les roues touchent le sol, la caisse Kenney
	# passe 5 cm au-dessus (1,8 mm sur les roues Légères).
	for cas in [[ModeleKart.ROUES_STANDARD, 0.0498], [ModeleKart.LEGERES, 0.0018]]:
		await _kart(cas[0])
		await wait_seconds(0.3)
		assert_almost_eq(temoin.jantes, 0.0, TOLERANCE, "les roues touchent le sol")
		assert_almost_eq(temoin.caisse, cas[1], TOLERANCE, "la caisse à sa hauteur d'aujourd'hui")
		kart.queue_free()
		await wait_process_frames(2)
