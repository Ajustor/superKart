@tool
class_name TrackWall
extends TrackFeature

## Un mur qui suit le tracé. Posé au bord, il empêche de tomber ou de couper ;
## posé au milieu de la route, il la sépare en deux voies — de quoi dessiner
## l'entrée d'un raccourci.
##
## Le kart qui le touche perd la vitesse qu'il y enfonce et glisse le long,
## et les carapaces rebondissent dessus.

enum Cote { GAUCHE, DROITE, LES_DEUX, LIBRE }

## GAUCHE, DROITE ou LES_DEUX : collé au bord du bitume. LIBRE : à l'écart
## `decalage` de l'axe, où l'on veut.
@export var cote: Cote = Cote.LES_DEUX:
	set(valeur):
		cote = valeur
		_modifie()

@export_range(0.2, 10.0, 0.1) var hauteur: float = 1.2:
	set(valeur):
		hauteur = valeur
		_modifie()

@export_range(0.1, 5.0, 0.05) var epaisseur: float = 0.6:
	set(valeur):
		epaisseur = valeur
		_modifie()

## Écart entre le bord du bitume et le mur, pour les murs de bord.
@export_range(0.0, 20.0, 0.1) var marge: float = 0.2:
	set(valeur):
		marge = valeur
		_modifie()

## Les deux couleurs des bandes alternées, comme un vibreur.
@export var couleur: Color = Color("d4564e"):
	set(valeur):
		couleur = valeur
		_modifie()
@export var couleur_bis: Color = Color(0.95, 0.95, 0.95):
	set(valeur):
		couleur_bis = valeur
		_modifie()

## Longueur de chaque bande de couleur, en mètres.
const BANDE := 2.0


func _init() -> void:
	longueur = 40.0


## L'écart à l'axe de chaque mur, pris en son milieu.
func lignes(demi_largeur: float) -> PackedFloat32Array:
	var bord := demi_largeur + marge + epaisseur * 0.5
	match cote:
		Cote.GAUCHE:
			return PackedFloat32Array([-bord])
		Cote.DROITE:
			return PackedFloat32Array([bord])
		Cote.LES_DEUX:
			return PackedFloat32Array([-bord, bord])
	return PackedFloat32Array([decalage])


## Un mur n'occupe pas une zone : c'est une ligne. Ce test sert au kart qui
## serait posé dedans, pas au jeu.
func contient(distance: float, lateral: float, longueur_tour: float) -> bool:
	if not couvre(distance, longueur_tour):
		return false
	var demi := courbe().half_width if courbe() != null else 0.0
	for l in lignes(demi):
		if absf(lateral - l) <= epaisseur * 0.5:
			return true
	return false


## Les barrières du Racing Kit de Kenney (CC0) : des blocs bas pour un mur
## bas, le mur de béton à bande pour un mur haut. Chacune est étirée sur une
## bande de BANDE mètres et dans la hauteur et l'épaisseur du mur, aux
## couleurs du mur (couleur, couleur_bis en alternance).
const BARRIERE := "res://assets/kenney/course/barrierRed.glb"
const MUR_DE_BETON := "res://assets/kenney/course/barrierWall.glb"
## Au-delà de cette hauteur, un mur n'est plus une barrière mais un mur.
const HAUTEUR_DE_BARRIERE := 2.0

static var _formes: Dictionary = {}


func _construire(c: TrackCurve, racine: Node3D) -> void:
	for l in lignes(c.half_width):
		var muret := _muret(c, l)
		if not _en_barrieres() or not ResourceLoader.exists(BARRIERE):
			var materiau := StandardMaterial3D.new()
			materiau.vertex_color_use_as_albedo = true
			materiau.roughness = 0.7
			TrackFeature._poser(racine, muret, materiau, true)
			continue
		# La collision reste celle du muret : un pavé lisse, sans accroc.
		var corps := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		forme.shape = muret.create_trimesh_shape()
		corps.add_child(forme)
		racine.add_child(corps)
		_poser_les_barrieres(c, l, racine)


## Faux : le mur garde sa forme de muret à bandes (un tunnel, dont les
## parois font corps avec la voûte).
func _en_barrieres() -> bool:
	return true


## Une barrière Kenney fondue en une maillage, ramenée à la boîte unité
## (x de 0 à 1 le long du mur, y de 0 à 1, z de -0,5 à 0,5).
static func forme_unite(chemin: String) -> ArrayMesh:
	if not _formes.has(chemin):
		var racine := (load(chemin) as PackedScene).instantiate() as Node3D
		var fondu := KenneyDecor.fondre(racine)
		racine.free()
		var b := fondu.get_aabb()
		var mise := Transform3D(Basis.from_scale(Vector3(1.0 / b.size.x, 1.0 / b.size.y, 1.0 / b.size.z)),
			Vector3(-b.position.x / b.size.x, -b.position.y / b.size.y, -(b.position.z + b.size.z * 0.5) / b.size.z))
		_formes[chemin] = KenneyDecor.transformer(fondu, mise)
	return _formes[chemin]


