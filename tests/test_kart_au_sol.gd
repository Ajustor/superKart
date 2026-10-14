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
	## La dernière image : ce qui flotte se lit là, pas dans le minimum.
	var jantes_maintenant := INF
	var caisse_maintenant := INF

	func _process(_delta: float) -> void:
		mesurer()
		jantes = minf(jantes, jantes_maintenant)
		caisse = minf(caisse, caisse_maintenant)

	func mesurer() -> void:
		var k := get_parent() as Kart
		jantes_maintenant = INF
		# Une roue est ronde : la boîte d'une jante qui tourne descend sous
		# elle, jusqu'à r(√2 - 1) au quart de tour. Son point le plus bas est
		# son centre moins son rayon, en travers de son axe.
		var rayon := k.suspension.wheel_radius
		for roue in k.get_node("Wheels").get_children():
			var r3 := roue as Node3D
			if not (r3.get_node("Jante") as Node3D).is_visible_in_tree():
				continue
			var axe := r3.global_basis.x.normalized()
			jantes_maintenant = minf(jantes_maintenant,
				r3.global_position.y - rayon * sqrt(maxf(1.0 - axe.y * axe.y, 0.0)))
		var nuage := k.get_node_or_null("Body/Nuage") as Node3D
		var caisse_dessinee: Node = nuage if nuage != null and nuage.visible else k.get_node("Body/Kenney")
		caisse_maintenant = Temoin.le_plus_bas(caisse_dessinee)

	## Le point le plus bas des maillages visibles de `noeud`, sommet par
	## sommet. Les coins d'une boîte inclinée descendent plus bas que le
	## modèle : mesurer avec eux a fait relever la caisse de 16 cm de trop.
	static func le_plus_bas(noeud: Node) -> float:
		var y := INF
		for m in noeud.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if not mi.is_visible_in_tree() or mi.mesh == null:
				continue
			var t := mi.global_transform
			for sommet in mi.mesh.get_faces():
				y = minf(y, (t * sommet).y)
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
func _kart(roues: int = ModeleKart.ROUES_STANDARD, carrosserie: int = ModeleKart.STANDARD) -> Pilote:
	_dalle()
	kart = (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate() as Kart
	ModeleKart.habiller(kart, carrosserie, ModeleKart.couleur(0), roues)
	add_child_autofree(kart)
	var pilote := Pilote.new()
	# Enfant du kart : libéré avec lui, sans quoi chaque essai laisse un orphelin.
	kart.add_child(pilote)
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
func _glisse(sens: int, roues: int, carrosserie: int = ModeleKart.STANDARD) -> void:
	await _kart(roues, carrosserie)
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


func test_en_glisse_rien_ne_flotte() -> void:
	# Mesuré sur 32846da : en glisse, les roues passaient 21 cm au-dessus de
	# la route et la caisse 16 cm. La relève se calculait sur les coins de la
	# boîte de toute la caisse, pilote compris, et soulevait aussi les roues
	# alors que l'inclinaison de la glisse ne touche que la caisse.
	for cas in [[ModeleKart.ROUES_STANDARD, 0.0498], [ModeleKart.LEGERES, 0.0018]]:
		for sens in [-1, 1]:
			await _glisse(sens, cas[0])
			temoin.mesurer()
			assert_lt(temoin.jantes_maintenant, 0.01,
				"les roues restent au sol : %.3f m au-dessus (roues %d, sens %d)"
				% [temoin.jantes_maintenant, cas[0], sens])
			assert_lt(temoin.caisse_maintenant, cas[1] + 0.015,
				"la caisse ne monte pas au-dessus de sa hauteur de repos : %.3f m (roues %d, sens %d)"
				% [temoin.caisse_maintenant, cas[0], sens])
			kart.queue_free()
			await wait_process_frames(2)


## Le kart penche autrement que la route : l'entrée d'un virage relevé, un
## vibreur. Le rayon de la suspension touche le sol sous le centre de la roue,
## mais le flanc de la jante, une vingtaine de centimètres à côté, passait
## sous la route : sur circuit_01, 2 % du temps de plus d'un centimètre,
## jusqu'à 10 cm. Le kart reste à plat sur une dalle penchée de 6°, relevée
## (de côté) puis en pente (d'avant en arrière).
func test_sur_une_route_penchee_les_jantes_restent_dessus() -> void:
	var trains := [ModeleKart.ROUES_STANDARD, ModeleKart.SLICKS, ModeleKart.MONSTRE, ModeleKart.LEGERES]
	for penche in [Basis(Vector3.BACK, deg_to_rad(6.0)), Basis(Vector3.RIGHT, deg_to_rad(6.0))]:
		for roues in trains:
			var sol := StaticBody3D.new()
			var forme := CollisionShape3D.new()
			var boite := BoxShape3D.new()
			boite.size = Vector3(40, 1, 40)
			forme.shape = boite
			forme.position.y = -0.5
			sol.add_child(forme)
			sol.basis = penche
			add_child_autofree(sol)
			kart = (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate() as Kart
			ModeleKart.habiller(kart, ModeleKart.STANDARD, ModeleKart.couleur(0), roues)
			add_child_autofree(kart)
			await wait_physics_frames(1)
			# Le kart ne bouge plus de lui-même : il reste à plat, posé sur
			# son centre, et seule la suspension travaille.
			kart.set_physics_process(false)
			kart.global_transform = Transform3D.IDENTITY
			for i in 30:
				kart.suspension._physics_process(1.0 / 60.0)
			var normale: Vector3 = penche.y
			var plus_bas := INF
			for roue in kart.get_node("Wheels").get_children():
				var jante := (roue as Node3D).get_node("Jante") as MeshInstance3D
				var t := jante.global_transform
				for sommet in jante.mesh.get_faces():
					plus_bas = minf(plus_bas, normale.dot(t * sommet))
			assert_gt(plus_bas, -TOLERANCE, "jante %.3f m sous la route (roues %d, %s)"
				% [-plus_bas, roues, "relevée" if penche.z.y == 0.0 else "en pente"])
			kart.queue_free()
			sol.queue_free()
			await wait_process_frames(2)


func test_le_nuage_flotte_au_dessus_du_sol() -> void:
	# Mesuré sur 32846da : au repos, le bas du nuage était 3,4 cm dans la
	# route en médiane, et 22 % du temps sous la route en roulant. Il doit
	# flotter, sur toute la période de son bercement, sans s'envoler.
	await _kart(ModeleKart.ROUES_STANDARD, ModeleKart.NUAGE)
	var plus_bas := INF
	var plus_haut := -INF
	for i in 120:
		await wait_process_frames(1)
		temoin.mesurer()
		plus_bas = minf(plus_bas, temoin.caisse_maintenant)
		plus_haut = maxf(plus_haut, temoin.caisse_maintenant)
	assert_gt(plus_bas, 0.03, "le nuage flotte : son bas à %.3f m du sol" % plus_bas)
	assert_lt(plus_haut, 0.25, "sans s'envoler : %.3f m" % plus_haut)


func test_le_nuage_ne_touche_pas_le_sol_en_glisse() -> void:
	for sens in [-1, 1]:
		await _glisse(sens, ModeleKart.ROUES_STANDARD, ModeleKart.NUAGE)
		temoin.mesurer()
		assert_gt(temoin.caisse_maintenant, 0.0,
			"nez plongé et incliné, le nuage reste au-dessus du sol : %.3f m (sens %d)"
			% [temoin.caisse_maintenant, sens])
		kart.queue_free()
		await wait_process_frames(2)
