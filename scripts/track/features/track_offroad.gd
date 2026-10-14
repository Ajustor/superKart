@tool
class_name TrackOffroad
extends TrackFeature

## Une zone hors-piste : de l'herbe, du sable, de la boue. Le kart y roule,
## mais lentement, et comme hors du bitume.
##
## Posée sur la route, elle la rétrécit ou la coupe d'une bande à éviter.
## Posée à côté, elle crée du terrain là où il n'y avait que du vide : c'est
## ainsi qu'on dessine un raccourci — plus court que la route, plus lent à
## parcourir, et d'autant plus payant qu'on y entre avec un champignon.

enum Sol { HERBE, SABLE, BOUE, NEIGE }

@export var sol: Sol = Sol.HERBE:
	set(valeur):
		sol = valeur
		_modifie()


## Une couleur à soi plutôt que celle du sol : du béton, de la poussière
## lunaire, l'herbe noire d'un parc hanté. Transparente : celle du sol.
@export var teinte: Color = Color(0, 0, 0, 0):
	set(valeur):
		teinte = valeur
		_modifie()


func _init() -> void:
	longueur = 30.0
	largeur = 12.0


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var g := decalage - largeur * 0.5
	var r := decalage + largeur * 0.5
	var sections := _sections()
	var gauches := _bornes(c, sections, g, r, -1.0)
	var droites := _bornes(c, sections, g, r, 1.0)
	var materiau := _materiau()
	# Dessinée deux centimètres au-dessus du bitume : là où la zone recouvre
	# la route, c'est elle qu'on voit. Mais solide au ras : ces deux
	# centimètres faisaient un mur sous le pare-chocs, 74 % des sorties vers
	# une bande d'herbe s'y bloquaient.
	TrackFeature._poser(racine, TrackFeature.nappe_bornee(c, sections, gauches, droites, debut, 0.02, true, true),
		materiau, false)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	forme.shape = TrackFeature.nappe_bornee(c, sections, gauches, droites, debut, 0.0, false, true) 		.create_trimesh_shape()
	corps.add_child(forme)
	racine.add_child(corps)
	# Un sol plat n'a rien à ombrer : au creux d'un virage en pente, sa bande
	# tordue projetait des traits d'ombre sur elle-même.
	for enfant in racine.get_children():
		if enfant is GeometryInstance3D:
			(enfant as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_poser_les_talus(c, racine, g, r, sections, gauches, droites, materiau)


## Le bord de la bande vers `cote`, section par section : là où elle déborde
## du bitume vers l'intérieur d'un virage serré, pas au-delà de ce qui se
## replierait (TrackFeature.portee_sans_repli) — jusqu'à ne plus rien
## couvrir au-delà du bitume ou de son autre bord, s'il le faut.
static func _bornes(c: TrackCurve, sections: PackedFloat32Array, g: float, r: float,
		cote: float) -> PackedFloat32Array:
	var loin := r if cote > 0.0 else -g
	var pres := g if cote > 0.0 else -r
	var bornes := PackedFloat32Array()
	bornes.resize(sections.size())
	bornes.fill(loin)
	if loin > c.half_width + 0.25:
		var portee := TrackFeature.portee_sans_repli(c, sections, cote, loin)
		var plancher := minf(maxf(pres, c.half_width), loin)
		for i in sections.size():
			bornes[i] = maxf(portee[i], plancher)
	for i in sections.size():
		bornes[i] *= cote
	return bornes


## Les bords de la bande qui ne touchent pas la route, et ses deux bouts :
## un talus partout où un sol réel est dessous (TrackTalus). Sans lui, la
## bande, restée à la hauteur du bord de la route, flottait au-dessus du sol
## plus bas : une marche de 13 à 32 cm, ou un dessous où l'on passait.
##
## Le talus d'un bord a les sommets de la bande, un par mètre (_sections) :
## coupé tous les deux mètres, sa corde passait au milieu au-dessus ou
## au-dessous de la bande, une lèvre de 0,4 à 1,3 cm qui arrêtait le kart
## venu du sol.
func _poser_les_talus(c: TrackCurve, racine: Node3D, g: float, r: float, sections: PackedFloat32Array,
		gauches: PackedFloat32Array, droites: PackedFloat32Array, materiau: Material) -> void:
	var circuit := piste()
	if circuit == null:
		return
	var demi := c.half_width
	var triangles := PackedVector3Array()
	# Un bord sur le bitume ou à son ras touche la route : rien à poser. Les
	# autres descendent vers l'extérieur de la bande, côté route compris
	# pour une bande détachée.
	for bord: Array in [[r, droites, 1.0], [g, gauches, -1.0]]:
		var lateral: float = bord[0]
		var lateraux: PackedFloat32Array = bord[1]
		var cote: float = bord[2]
		if absf(lateral) <= demi + 0.25:
			continue
		var arete := TrackTalus.Bord.new()
		arete.cote = cote
		arete.lateraux = lateraux
		for i in sections.size():
			arete.sommets.append(TrackFeature.point_lisse(c, sections[i], lateraux[i], 0.0))
			arete.distances.append(sections[i])
		# Fermé aussi à ses bouts : la pente y rejoint celle du bout de la
		# bande, sans coin ouvert.
		triangles.append_array(TrackTalus.le_long(circuit, c, arete, lateral, cote,
			func(_d: float) -> bool: return true, true).triangles)
	# Les bouts, sur la partie de la bande qui n'est pas sur le bitume.
	for bout: Array in [[0, -1.0], [sections.size() - 1, 1.0]]:
		var i: int = bout[0]
		var sens: float = bout[1]
		var d := sections[i]
		for morceau: Vector2 in _hors_du_bitume(gauches[i], droites[i], demi):
			triangles.append_array(TrackTalus.en_travers(circuit, c, d, morceau.x, morceau.y, sens))
	TrackTalus.poser(racine, triangles, materiau)


## Les parties de [g, r] hors du bitume, de chaque côté.
static func _hors_du_bitume(g: float, r: float, demi: float) -> Array[Vector2]:
	var morceaux: Array[Vector2] = []
	if g < -demi:
		morceaux.append(Vector2(g, minf(r, -demi)))
	if r > demi:
		morceaux.append(Vector2(maxf(g, demi), r))
	return morceaux


func _materiau() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	match sol:
		Sol.HERBE:
			m.albedo_color = Color(0.3, 0.6, 0.22)
		Sol.SABLE:
			m.albedo_color = Color(0.86, 0.76, 0.5)
		Sol.BOUE:
			m.albedo_color = Color(0.4, 0.28, 0.16)
		Sol.NEIGE:
			m.albedo_color = Color(0.92, 0.95, 1.0)
	if teinte.a > 0.0:
		m.albedo_color = Color(teinte, 1.0)
	m.roughness = 1.0
	return m
