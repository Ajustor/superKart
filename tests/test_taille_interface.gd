extends GutTest

## La taille de l'interface et l'aide des commandes du premier lancement.

const REGLAGES := preload("res://scripts/core/game_settings.gd")
const FICHIER_DE_TEST := "user://test_taille_interface.cfg"


func after_each() -> void:
	if FileAccess.file_exists(FICHIER_DE_TEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER_DE_TEST))


func _reglages() -> Node:
	var r: Node = REGLAGES.new()
	r.chemin = FICHIER_DE_TEST
	autofree(r)
	return r


func test_la_taille_de_l_interface_va_de_petite_a_grande() -> void:
	var t := REGLAGES.TailleInterface
	assert_lt(REGLAGES.echelle_interface(t.PETITE), REGLAGES.echelle_interface(t.NORMALE))
	assert_lt(REGLAGES.echelle_interface(t.NORMALE), REGLAGES.echelle_interface(t.GRANDE))
	assert_eq(REGLAGES.echelle_interface(t.NORMALE), 1.0)


func test_sans_ecran_tactile_l_interface_est_plus_petite() -> void:
	# Les essais tournent sur un PC, sans écran tactile.
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		pass_test("écran tactile : rien à vérifier ici")
		return
	assert_lt(REGLAGES.echelle_interface(REGLAGES.TailleInterface.AUTO), 1.0)


func test_l_aide_vue_et_la_taille_survivent_a_un_redemarrage() -> void:
	var avant := _reglages()
	assert_false(avant.aide_vue, "au premier lancement, l'aide n'a pas été vue")
	avant.aide_vue = true
	avant.taille_interface = REGLAGES.TailleInterface.GRANDE
	avant.sauver()
	var apres := _reglages()
	apres.charger()
	assert_true(apres.aide_vue)
	assert_eq(apres.taille_interface, REGLAGES.TailleInterface.GRANDE)


func test_l_aide_montre_les_touches_du_clavier_et_de_la_manette() -> void:
	for ligne in AideCommandes.ACTIONS:
		var action: StringName = ligne[0]
		assert_true(InputMap.has_action(action), "%s existe" % action)
		assert_ne(AideCommandes.touches(action, Touches.Famille.CLAVIER), "—", "%s : une touche au clavier" % action)
		assert_ne(AideCommandes.touches(action, Touches.Famille.MANETTE), "—", "%s : un bouton à la manette" % action)
