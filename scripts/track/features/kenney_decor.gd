class_name KenneyDecor
extends RefCounted

## Les objets de décor (TrackDecor) qui ont leur pendant chez Kenney (CC0,
## assets/kenney/LICENCE.txt) : un palmier, un sapin, un rocher, une maison…
## Le modèle Kenney remplace la forme faite main, à sa taille, pour que
## les rangées, les collisions et la place de chaque objet sur les circuits
## restent ce qu'elles étaient.
##
## Toutes les pièces du modèle sont fondues en une seule maillage (une
## surface par matériau) : une rangée reste une seule MultiMesh.
##
## Ce qui brille (flammes, lanternes, cristaux, étoiles) et ce qui n'a pas
## d'équivalent reste fait main.

const DOSSIER := "res://assets/kenney/decor/"

## Objet : [modèle Kenney, ce qui donne sa taille, lueur]. « hauteur » : celle
## de l'objet fait main, la largeur suit (sans dépasser le double) ;
## « largeur » : l'emprise au sol, pour ce qui s'étale (un rocher). La lueur,
## facultative, fait briller le modèle comme brillait l'objet fait main (une
## lanterne, une étoile, un fantôme dans la nuit).
const MODELES := {
	TrackDecor.Objet.PALMIER: ["tree-palmdetailedtall", "hauteur"],
	TrackDecor.Objet.ROCHER: ["rock-largeb", "largeur"],
	TrackDecor.Objet.SAPIN: ["tree-pinetallb", "hauteur"],
	TrackDecor.Objet.ARBRE: ["tree-default", "hauteur"],
	TrackDecor.Objet.BUISSON: ["plant-bushlarge", "hauteur"],
	TrackDecor.Objet.CACTUS: ["cactus-tall", "hauteur"],
	TrackDecor.Objet.ARBRE_AUTOMNE: ["tree-default-fall", "hauteur"],
	TrackDecor.Objet.ARBRE_CUBE: ["tree-blocks", "hauteur"],
	TrackDecor.Objet.TETE_DE_PIERRE: ["statue-head", "hauteur"],
	TrackDecor.Objet.BOTTE_DE_FOIN: ["hay-bale", "hauteur"],
	TrackDecor.Objet.TONNEAU: ["barrel", "hauteur"],
	TrackDecor.Objet.MAISON: ["building-type-a", "hauteur"],
	TrackDecor.Objet.PARASOL: ["detail-parasol-a", "hauteur"],
	TrackDecor.Objet.FANTOME: ["character-ghost", "hauteur", 0.2],
	TrackDecor.Objet.LANTERNE: ["lantern-glass", "hauteur", 0.6],
	TrackDecor.Objet.CITROUILLE: ["pumpkin-carved", "hauteur", 0.25],
	TrackDecor.Objet.ANANAS: ["pineapple", "hauteur"],
	TrackDecor.Objet.FLEUR: ["flowers-tall", "hauteur"],
	TrackDecor.Objet.ETOILE: ["star", "hauteur", 0.5],
	TrackDecor.Objet.BLOC: ["block-grass", "largeur"],
	TrackDecor.Objet.CUBE_LESTE: ["crate-strong", "largeur"],
	TrackDecor.Objet.PARABOLE: ["satellitedish-large", "largeur"],
	TrackDecor.Objet.ANTENNE: ["satellitedish", "largeur"],
	TrackDecor.Objet.TOURELLE: ["turret-double", "largeur"],
}


## Le bord de piste, tiré du Racing Kit de Kenney : objet : [modèle, taille
## en mètres de sa plus grande dimension au sol (ou de sa hauteur pour ce qui
## est plus haut que large)]. Recentrés sur leur pied, la face (+z) devant :
## TrackDecor les tourne vers la route.
const DOSSIER_COURSE := "res://assets/kenney/course/"
const COURSE := {
	TrackDecor.Objet.TRIBUNE: ["grandStandCovered", 10.0],
	TrackDecor.Objet.TENTE: ["tent", 6.0],
	TrackDecor.Objet.TOUR_BANNIERE: ["bannerTowerRed", 8.0],
	TrackDecor.Objet.DRAPEAU_DAMIER: ["flagCheckers", 6.0],
	TrackDecor.Objet.PANNEAU_PUB: ["billboard", 8.0],
	TrackDecor.Objet.STANDS: ["pitsGarage", 12.0],
	TrackDecor.Objet.LAMPADAIRE_COURSE: ["lightPostLarge", 7.0],
}


static func maillage_de_course(quoi: int) -> ArrayMesh:
	var donnees: Array = COURSE[quoi]
	var racine := (load(DOSSIER_COURSE + str(donnees[0]) + ".glb") as PackedScene).instantiate() as Node3D
	var fondu := fondre(racine)
	racine.free()
	var boite := fondu.get_aabb()
	var taille := maxf(maxf(boite.size.x, boite.size.z), boite.size.y)
	var echelle := float(donnees[1]) / maxf(taille, 0.001)
	var centre := boite.get_center()
	return transformer(fondu, Transform3D(Basis.from_scale(Vector3.ONE * echelle),
		Vector3(-centre.x, -boite.position.y, -centre.z) * echelle))


static func a_un_modele(quoi: int) -> bool:
	return MODELES.has(quoi) and ResourceLoader.exists(_chemin(quoi))


