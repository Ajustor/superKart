extends GutTest

## La musique se compose dans des fils à part : celle du menu, celle de la
## course qui se prépare. Deux fils qui remplissaient le cache en même temps
## pouvaient le corrompre, et le jeu se fermait d'un coup.

func test_deux_fils_qui_composent_en_meme_temps_remplissent_le_cache() -> void:
	var styles := [Musique.Style.TEMPS, Musique.Style.RECIF, Musique.Style.LUNE, Musique.Style.CUBES,
		Musique.Style.SAISONS, Musique.Style.LABO, Musique.Style.ESCHER, Musique.Style.ETOILES]
	var taches: Array[int] = []
	for style in styles:
		taches.append(WorkerThreadPool.add_task(Musique.composer.bind(style), false, "essai"))
		# Le même style deux fois : le second fil doit trouver ou garder la
		# même boucle, pas en écraser une à moitié écrite.
		taches.append(WorkerThreadPool.add_task(Musique.composer.bind(style), false, "essai"))
	for tache in taches:
		WorkerThreadPool.wait_for_task_completion(tache)
	for style in styles:
		var flux := Musique.deja_composee(style)
		assert_not_null(flux, "style %d composé" % style)
		assert_eq(Musique.composer(style), flux, "une seule boucle par style")
