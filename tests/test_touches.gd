extends GutTest

## Les commandes qu'on change dans les options : décrites, enregistrées,
## relues au lancement, et une touche jamais partagée entre deux actions.

const REGLAGES := preload("res://scripts/core/game_settings.gd")
const FICHIER_DE_TEST := "user://test_touches.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER_DE_TEST))
	Touches.appliquer(GameSettings.touches)


func _reglages() -> Node:
	var r: Node = REGLAGES.new()
	r.chemin = FICHIER_DE_TEST
	return r


func _touche(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	return k


func test_un_evenement_decrit_se_recree_a_l_identique() -> void:
	var axe := InputEventJoypadMotion.new()
	axe.axis = JOY_AXIS_TRIGGER_RIGHT
	axe.axis_value = 1.0
	var bouton := InputEventJoypadButton.new()
	bouton.button_index = JOY_BUTTON_X
	for e: InputEvent in [_touche(KEY_Q), axe, bouton]:
		var recree := Touches.creer(Touches.decrire(e))
		assert_not_null(recree)
		assert_true(Touches.identiques(e, recree), e.as_text())


func test_remplacer_change_la_touche_de_la_meme_famille() -> void:
	var manette_avant := Touches.premier(&"drift", Touches.Famille.MANETTE)
	Touches.remplacer(&"drift", _touche(KEY_K))
	assert_true(Touches.identiques(Touches.premier(&"drift", Touches.Famille.CLAVIER), _touche(KEY_K)))
	assert_true(Touches.identiques(Touches.premier(&"drift", Touches.Famille.MANETTE), manette_avant),
		"la manette n'a pas bougé")


func test_une_touche_ne_sert_qu_a_une_action() -> void:
	var espace := Touches.premier(&"drift", Touches.Famille.CLAVIER)
	assert_not_null(espace)
	var changees := Touches.remplacer(&"use_item", espace)
	assert_has(changees, &"drift")
	for e in InputMap.action_get_events(&"drift"):
		assert_false(Touches.identiques(e, espace), "retirée du dérapage")


func test_les_touches_changees_survivent_au_redemarrage() -> void:
	var r := _reglages()
	r.changer_touche(&"use_item", _touche(KEY_L))
	r.free()
	InputMap.load_from_project_settings()
	var relu := _reglages()
	relu.charger()
	Touches.appliquer(relu.touches)
	assert_true(Touches.identiques(Touches.premier(&"use_item", Touches.Famille.CLAVIER), _touche(KEY_L)))
	relu.reinitialiser_touches()
	assert_false(Touches.identiques(Touches.premier(&"use_item", Touches.Famille.CLAVIER), _touche(KEY_L)),
		"réinitialisé")
	relu.free()
	var encore := _reglages()
	encore.charger()
	assert_true(encore.touches.is_empty(), "et plus rien d'enregistré")
	encore.free()


func test_l_ecran_capte_la_bonne_famille() -> void:
	var appui := _touche(KEY_M)
	appui.pressed = true
	assert_not_null(TouchesPanel.capturer(appui, Touches.Famille.CLAVIER))
	assert_null(TouchesPanel.capturer(appui, Touches.Famille.MANETTE), "une touche pour la manette")
	var effleure := InputEventJoypadMotion.new()
	effleure.axis = JOY_AXIS_LEFT_X
	effleure.axis_value = 0.3
	assert_null(TouchesPanel.capturer(effleure, Touches.Famille.MANETTE), "un stick effleuré")
	effleure.axis_value = -0.9
	var capte := TouchesPanel.capturer(effleure, Touches.Famille.MANETTE) as InputEventJoypadMotion
	assert_eq(capte.axis_value, -1.0)


func test_l_ecran_enregistre_la_touche_appuyee() -> void:
	var chemin := GameSettings.chemin
	GameSettings.chemin = FICHIER_DE_TEST
	var ecran := TouchesPanel.new()
	add_child_autofree(ecran)
	ecran.attendre(&"brake", Touches.Famille.CLAVIER)
	var appui := _touche(KEY_J)
	appui.pressed = true
	ecran._input(appui)
	assert_false(ecran.en_attente())
	assert_true(Touches.identiques(Touches.premier(&"brake", Touches.Famille.CLAVIER), _touche(KEY_J)))
	GameSettings.reinitialiser_touches()
	GameSettings.chemin = chemin


func test_la_sensibilite_ne_braque_pas_plus_d_un_tour() -> void:
	var centre := Vector2(100, 100)
	var pouce := Vector2(130, 100)
	var rayon := 80.0
	var doux := TouchControls.braquage(centre, pouce, rayon / GameSettings.SENSIBILITE_MIN)
	var vif := TouchControls.braquage(centre, pouce, rayon / GameSettings.SENSIBILITE_MAX)
	assert_gt(vif, doux, "plus sensible : le même geste braque plus")