static func _chemin(quoi: int) -> String:
	return DOSSIER + str(MODELES[quoi][0]) + ".glb"


## Le modèle Kenney de `quoi`, fondu en une maillage, posé sur y = 0 et mis
## à la taille de `gabarit`, la boîte de l'objet fait main (voir MODELES).
static func maillage(quoi: int, gabarit: AABB) -> ArrayMesh:
	var scene := load(_chemin(quoi)) as PackedScene
	var racine := scene.instantiate() as Node3D
	var fondu := fondre(racine)
	racine.free()
	var boite := fondu.get_aabb()
	if boite.size.y <= 0.0:
		return fondu
	var large := maxf(boite.size.x, boite.size.z)
	var large_voulu := maxf(gabarit.size.x, gabarit.size.z)
	var echelle := gabarit.end.y / boite.size.y
	if MODELES[quoi][1] == "largeur" and large > 0.0:
		echelle = large_voulu / large
	elif large > 0.0 and large_voulu > 0.0:
		echelle = minf(echelle, 2.0 * large_voulu / large)
	# Centré sur son pied : l'origine d'un modèle Kenney est souvent dans un
	# coin, et l'objet tomberait à côté de sa place (et de sa collision).
	var centre := boite.get_center()
	var mise := Transform3D(Basis.from_scale(Vector3.ONE * echelle),
		Vector3(-centre.x, -boite.position.y, -centre.z) * echelle)
	var resultat := transformer(fondu, mise)
	var donnees: Array = MODELES[quoi]
	if donnees.size() > 2:
		faire_briller(resultat, float(donnees[2]))
	return resultat


## Fait briller chaque surface de sa propre couleur (des copies : les
## matériaux du modèle sont partagés).
static func faire_briller(maillage_source: ArrayMesh, force: float) -> void:
	for s in maillage_source.get_surface_count():
		var m := maillage_source.surface_get_material(s) as StandardMaterial3D
		if m == null:
			continue
		var lumineux := m.duplicate() as StandardMaterial3D
		lumineux.emission_enabled = true
		lumineux.emission = m.albedo_color
		lumineux.emission_texture = m.albedo_texture
		lumineux.emission_energy_multiplier = force
		maillage_source.surface_set_material(s, lumineux)


## Un modèle Kenney fondu, sa plus grande dimension ramenée à `taille`,
## centré sur son pied (les objets lancés : ItemManager). Fait une fois.
static var _modeles: Dictionary = {}

static func modele(chemin: String, taille: float) -> ArrayMesh:
	var cle := "%s@%.2f" % [chemin, taille]
	if not _modeles.has(cle):
		var racine := (load(chemin) as PackedScene).instantiate() as Node3D
		var fondu := fondre(racine)
		racine.free()
		var boite := fondu.get_aabb()
		var echelle := taille / maxf(maxf(boite.size.x, boite.size.y), maxf(boite.size.z, 0.001))
		var centre := boite.get_center()
		_modeles[cle] = transformer(fondu, Transform3D(Basis.from_scale(Vector3.ONE * echelle), -centre * echelle))
	return _modeles[cle]


## Toutes les maillages sous `racine`, dans son repère, en une seule.
static func fondre(racine: Node3D) -> ArrayMesh:
	var sortie := ArrayMesh.new()
	for noeud in racine.find_children("*", "MeshInstance3D", true, false):
		var mi := noeud as MeshInstance3D
		if mi.mesh == null:
			continue
		var repere := _repere_dans(mi, racine)
		for s in mi.mesh.get_surface_count():
			var tableaux := _transformer_tableaux(mi.mesh.surface_get_arrays(s), repere)
			sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
			var matiere := mi.get_surface_override_material(s)
			if matiere == null:
				matiere = mi.mesh.surface_get_material(s)
			sortie.surface_set_material(sortie.get_surface_count() - 1, matiere)
	return sortie


static func transformer(maillage_source: ArrayMesh, repere: Transform3D) -> ArrayMesh:
	var sortie := ArrayMesh.new()
	for s in maillage_source.get_surface_count():
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			_transformer_tableaux(maillage_source.surface_get_arrays(s), repere))
		sortie.surface_set_material(s, maillage_source.surface_get_material(s))
	return sortie


static func _repere_dans(noeud: Node3D, racine: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = noeud
	while n != null and n != racine:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _transformer_tableaux(tableaux: Array, repere: Transform3D) -> Array:
	var copie := tableaux.duplicate()
	var sommets: PackedVector3Array = copie[Mesh.ARRAY_VERTEX]
	var nouveaux := PackedVector3Array()
	nouveaux.resize(sommets.size())
	for i in sommets.size():
		nouveaux[i] = repere * sommets[i]
	copie[Mesh.ARRAY_VERTEX] = nouveaux
	var normales = copie[Mesh.ARRAY_NORMAL]
	if normales is PackedVector3Array:
		var base := repere.basis.inverse().transposed()
		var tournees := PackedVector3Array()
		tournees.resize(normales.size())
		for i in normales.size():
			tournees[i] = (base * normales[i]).normalized()
		copie[Mesh.ARRAY_NORMAL] = tournees
	# Les tangentes ne servent qu'aux reliefs : les modèles Kenney n'en ont
	# pas l'usage, et elles ne suivraient pas la mise à l'échelle.
	copie[Mesh.ARRAY_TANGENT] = null
	return copie
