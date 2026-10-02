class_name Personnage
extends RefCounted

## Les pilotes qu'on assoit dans les karts. Chacun vient d'une œuvre ou d'une
## tradition tombée dans le domaine public (contes de Perrault, fables de La
## Fontaine, Roman de Renart, légendes…) et est redessiné ici, à la manière du
## jeu : des formes simples et des couleurs franches, lisibles de dos, à trente
## mètres, en plein virage — c'est ainsi que la caméra les voit.
##
## Un pilote ne change rien au kart : c'est un choix d'allure, et le ton de
## son klaxon.
##
## Chaque pilote est une seule maillage à couleurs de sommets : huit karts,
## huit appels de dessin de plus, pas une centaine. Les maillages sont faits
## une fois et partagés par tous les karts qui portent le même pilote.

const PERSONNAGES := [
	{nom = "Chevalier", origine = "Légendes arthuriennes", klaxon = 0.95},
	{nom = "Pirate", origine = "Légendes de la flibuste", klaxon = 0.85},
	{nom = "Robot", origine = "R.U.R., Karel Čapek (1920)", klaxon = 1.25},
	{nom = "Sorcière", origine = "Contes populaires", klaxon = 1.15},
	{nom = "Fantôme", origine = "Légendes de châteaux", klaxon = 0.7},
	{nom = "Chaperon", origine = "Le Petit Chaperon rouge, Perrault (1697)", klaxon = 1.3},
	{nom = "Viking", origine = "Sagas nordiques", klaxon = 0.8},
	{nom = "Momie", origine = "Égypte ancienne", klaxon = 0.9},
	{nom = "Renart", origine = "Le Roman de Renart (XIIᵉ siècle)", klaxon = 1.1},
	{nom = "Chat botté", origine = "Le Maître chat, Perrault (1697)", klaxon = 1.2},
	{nom = "Tortue", origine = "Le Lièvre et la Tortue, La Fontaine (1668)", klaxon = 0.65},
	{nom = "Lièvre", origine = "Le Lièvre et la Tortue, La Fontaine (1668)", klaxon = 1.4},
]

enum { CHEVALIER, PIRATE, ROBOT, SORCIERE, FANTOME, CHAPERON, VIKING, MOMIE, RENART, CHAT, TORTUE, LIEVRE }

## Le pilote s'assoit ici, dans le repère de la caisse (Body) : le haut de
## l'assise, un peu en arrière du centre du kart.
const SIEGE := Vector3(0.0, 0.44, 0.17)
## Ses mains vont au volant.
const VOLANT := Vector3(0.0, 0.62, -0.36)

static var _maillages: Dictionary = {}
static var _materiau: StandardMaterial3D


static func nombre() -> int:
	return PERSONNAGES.size()


static func donnees(i: int) -> Dictionary:
	return PERSONNAGES[clampi(i, 0, PERSONNAGES.size() - 1)]


static func nom(i: int) -> String:
	return donnees(i).nom


static func origine(i: int) -> String:
	return donnees(i).origine


static func hauteur_klaxon(i: int) -> float:
	return float(donnees(i).klaxon)


## Les pilotes de l'IA : ceux que personne n'a pris, dans l'ordre, puis on
## recommence.
static func libres(pris: Array) -> Array[int]:
	var reste: Array[int] = []
	for i in nombre():
		if not pris.has(i):
			reste.append(i)
	if reste.is_empty():
		for i in nombre():
			reste.append(i)
	return reste


## Assoit le pilote `i` dans le kart (ou la vitrine du garage) : remplace
## celui qui y était, et règle le klaxon.
static func habiller(kart: Node3D, i: int) -> void:
	var caisse := kart.get_node_or_null("Body") as Node3D
	if caisse == null:
		return
	var ancien := caisse.get_node_or_null("Pilote")
	if ancien != null:
		caisse.remove_child(ancien)
		ancien.free()
	var pilote := MeshInstance3D.new()
	pilote.name = "Pilote"
	pilote.mesh = maillage(i)
	pilote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	caisse.add_child(pilote)
	if kart is Kart:
		(kart as Kart).hauteur_klaxon = hauteur_klaxon(i)


static func maillage(i: int) -> ArrayMesh:
	i = clampi(i, 0, nombre() - 1)
	if not _maillages.has(i):
		_maillages[i] = _construire(i)
	return _maillages[i]