func _poser_les_barrieres(c: TrackCurve, centre: float, racine: Node3D) -> void:
	var haut := hauteur > HAUTEUR_DE_BARRIERE
	var forme := forme_unite(MUR_DE_BETON if haut else BARRIERE)
	var poses: Array[Array] = [[], []]
	var sections := _sections(BANDE)
	for i in sections.size() - 1:
		var d0 := sections[i]
		var d1 := sections[i + 1]
		var p0 := point(c, d0, centre, -0.2)
		var p1 := point(c, d1, centre, -0.2)
		var le_long := p1 - p0
		if le_long.length() < 0.01:
			continue
		var debout := (point(c, d0, centre, 1.0) - point(c, d0, centre, 0.0)).normalized()
		var travers := le_long.cross(debout).normalized()
		debout = travers.cross(le_long).normalized()
		var base := Basis(le_long, debout * (hauteur + 0.2), travers * epaisseur)
		var bande := 0 if haut else int(floor((d0 - debut) / BANDE)) % 2
		poses[bande].append(Transform3D(base, p0))
	for bande in 2:
		if poses[bande].is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		# Les couleurs du mur : le mur de béton garde sa bande (couleur) sur un
		# corps clair (couleur_bis) ; les blocs bas alternent. Une MultiMesh ne
		# prend pas de matériau par surface : on les pose sur une copie.
		var teintes: Array = [couleur_bis, couleur] if haut else [couleur if bande == 0 else couleur_bis]
		var peinte := forme.duplicate() as ArrayMesh
		for s in peinte.get_surface_count():
			peinte.surface_set_material(s, _materiau_unique(teintes[mini(s, teintes.size() - 1)]))
		multi.mesh = peinte
		multi.instance_count = poses[bande].size()
		for i in poses[bande].size():
			multi.set_instance_transform(i, poses[bande][i])
		var affichage := MultiMeshInstance3D.new()
		affichage.multimesh = multi
		racine.add_child(affichage)


static func _materiau_unique(teinte: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = teinte
	m.roughness = 0.6
	return m


## Un pavé extrudé le long du tracé : deux flancs, le dessus, et les deux bouts.
func _muret(c: TrackCurve, centre: float) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := centre - epaisseur * 0.5
	var r := centre + epaisseur * 0.5
	var sections := _sections(BANDE * 0.5)
	for i in sections.size() - 1:
		var d0 := sections[i]
		var d1 := sections[i + 1]
		var bande := int(floor((d0 - debut) / BANDE)) % 2
		outil.set_color(couleur if bande == 0 else couleur_bis)
		var gb0 := point(c, d0, g, -0.2)
		var gh0 := point(c, d0, g, hauteur)
		var rb0 := point(c, d0, r, -0.2)
		var rh0 := point(c, d0, r, hauteur)
		var gb1 := point(c, d1, g, -0.2)
		var gh1 := point(c, d1, g, hauteur)
		var rb1 := point(c, d1, r, -0.2)
		var rh1 := point(c, d1, r, hauteur)
		_quad(outil, gb0, gb1, gh1, gh0)   # flanc gauche
		_quad(outil, rb1, rb0, rh0, rh1)   # flanc droit
		_quad(outil, gh0, gh1, rh1, rh0)   # dessus
		if i == 0:
			_quad(outil, rb0, gb0, gh0, rh0)
		if i == sections.size() - 2:
			_quad(outil, gb1, rb1, rh1, gh1)
	outil.generate_normals()
	return outil.commit()


static func _quad(outil: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	outil.add_vertex(a)
	outil.add_vertex(b)
	outil.add_vertex(c)
	outil.add_vertex(a)
	outil.add_vertex(c)
	outil.add_vertex(d)


func _lateral_de_la_poignee() -> float:
	var demi := courbe().half_width if courbe() != null else 0.0
	var l := lignes(demi)
	return l[0] if l.size() == 1 else 0.0


## Glissée à la souris, la poignée déplace le mur le long du tracé. En travers,
## elle choisit le côté : d'un bord à l'autre pour un mur de bord, n'importe
## où pour un mur libre.
func _appliquer_deplacement(distance_milieu: float, lateral: float, longueur_tour: float) -> void:
	debut = wrapf(distance_milieu - longueur * 0.5, 0.0, longueur_tour)
	match cote:
		Cote.LIBRE:
			decalage = snappedf(lateral, 0.25)
		Cote.GAUCHE, Cote.DROITE:
			cote = Cote.GAUCHE if lateral < 0.0 else Cote.DROITE
