extends GutTest

## L'icône du jeu : celle du projet, et celles qu'attend l'export Android. Un
## chemin faux ou une mauvaise taille ne se voit qu'à l'installation sur le
## téléphone ; ici, il se voit tout de suite.

const PRESETS := "res://.github/export_presets.ci.cfg"


func test_le_projet_a_une_icone() -> void:
	var chemin: String = ProjectSettings.get_setting("application/config/icon", "")
	assert_ne(chemin, "")
	assert_not_null(load(chemin), "l'icône %s se charge" % chemin)


func test_les_icones_android_existent_a_la_bonne_taille() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load(PRESETS), OK)
	var attendues := {
		"launcher_icons/main_192x192": 192,
		"launcher_icons/adaptive_foreground_432x432": 432,
		"launcher_icons/adaptive_background_432x432": 432,
	}
	for cle in attendues:
		var chemin: String = presets.get_value("preset.1.options", cle, "")
		assert_true(chemin.ends_with(".png"), "%s : un PNG" % cle)
		var texture := load(chemin) as Texture2D
		assert_not_null(texture, "%s : %s se charge" % [cle, chemin])
		if texture != null:
			assert_eq(texture.get_size(), Vector2(attendues[cle], attendues[cle]), cle)