static func materiau() -> StandardMaterial3D:
	if _materiau == null:
		_materiau = StandardMaterial3D.new()
		_materiau.vertex_color_use_as_albedo = true
		_materiau.roughness = 0.75
	return _materiau


# --- Fabrication ---------------------------------------------------------------

## Assemble des formes simples en une seule maillage colorée.
class Atelier:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var indices := PackedInt32Array()

	func ajouter(forme: PrimitiveMesh, ou: Vector3, couleur: Color, angles := Vector3.ZERO,
			echelle := Vector3.ONE) -> void:
		var base := Basis.from_euler(angles * (PI / 180.0)).scaled(echelle)
		var t := Transform3D(base, ou)
		var pour_normales := base.inverse().transposed()
		var tableaux := forme.get_mesh_arrays()
		var depart := sommets.size()
		for v: Vector3 in tableaux[Mesh.ARRAY_VERTEX]:
			sommets.append(t * v)
			couleurs.append(couleur)
		for n: Vector3 in tableaux[Mesh.ARRAY_NORMAL]:
			normales.append((pour_normales * n).normalized())
		for k: int in tableaux[Mesh.ARRAY_INDEX]:
			indices.append(depart + k)

	func maillage() -> ArrayMesh:
		var tableaux := []
		tableaux.resize(Mesh.ARRAY_MAX)
		tableaux[Mesh.ARRAY_VERTEX] = sommets
		tableaux[Mesh.ARRAY_NORMAL] = normales
		tableaux[Mesh.ARRAY_COLOR] = couleurs
		tableaux[Mesh.ARRAY_INDEX] = indices
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
		m.surface_set_material(0, Personnage.materiau())
		return m


