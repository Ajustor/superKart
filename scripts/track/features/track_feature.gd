@tool
class_name TrackFeature
extends Node3D

## Un élément posé sur le tracé : mur, tremplin, zone hors-piste. S'ajoute
## comme enfant d'un nœud Track, et se décrit dans le repère du circuit plutôt
## que dans celui du monde — où il commence le long de la courbe, sur quelle
## longueur, à quelle distance de l'axe. Quand on retouche la courbe, il suit.
##
## Deux façons de le placer dans l'éditeur :
## - régler début, longueur, décalage et largeur dans l'inspecteur ;
## - attraper le nœud dans la vue 3D et le déplacer : il se recale sur le
##   tracé, et ses réglages suivent.
##
## Comme la route, la géométrie construite ici n'a pas d'`owner` : elle n'est
## jamais sauvegardée dans la scène et reste toujours le produit des réglages.

const NOM_GENERE := "Genere"

## Où l'élément commence, en mètres le long du tracé depuis la ligne de départ.
@export var debut: float = 0.0:
	set(valeur):
		debut = valeur
		_modifie()

## Sur combien de mètres de tracé il s'étend.
@export_range(0.5, 500.0, 0.5, "or_greater") var longueur: float = 20.0:
	set(valeur):
		longueur = maxf(valeur, 0.5)
		_modifie()

## Position de son milieu par rapport à l'axe de la route, en mètres. Positif
## à droite dans le sens de la course. La route va de -demi_largeur à
## +demi_largeur : au-delà, on est à côté.
@export var decalage: float = 0.0:
	set(valeur):
		decalage = valeur
		_modifie()

## Largeur couverte, en travers du tracé.
@export_range(0.5, 100.0, 0.5, "or_greater") var largeur: float = 6.0:
	set(valeur):
		largeur = maxf(valeur, 0.5)
		_modifie()

## Pendant qu'on recale le nœud nous-mêmes, ses propres déplacements ne
## doivent pas être pris pour un geste de l'utilisateur.
var _aimantage: bool = false


func _ready() -> void:
	set_notify_transform(Engine.is_editor_hint())
	reconstruire()


func piste() -> Track:
	return get_parent() as Track


func courbe() -> TrackCurve:
	var p := piste()
	return p.track_curve if p != null else null


## L'élément couvre-t-il ce point, donné dans le repère du circuit ? La
## distance est ramenée sur le tour : un élément posé à cheval sur la ligne
## d'arrivée fonctionne comme les autres.
func contient(distance: float, lateral: float, longueur_tour: float) -> bool:
	return couvre(distance, longueur_tour) and absf(lateral - decalage) <= largeur * 0.5


func couvre(distance: float, longueur_tour: float) -> bool:
	return wrapf(distance - debut, 0.0, longueur_tour) <= longueur


## Refait la géométrie. Appelé à chaque réglage, et par le Track quand sa
## courbe change.
func reconstruire() -> void:
	_vider()
	var c := courbe()
	if c == null:
		return
	var racine := Node3D.new()
	racine.name = NOM_GENERE
	# Construit dans le repère du monde : la poignée que l'on déplace à la
	# souris ne doit pas emporter la géométrie avec elle.
	racine.top_level = true
	add_child(racine)
	_construire(c, racine)
	if Engine.is_editor_hint():
		_placer_la_poignee(c)
		update_configuration_warnings()


## À surcharger : remplit `racine` de ce qui fait l'élément.
func _construire(_c: TrackCurve, _racine: Node3D) -> void:
	pass


## Où poser la poignée, en travers du tracé. Le milieu de l'élément par défaut.
func _lateral_de_la_poignee() -> float:
	return decalage


## Retient ce qu'un déplacement de la poignée veut dire. Par défaut, le
## milieu de l'élément suit le long du tracé et en travers.
func _appliquer_deplacement(distance_milieu: float, lateral: float, longueur_tour: float) -> void:
	debut = wrapf(distance_milieu - longueur * 0.5, 0.0, longueur_tour)
	decalage = snappedf(lateral, 0.25)


func _modifie() -> void:
	if _aimantage or not is_node_ready():
		return
	_apres_modification()


