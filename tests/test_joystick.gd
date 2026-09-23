extends GutTest

## Le joystick tactile : ce qu'il braque, où il se pose, et ce qu'Input en
## reçoit quand un pouce le manipule.

const ECRAN := Vector2(1280, 720)

var _tactile_avant: int
var _joystick_avant: bool


func before_each() -> void:
	_tactile_avant = GameSettings.tactile
	_joystick_avant = GameSettings.joystick


func after_each() -> void:
	GameSettings.tactile = _tactile_avant
	GameSettings.joystick = _joystick_avant
	Input.action_release(&"steer_left")
	Input.action_release(&"steer_right")
	Input.action_release(&"throttle")


func test_au_centre_on_va_tout_droit() -> void:
	var r := 100.0
	assert_eq(TouchControls.braquage(Vector2.ZERO, Vector2(5, 30), r), 0.0, "zone morte, et le vertical ne compte pas")
	assert_eq(TouchControls.braquage(Vector2.ZERO, Vector2(-11, 0), r), 0.0)


func test_le_braquage_suit_la_poussee() -> void:
	var r := 100.0
	var peu := TouchControls.braquage(Vector2.ZERO, Vector2(40, 0), r)
	var beaucoup := TouchControls.braquage(Vector2.ZERO, Vector2(80, 0), r)
	assert_between(peu, 0.05, 0.5, "un petit coup de pouce braque un peu")
	assert_gt(beaucoup, peu)
	assert_eq(TouchControls.braquage(Vector2.ZERO, Vector2(300, 0), r), 1.0, "à fond au bord, pas au-delà")
	assert_eq(TouchControls.braquage(Vector2.ZERO, Vector2(-300, 0), r), -1.0)
	assert_almost_eq(TouchControls.braquage(Vector2.ZERO, Vector2(-40, 0), r), -peu, 0.0001, "symétrique")


func test_la_base_suit_un_pouce_qui_s_eloigne() -> void:
	var r := 100.0
	assert_eq(TouchControls.suivre(Vector2.ZERO, Vector2(50, 0), r), Vector2.ZERO, "près du centre, elle ne bouge pas")
	var suivie := TouchControls.suivre(Vector2.ZERO, Vector2(400, 0), r)
	assert_almost_eq(suivie.distance_to(Vector2(400, 0)), r * TouchControls.LAISSE, 0.001)
	# Revenir de l'autre côté ne demande plus qu'un rayon et un peu.
	assert_lt(TouchControls.braquage(suivie, Vector2(400 - r * 2.4, 0), r), 0.0)


func test_au_repos_le_joystick_tient_dans_la_zone_de_direction() -> void:
	for ecran in [Vector2(1152, 648), ECRAN, Vector2(2400, 1080), Vector2(800, 480)]:
		var repos := TouchControls.repos_joystick(ecran)
		assert_true(TouchControls.dans_la_zone_de_direction(repos, ecran), "%s" % ecran)
		var r := TouchControls.rayon_joystick(ecran)
		assert_true(Rect2(Vector2.ZERO, ecran).encloses(Rect2(repos - Vector2(r, r), Vector2(r, r) * 2.0)),
			"%s : dessiné en entier" % ecran)


func test_avec_le_joystick_les_fleches_disparaissent() -> void:
	var avec := TouchControls.boutons(ECRAN, true).map(func(b: Dictionary) -> StringName: return b.action)
	assert_false(avec.has(&"steer_left") or avec.has(&"steer_right"))
	assert_true(avec.has(&"use_item"))
	assert_eq(TouchControls.action_au_point(Vector2(100, 650), ECRAN, true), &"", "la zone est au joystick")


func _toucher(controles: TouchControls, doigt: int, ou: Vector2, appui: bool = true) -> void:
	var e := InputEventScreenTouch.new()
	e.index = doigt
	e.position = ou
	e.pressed = appui
	controles._input(e)


func _glisser(controles: TouchControls, doigt: int, ou: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = doigt
	e.position = ou
	controles._input(e)


func _controles() -> TouchControls:
	GameSettings.tactile = GameSettings.Tactile.TOUJOURS
	GameSettings.joystick = true
	# Un parent à la taille de l'écran : les commandes le remplissent, comme
	# elles remplissent le HUD en jeu.
	var ecran := Control.new()
	ecran.size = ECRAN
	add_child_autofree(ecran)
	var c := TouchControls.new()
	ecran.add_child(c)
	c._rafraichir_visibilite()
	return c


func test_un_pouce_qui_pousse_braque_en_analogique() -> void:
	var c := _controles()
	var r := TouchControls.rayon_joystick(ECRAN)
	_toucher(c, 0, Vector2(200, 550))
	assert_eq(Input.get_axis(&"steer_left", &"steer_right"), 0.0, "poser le pouce ne braque pas")
	_glisser(c, 0, Vector2(200 + r * 0.5, 550))
	var mi := Input.get_axis(&"steer_left", &"steer_right")
	assert_between(mi, 0.1, 0.6, "à moitié poussé, à moitié braqué (ou moins : la courbe)")
	_glisser(c, 0, Vector2(200 - r, 550))
	assert_almost_eq(Input.get_axis(&"steer_left", &"steer_right"), -1.0, 0.001, "à fond à gauche")
	_toucher(c, 0, Vector2(200 - r, 550), false)
	assert_eq(Input.get_axis(&"steer_left", &"steer_right"), 0.0, "pouce levé : droit devant")


func test_le_joystick_et_les_boutons_se_tiennent_ensemble() -> void:
	var c := _controles()
	var r := TouchControls.rayon_joystick(ECRAN)
	var objet: Dictionary = TouchControls.boutons(ECRAN, true).filter(
		func(b: Dictionary) -> bool: return b.action == &"drift")[0]
	_toucher(c, 0, Vector2(200, 550))
	_glisser(c, 0, Vector2(200 + r, 550))
	_toucher(c, 1, objet.centre)
	assert_true(Input.is_action_pressed(&"drift"), "l'autre pouce dérape")
	assert_almost_eq(Input.get_axis(&"steer_left", &"steer_right"), 1.0, 0.001, "pendant que le premier braque")
	_toucher(c, 1, objet.centre, false)
	assert_false(Input.is_action_pressed(&"drift"))
	assert_almost_eq(Input.get_axis(&"steer_left", &"steer_right"), 1.0, 0.001, "lâcher le dérapage ne lâche pas le volant")