static func _boule(rayon: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	s.radial_segments = 14
	s.rings = 7
	return s


static func _gelule(rayon: float, hauteur: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = rayon
	c.height = maxf(hauteur, rayon * 2.0)
	c.radial_segments = 10
	c.rings = 3
	return c


static func _cylindre(bas: float, haut: float, hauteur: float, cotes: int = 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = bas
	c.top_radius = haut
	c.height = hauteur
	c.radial_segments = cotes
	c.rings = 1
	return c


static func _boite(taille: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = taille
	return b


static func _anneau(interieur: float, exterieur: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = interieur
	t.outer_radius = exterieur
	t.rings = 14
	t.ring_segments = 6
	return t


const PEAU := Color(0.96, 0.78, 0.62)
const NOIR := Color(0.08, 0.08, 0.1)
const BLANC := Color(0.95, 0.95, 0.95)

## Le haut de la tête, d'où partent chapeaux et oreilles.
const TETE := Vector3(0.0, 1.0, 0.16)
const RAYON_TETE := 0.17


## Le corps commun : jambes vers les pédales, buste, bras jusqu'au volant,
## mains, tête. `tete` à false pour ceux qui l'ont d'une autre forme.
static func _corps(a: Atelier, tenue: Color, peau: Color, mains: Color, tete := true,
		jambes := Color(0, 0, 0, 0)) -> void:
	var j := jambes if jambes.a > 0.0 else tenue.darkened(0.35)
	for cote in [-1.0, 1.0]:
		a.ajouter(_gelule(0.065, 0.5), SIEGE + Vector3(0.1 * cote, 0.02, -0.2), j, Vector3(-80, 0, 0))
	a.ajouter(_gelule(0.16, 0.46), SIEGE + Vector3(0, 0.23, 0.02), tenue, Vector3(-8, 0, 0))
	for cote in [-1.0, 1.0]:
		var epaule := SIEGE + Vector3(0.17 * cote, 0.36, 0.02)
		var main := VOLANT + Vector3(0.14 * cote, 0.0, 0.0)
		var milieu := (epaule + main) * 0.5
		var vers := main - epaule
		var bras := _gelule(0.05, vers.length() + 0.08)
		# La gélule est verticale : on la couche le long de l'avant-bras.
		var base := Basis(Quaternion(Vector3.UP, vers.normalized()))
		a.ajouter(bras, milieu, tenue, base.get_euler() * (180.0 / PI))
		a.ajouter(_boule(0.055), main, mains)
	if tete:
		a.ajouter(_boule(RAYON_TETE), TETE, peau)


## Deux yeux sur la face (devant = -Z), pour la vitrine du garage.
static func _yeux(a: Atelier, couleur := NOIR, ecart := 0.065, hauteur := 0.02, taille := 0.028) -> void:
	for cote in [-1.0, 1.0]:
		a.ajouter(_boule(taille), TETE + Vector3(ecart * cote, hauteur, -RAYON_TETE * 0.92), couleur)


static func _construire(i: int) -> ArrayMesh:
	var a := Atelier.new()
	match i:
		CHEVALIER:
			var acier := Color(0.72, 0.74, 0.8)
			_corps(a, acier, acier, acier.darkened(0.2))
			a.ajouter(_cylindre(0.18, 0.18, 0.2), TETE + Vector3(0, -0.02, 0), acier.darkened(0.1))
			a.ajouter(_boite(Vector3(0.22, 0.03, 0.02)), TETE + Vector3(0, 0.0, -0.18), NOIR)
			a.ajouter(_gelule(0.05, 0.36), TETE + Vector3(0, 0.22, 0.06), Color(0.85, 0.12, 0.12), Vector3(60, 0, 0))
			a.ajouter(_boite(Vector3(0.4, 0.06, 0.14)), SIEGE + Vector3(0, 0.36, 0.02), acier.lightened(0.15))
		PIRATE:
			_corps(a, Color(0.75, 0.13, 0.15), PEAU, PEAU, true, Color(0.2, 0.15, 0.1))
			a.ajouter(_boule(0.12), TETE + Vector3(0, -0.1, -0.08), Color(0.12, 0.08, 0.05), Vector3.ZERO, Vector3(1, 0.8, 0.9))
			a.ajouter(_cylindre(0.27, 0.27, 0.03), TETE + Vector3(0, 0.12, 0), NOIR)
			a.ajouter(_cylindre(0.14, 0.12, 0.16), TETE + Vector3(0, 0.2, 0), NOIR)
			for angle in [0.0, 120.0, 240.0]:
				var dir := Vector3(sin(deg_to_rad(angle)), 0, cos(deg_to_rad(angle)))
				a.ajouter(_boite(Vector3(0.26, 0.1, 0.03)), TETE + Vector3(0, 0.17, 0) + dir * 0.2, NOIR, Vector3(0, angle, 0))
			a.ajouter(_boule(0.03), TETE + Vector3(0, 0.22, -0.15), BLANC)
			a.ajouter(_boule(0.04), TETE + Vector3(-0.065, 0.02, -0.16), NOIR)
			a.ajouter(_boule(0.028), TETE + Vector3(0.065, 0.02, -0.16), NOIR)
		ROBOT:
			var metal := Color(0.62, 0.66, 0.72)
			_corps(a, metal, metal, metal.darkened(0.3), false, metal.darkened(0.4))
			a.ajouter(_boite(Vector3(0.3, 0.28, 0.28)), TETE, metal.lightened(0.1))
			a.ajouter(_boite(Vector3(0.24, 0.07, 0.02)), TETE + Vector3(0, 0.03, -0.14), Color(0.2, 0.95, 1.0))
			a.ajouter(_cylindre(0.012, 0.012, 0.2), TETE + Vector3(0, 0.24, 0), NOIR)
			a.ajouter(_boule(0.045), TETE + Vector3(0, 0.35, 0), Color(1.0, 0.2, 0.15))
			for cote in [-1.0, 1.0]:
				a.ajouter(_cylindre(0.05, 0.05, 0.05), TETE + Vector3(0.16 * cote, 0, 0), metal.darkened(0.3), Vector3(0, 0, 90))
			a.ajouter(_boite(Vector3(0.18, 0.12, 0.02)), SIEGE + Vector3(0, 0.26, -0.15), Color(1.0, 0.75, 0.2))
		SORCIERE:
			var robe := Color(0.36, 0.16, 0.5)
			var verte := Color(0.55, 0.78, 0.42)
			_corps(a, robe, verte, verte)
			a.ajouter(_cylindre(0.3, 0.3, 0.02), TETE + Vector3(0, 0.1, 0), NOIR)
			a.ajouter(_cylindre(0.15, 0.0, 0.48), TETE + Vector3(0, 0.34, 0.05), NOIR, Vector3(12, 0, 0))
			a.ajouter(_cylindre(0.155, 0.13, 0.05), TETE + Vector3(0, 0.14, 0.01), Color(0.95, 0.65, 0.1))
			a.ajouter(_gelule(0.1, 0.4), TETE + Vector3(0, -0.12, 0.13), Color(0.6, 0.3, 0.12))
			_yeux(a)
		FANTOME:
			# Un drap : pas de bras qui dépassent, un grand voile qui flotte.
			a.ajouter(_cylindre(0.17, 0.26, 0.55), SIEGE + Vector3(0, 0.27, 0.04), BLANC)
			a.ajouter(_boule(0.2), TETE + Vector3(0, -0.04, 0), BLANC)
			for cote in [-1.0, 1.0]:
				a.ajouter(_gelule(0.07, 0.42), SIEGE + Vector3(0.17 * cote, 0.25, -0.22), BLANC, Vector3(-60, 0, 0))
				a.ajouter(_boule(0.04), TETE + Vector3(0.07 * cote, 0.0, -0.18), NOIR, Vector3.ZERO, Vector3(1, 1.4, 0.6))
			a.ajouter(_boule(0.05), TETE + Vector3(0, -0.1, -0.18), NOIR, Vector3.ZERO, Vector3(1, 1.2, 0.6))
		CHAPERON:
			var rouge := Color(0.86, 0.1, 0.12)
			_corps(a, Color(0.95, 0.9, 0.8), PEAU, PEAU, true, Color(0.35, 0.25, 0.2))
			# Le capuchon : une calotte rouge derrière la tête, et la pèlerine.
			a.ajouter(_boule(0.2), TETE + Vector3(0, 0.03, 0.05), rouge, Vector3.ZERO, Vector3(1.05, 1.05, 0.95))
			a.ajouter(_cylindre(0.08, 0.0, 0.16), TETE + Vector3(0, 0.12, 0.2), rouge, Vector3(-60, 0, 0))
			a.ajouter(_cylindre(0.2, 0.3, 0.42), SIEGE + Vector3(0, 0.26, 0.07), rouge)
			a.ajouter(_gelule(0.07, 0.24), TETE + Vector3(0, -0.06, 0.16), Color(0.55, 0.3, 0.12))
			_yeux(a)
		VIKING:
			_corps(a, Color(0.45, 0.3, 0.18), PEAU, PEAU, true, Color(0.3, 0.2, 0.12))
			var casque := Color(0.6, 0.62, 0.66)
			a.ajouter(_boule(0.18), TETE + Vector3(0, 0.05, 0), casque, Vector3.ZERO, Vector3(1, 0.8, 1))
			for cote in [-1.0, 1.0]:
				a.ajouter(_cylindre(0.045, 0.0, 0.22), TETE + Vector3(0.2 * cote, 0.14, 0), Color(0.95, 0.92, 0.8), Vector3(0, 0, -50 * cote))
			a.ajouter(_boule(0.15), TETE + Vector3(0, -0.13, -0.06), Color(0.85, 0.45, 0.12), Vector3.ZERO, Vector3(1, 1.1, 0.8))
			a.ajouter(_gelule(0.045, 0.26), TETE + Vector3(0, -0.27, -0.13), Color(0.85, 0.45, 0.12))
			a.ajouter(_cylindre(0.22, 0.24, 0.12), SIEGE + Vector3(0, 0.38, 0.02), Color(0.75, 0.68, 0.55))
			_yeux(a)
		MOMIE:
			var bande := Color(0.88, 0.84, 0.7)
			_corps(a, bande, bande, bande)
			for k in 5:
				a.ajouter(_anneau(0.15, 0.175), TETE + Vector3(0, -0.12 + k * 0.06, 0), bande.darkened(0.15), Vector3(8 * (k % 2 * 2 - 1), 0, 0))
			for k in 4:
				a.ajouter(_anneau(0.15, 0.18), SIEGE + Vector3(0, 0.12 + k * 0.08, 0.02), bande.darkened(0.12), Vector3(6 * (k % 2 * 2 - 1), 0, 0))
			_yeux(a, Color(0.95, 0.85, 0.2), 0.06, 0.02, 0.025)
		RENART:
			var roux := Color(0.9, 0.42, 0.1)
			_corps(a, Color(0.2, 0.5, 0.25), roux, roux)
			a.ajouter(_cylindre(0.1, 0.03, 0.18), TETE + Vector3(0, -0.04, -0.2), roux, Vector3(-90, 0, 0))
			a.ajouter(_boule(0.035), TETE + Vector3(0, -0.04, -0.3), NOIR)
			a.ajouter(_boule(0.09), TETE + Vector3(0, -0.09, -0.11), BLANC, Vector3.ZERO, Vector3(1.2, 0.8, 1))
			for cote in [-1.0, 1.0]:
				a.ajouter(_cylindre(0.07, 0.0, 0.18), TETE + Vector3(0.1 * cote, 0.19, 0.02), roux, Vector3(0, 0, -15 * cote))
				a.ajouter(_cylindre(0.035, 0.0, 0.1), TETE + Vector3(0.1 * cote, 0.17, -0.01), NOIR, Vector3(0, 0, -15 * cote))
			# La queue en panache, qui dépasse derrière le siège.
			a.ajouter(_gelule(0.09, 0.5), SIEGE + Vector3(0, 0.12, 0.42), roux, Vector3(-60, 0, 0))
			a.ajouter(_boule(0.085), SIEGE + Vector3(0, 0.33, 0.55), BLANC)
			_yeux(a)
		CHAT:
			var gris := Color(0.62, 0.6, 0.58)
			_corps(a, Color(0.7, 0.12, 0.2), gris, gris, true, Color(0.25, 0.15, 0.08))
			a.ajouter(_boule(0.07), TETE + Vector3(0, -0.07, -0.13), BLANC, Vector3.ZERO, Vector3(1.3, 0.8, 0.9))
			a.ajouter(_boule(0.025), TETE + Vector3(0, -0.04, -0.19), Color(0.95, 0.5, 0.6))
			for cote in [-1.0, 1.0]:
				a.ajouter(_cylindre(0.065, 0.0, 0.14), TETE + Vector3(0.11 * cote, 0.16, 0.03), gris, Vector3(0, 0, -20 * cote))
			# Le grand chapeau à plume des mousquetaires.
			a.ajouter(_cylindre(0.3, 0.3, 0.025), TETE + Vector3(0, 0.15, 0.02), Color(0.3, 0.18, 0.1), Vector3(-10, 0, 8))
			a.ajouter(_cylindre(0.13, 0.12, 0.12), TETE + Vector3(0, 0.22, 0.03), Color(0.3, 0.18, 0.1), Vector3(-10, 0, 8))
			a.ajouter(_gelule(0.035, 0.42), TETE + Vector3(-0.12, 0.3, 0.12), BLANC, Vector3(40, 0, 30))
			_yeux(a, Color(0.35, 0.8, 0.3))
		TORTUE:
			var verte := Color(0.45, 0.68, 0.3)
			_corps(a, verte, verte, verte, true, verte.darkened(0.2))
			# La carapace sur le dos, plus haute que le dossier.
			a.ajouter(_boule(0.27), SIEGE + Vector3(0, 0.28, 0.17), Color(0.5, 0.33, 0.15), Vector3(-10, 0, 0), Vector3(1, 1.15, 0.7))
			for k in 3:
				a.ajouter(_cylindre(0.06, 0.06, 0.02, 6), SIEGE + Vector3(0, 0.18 + k * 0.12, 0.35), Color(0.65, 0.5, 0.22), Vector3(-80, 0, 0))
			_yeux(a)
		LIEVRE:
			var brun := Color(0.66, 0.5, 0.34)
			_corps(a, Color(0.2, 0.35, 0.75), brun, BLANC)
			for cote in [-1.0, 1.0]:
				a.ajouter(_gelule(0.05, 0.4), TETE + Vector3(0.07 * cote, 0.3, 0.06), brun, Vector3(-12, 0, -8 * cote))
				a.ajouter(_gelule(0.028, 0.3), TETE + Vector3(0.07 * cote, 0.3, 0.035), Color(0.95, 0.7, 0.75), Vector3(-12, 0, -8 * cote))
			a.ajouter(_boule(0.07), TETE + Vector3(0, -0.07, -0.13), BLANC, Vector3.ZERO, Vector3(1.3, 0.8, 0.9))
			a.ajouter(_boule(0.025), TETE + Vector3(0, -0.03, -0.19), Color(0.9, 0.45, 0.55))
			a.ajouter(_boule(0.07), SIEGE + Vector3(0, 0.05, 0.34), BLANC)
			_yeux(a)
	return a.maillage()