## Ce qu'un réglage ou un déplacement doit refaire. L'élément seul, par défaut ;
## un trou, lui, doit faire refaire la route.
func _apres_modification() -> void:
	reconstruire()


func _vider() -> void:
	var ancien := get_node_or_null(NodePath(NOM_GENERE))
	if ancien != null:
		# Libéré tout de suite : rien d'autre ne tient ces nœuds, et un
		# glissé de poignée reconstruit à chaque image de souris.
		remove_child(ancien)
		ancien.free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not _aimantage:
		_aimanter()


## La poignée vient d'être déplacée à la main : on lit où elle est tombée dans
## le repère du circuit, on en tire les réglages, puis on la recale.
func _aimanter() -> void:
	var c := courbe()
	if c == null:
		return
	# Déjà sur le tracé : c'est notre propre recalage qui revient en écho.
	if global_position.distance_to(_position_de_la_poignee(c)) < 0.01:
		return
	var d := c.distance_of(global_position)
	var lateral := c.lateral_offset(global_position)
	_aimantage = true
	_appliquer_deplacement(d, lateral, c.length)
	_aimantage = false
	_apres_modification()
	notify_property_list_changed()


func _position_de_la_poignee(c: TrackCurve) -> Vector3:
	var milieu := debut + longueur * 0.5
	return c.position_at(milieu) + c.right_at(milieu) * _lateral_de_la_poignee() + c.up_at(milieu) * 1.0


func _placer_la_poignee(c: TrackCurve) -> void:
	_aimantage = true
	var milieu := debut + longueur * 0.5
	global_transform = Transform3D(c.basis_at(milieu), _position_de_la_poignee(c))
	_aimantage = false


func _get_configuration_warnings() -> PackedStringArray:
	var avertissements := PackedStringArray()
	if piste() == null:
		avertissements.append("À placer comme enfant direct d'un nœud Track : c'est de son tracé qu'il tire sa position.")
		return avertissements
	var c := courbe()
	if c == null:
		return avertissements
	var pire := depassement_du_centre(c)
	if pire > 0.0:
		avertissements.append(("L'élément déborde de %.1f m au-delà du centre d'un virage : " % pire) \
			+ "sa géométrie s'y replie sur elle-même. Réduis sa largeur ou son décalage vers l'intérieur.")
	return avertissements


## De combien l'élément dépasse, côté intérieur, le centre du virage le plus
## serré qu'il couvre. Au-delà, les sections se croisent et la surface se
## retourne : dans un virage de 20 m de rayon, rien ne peut s'étendre à 25 m
## vers l'intérieur. Zéro si tout va bien.
func depassement_du_centre(c: TrackCurve) -> float:
	var pire := 0.0
	for d in _sections(2.0):
		var virage := c.turn_at(d)
		if absf(virage) < 0.001:
			continue
		# Un virage à droite a son intérieur à droite, donc côté latéral positif.
		var vers_l_interieur := signf(virage)
		var etendue := (decalage + largeur * 0.5 * vers_l_interieur) * vers_l_interieur
		pire = maxf(pire, etendue - c.radius_at(d))
	return pire


# --- Outils de construction ---------------------------------------------------
# Tout se construit en bandes qui suivent la courbe, dans le plan de la
# chaussée : pente et dévers compris, un élément colle au relief du circuit.

## Les distances des sections d'une bande, d'environ `pas` mètres.
func _sections(pas: float = 1.0) -> PackedFloat32Array:
	return sections_entre(debut, longueur, pas)


static func sections_entre(de: float, sur: float, pas: float = 1.0) -> PackedFloat32Array:
	var n := maxi(int(ceil(sur / pas)), 1)
	var d := PackedFloat32Array()
	for i in n + 1:
		d.append(de + sur * float(i) / float(n))
	return d


## Un point du circuit : distance le long du tracé, écart latéral, hauteur
## au-dessus du sol.
##
## Sur le bitume, le sol est la chaussée, dévers compris. Au-delà du bord, il
## continue à plat, à la hauteur du bord : prolonger le plan incliné de la
## chaussée dressait un raccourci de dix mètres en mur, cinq mètres plus haut
## que la route dans un virage relevé.
static func point(c: TrackCurve, distance: float, lateral: float, hauteur: float) -> Vector3:
	var demi := c.half_width
	if absf(lateral) <= demi:
		return c.position_at(distance) + c.right_at(distance) * lateral + c.up_at(distance) * hauteur
	var cote := signf(lateral)
	var bord := c.position_at(distance) + c.right_at(distance) * demi * cote
	var plat := c.right_at(distance)
	plat.y = 0.0
	plat = plat.normalized()
	return bord + plat * (absf(lateral) - demi) * cote + Vector3.UP * hauteur


## Une surface posée sur le sol, de `gauche` à `droite` en travers. Coupée
## aux bords du bitume quand elle les chevauche, là où le sol passe de la
## chaussée inclinée au plat. Les UV comptent en mètres : u le long du tracé,
## v en travers.
func _nappe(c: TrackCurve, gauche: float, droite: float, hauteur: float,
		eclairee_d_en_haut := false) -> ArrayMesh:
	return nappe(c, debut, longueur, gauche, droite, hauteur, eclairee_d_en_haut)


## La même, pour n'importe quelle portion du tracé.
##
## `eclairee_d_en_haut` : toutes les normales vers le haut. Pour un sol plat
## (herbe, sable) : au creux d'un virage en pente, la bande se tord en éventail
## de facettes, chacune éclairée sous son angle, et le sol paraissait strié.
static func nappe(c: TrackCurve, de: float, sur: float, gauche: float, droite: float,
		hauteur: float, eclairee_d_en_haut := false) -> ArrayMesh:
	var colonnes := PackedFloat32Array([gauche])
	for bord in [-c.half_width, c.half_width]:
		if gauche < bord and bord < droite:
			colonnes.append(bord)
	colonnes.append(droite)

	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := sections_entre(de, sur)
	for i in sections.size() - 1:
		var d0 := sections[i]
		var d1 := sections[i + 1]
		var u0 := d0 - de
		var u1 := d1 - de
		for j in colonnes.size() - 1:
			var a := colonnes[j]
			var b := colonnes[j + 1]
			var va := a - gauche
			var vb := b - gauche
			var a0 := point(c, d0, a, hauteur)
			var b0 := point(c, d0, b, hauteur)
			var a1 := point(c, d1, a, hauteur)
			var b1 := point(c, d1, b, hauteur)
			_triangle(outil, a0, a1, b0, Vector2(u0, va), Vector2(u1, va), Vector2(u0, vb))
			_triangle(outil, b0, a1, b1, Vector2(u0, vb), Vector2(u1, va), Vector2(u1, vb))
	if eclairee_d_en_haut:
		var arrays := outil.commit_to_arrays()
		var normales := PackedVector3Array()
		normales.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		normales.fill(Vector3.UP)
		arrays[Mesh.ARRAY_NORMAL] = normales
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m
	outil.generate_normals()
	return outil.commit()


static func _triangle(outil: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	outil.set_uv(ua)
	outil.add_vertex(a)
	outil.set_uv(ub)
	outil.add_vertex(b)
	outil.set_uv(uc)
	outil.add_vertex(c)


## Un motif de flèche pour les éléments qui poussent (tremplins,
## accélérateurs) : un seul chevron par carreau, pointe vers l'avant (u
## croissant, le sens de la course), et un large vide derrière. Des chevrons
## jointifs se lisaient dans un sens comme dans l'autre, et semblaient
## parfois pointer vers l'arrière.
static func image_de_chevron(fond: Color, dessin: Color) -> Image:
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var v := absf(float(y) - 15.5) / 16.0
			# La pointe à x = 26 au milieu, les ailes reculent jusqu'à x = 10.
			var axe := 26.0 - 16.0 * v
			var dans := float(x) <= axe and float(x) > axe - 7.0 and v < 0.9
			image.set_pixel(x, y, dessin if dans else fond)
	return image


## Affiche un maillage, et lui donne une collision si demandé.
static func _poser(racine: Node3D, maillage: ArrayMesh, materiau: Material, solide: bool) -> void:
	var affichage := MeshInstance3D.new()
	affichage.mesh = maillage
	affichage.material_override = materiau
	racine.add_child(affichage)
	if solide:
		var corps := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		forme.shape = maillage.create_trimesh_shape()
		corps.add_child(forme)
		racine.add_child(corps)
