@tool
class_name TrackTerrain
extends TrackFeature

## Le sol autour du circuit : un relief de collines qui épouse la route. Juste
## sous le bitume et au ras des bas-côtés près du tracé, il s'en affranchit en
## s'éloignant et monte en collines ; sous un trou du circuit, il se creuse en
## ravin.
##
## Purement décoratif : sans collision, il ne change rien à la course. Un kart
## qui quitte la route est remis en piste bien avant d'atteindre le relief.
##
## Les décors du même circuit s'y posent (TrackDecor.hauteur_du_sol) : un
## arbre à quarante mètres de la route est au pied de sa colline, pas en
## l'air au niveau du bitume.

## Mètres de terrain autour du tracé.
@export_range(20.0, 600.0, 5.0) var marge: float = 160.0:
	set(valeur):
		marge = valeur
		_modifie()

## Taille d'une maille, en mètres : plus fin, plus joli, plus lourd.
@export_range(2.0, 20.0, 0.5) var maille: float = 6.0:
	set(valeur):
		maille = valeur
		_modifie()

## Hauteur des collines au loin, en mètres.
@export_range(0.0, 80.0, 0.5) var relief: float = 14.0:
	set(valeur):
		relief = valeur
		_modifie()

## Profondeur du ravin sous un trou du circuit.
@export_range(0.0, 60.0, 0.5) var ravin: float = 16.0:
	set(valeur):
		ravin = valeur
		_modifie()

@export var couleur: Color = Color(0.3, 0.6, 0.22):
	set(valeur):
		couleur = valeur
		_modifie()

@export var graine: int = 3:
	set(valeur):
		graine = valeur
		_modifie()

## Faux : le relief épouse tout le tracé. Vrai : seulement la portion
## [debut, debut + longueur] — un pont qui file à quarante mètres de haut, ou
## un autre monde derrière un portail, ne soulève pas de crête sous lui.
@export var portion: bool = false:
	set(valeur):
		portion = valeur
		_modifie()


func _validate_property(property: Dictionary) -> void:
	if property.name in ["decalage", "largeur"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name in ["debut", "longueur"] and not portion:
		property.usage = PROPERTY_USAGE_NO_EDITOR

## Pas des échantillons de route, en mètres.
const PAS := 3.0
## Case de la grille de recherche des échantillons, en mètres.
const CASE := 30.0
## Sous le bitume, puis au ras des bas-côtés : juste assez pour ne jamais
## percer la route dans un creux (flèche d'une corde de 6 m sur un rayon
## vertical de 50 m : 9 cm).
const SOUS_LA_ROUTE := 0.45
const SOUS_LE_BORD := 0.14

var _echantillons: Array[Vector3] = []
var _droites: Array[Vector3] = []
var _dans_un_trou: Array[bool] = []
var _grille: Dictionary = {}
var _bruit: FastNoiseLite
var _pour: TrackCurve


func _init() -> void:
	longueur = 1.0


## La hauteur du sol à ce point (x, z) du monde.
func hauteur_en(x: float, z: float) -> float:
	var c := courbe()
	if c == null:
		return 0.0
	_preparer(c)
	return _hauteur(c, x, z)


func _preparer(c: TrackCurve) -> void:
	if _pour == c and not _echantillons.is_empty():
		return
	_pour = c
	_echantillons.clear()
	_droites.clear()
	_dans_un_trou.clear()
	_grille.clear()
	var circuit := piste()
	var n := maxi(int(c.length / PAS), 8)
	for k in n:
		var d := c.length * float(k) / float(n)
		# Ce qui n'est pas de ce relief : hors de la portion, ou la boucle
		# qu'on ne court pas après l'arrivée d'une course linéaire.
		if portion and not couvre(d, c.length):
			continue
		if circuit != null and circuit.hors_course(d):
			continue
		var i := _echantillons.size()
		_echantillons.append(c.position_at(d))
		_droites.append(c.right_at(d))
		# Le ravin déborde un peu du trou : ses bords ne tombent pas à pic
		# au ras de la route.
		var trou := false
		if circuit != null:
			for marge_trou in [-4.0, 0.0, 4.0]:
				if circuit.trou_en(wrapf(d + marge_trou, 0.0, c.length)) != null:
					trou = true
		_dans_un_trou.append(trou)
		var cle := _case(_echantillons[i].x, _echantillons[i].z)
		# Un PackedInt32Array se copie : on le relit, on l'allonge, on le
		# range.
		var liste: PackedInt32Array = _grille.get(cle, PackedInt32Array())
		liste.append(i)
		_grille[cle] = liste
	_bruit = FastNoiseLite.new()
	_bruit.seed = graine
	_bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bruit.frequency = 0.006
	_bruit.fractal_octaves = 3


func _case(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CASE), floori(z / CASE))


## L'échantillon de route le plus proche dans le plan, et sa distance. Cherché
## dans les cases voisines ; au-delà, tout est loin et la plus proche des
## routes n'a plus d'importance que pour l'altitude de base.
func _plus_proche(x: float, z: float) -> Vector2:
	var centre := _case(x, z)
	var meilleur := -1
	var d2_min := INF
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var cle := centre + Vector2i(dx, dz)
			if not _grille.has(cle):
				continue
			for i in (_grille[cle] as PackedInt32Array):
				var e := _echantillons[i]
				var d2 := (e.x - x) * (e.x - x) + (e.z - z) * (e.z - z)
				if d2 < d2_min:
					d2_min = d2
					meilleur = i
	if meilleur < 0:
		# Loin de tout : une recherche grossière suffit.
		for i in range(0, _echantillons.size(), 8):
			var e := _echantillons[i]
			var d2 := (e.x - x) * (e.x - x) + (e.z - z) * (e.z - z)
			if d2 < d2_min:
				d2_min = d2
				meilleur = i
	return Vector2(meilleur, sqrt(d2_min))


func _hauteur(c: TrackCurve, x: float, z: float) -> float:
	var trouve := _plus_proche(x, z)
	var i := int(trouve.x)
	var loin := trouve.y
	var e := _echantillons[i]
	var droite := _droites[i]
	# Près de la route, le point le plus proche exactement, projeté sur la
	# courbe : à l'intérieur d'un virage serré, estimer « le long de la route »
	# depuis l'échantillon voisin se trompait de deux mètres, soit un
	# demi-mètre d'altitude dans une côte.
	if loin < c.half_width + 20.0:
		var d := c.distance_of(Vector3(x, e.y, z))
		e = c.position_at(d)
		droite = c.right_at(d)
	var plat := Vector3(droite.x, 0.0, droite.z).normalized()
	var lateral := (Vector3(x, e.y, z) - e).dot(plat)
	var demi := c.half_width
	# La surface de la route, dévers compris, prolongée à plat au-delà du bord
	# (comme les bas-côtés, voir TrackFeature.point).
	var route := e.y + droite.y * clampf(lateral, -demi, demi)
	# Un mètre de marge : au bord extérieur d'un virage, l'écart mesuré depuis
	# l'échantillon voisin est un peu faussé par la courbure.
	var enfonce := lerpf(SOUS_LA_ROUTE, SOUS_LE_BORD, smoothstep(demi + 1.0, demi + 2.5, absf(lateral)))
	var pres := route - enfonce
	# En s'éloignant, les collines.
	# Pas avant d'avoir dépassé les bas-côtés d'une maille : un relief qui
	# monte sous leur bord les percerait en dents de scie.
	var ouvert := smoothstep(demi + 14.0, demi + 70.0, loin)
	var colline := e.y + relief * ouvert * (0.55 + 0.45 * _bruit.get_noise_2d(x, z))
	var h := lerpf(pres, colline, ouvert)
	if _dans_un_trou[i]:
		var creux := 1.0 - smoothstep(demi + 2.0, demi + 18.0, loin)
		h = lerpf(h, e.y - ravin, creux)
	return minf(h, _sous_les_autres_routes(x, z, i, demi))


## Là où le tracé revient sur lui-même (une épingle), le point de route le
## plus proche n'est pas le seul au-dessus duquel passer : une maille entre
## deux branches à des hauteurs différentes percerait la plus basse. On reste
## sous toute route à portée de maille.
func _sous_les_autres_routes(x: float, z: float, deja: int, demi: float) -> float:
	var plafond := INF
	var portee := demi + maille * 1.5
	var centre := _case(x, z)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cle := centre + Vector2i(dx, dz)
			if not _grille.has(cle):
				continue
			for i in (_grille[cle] as PackedInt32Array):
				if absi(i - deja) < 8:
					continue
				var e := _echantillons[i]
				var d2 := (e.x - x) * (e.x - x) + (e.z - z) * (e.z - z)
				if d2 > portee * portee:
					continue
				var droite := _droites[i]
				var plat := Vector3(droite.x, 0.0, droite.z).normalized()
				var lateral := (Vector3(x, e.y, z) - e).dot(plat)
				plafond = minf(plafond, e.y + droite.y * clampf(lateral, -demi, demi) - SOUS_LA_ROUTE)
	return plafond


func _construire(c: TrackCurve, racine: Node3D) -> void:
	_pour = null
	_preparer(c)
	var mini := Vector2(INF, INF)
	var maxi := Vector2(-INF, -INF)
	for e in _echantillons:
		mini = mini.min(Vector2(e.x, e.z))
		maxi = maxi.max(Vector2(e.x, e.z))
	mini -= Vector2.ONE * marge
	maxi += Vector2.ONE * marge
	var colonnes := int(ceil((maxi.x - mini.x) / maille)) + 1
	var lignes := int(ceil((maxi.y - mini.y) / maille)) + 1

	var teintes := FastNoiseLite.new()
	teintes.seed = graine + 7
	teintes.frequency = 0.03
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in lignes:
		for q in colonnes:
			var x := mini.x + q * maille
			var z := mini.y + r * maille
			var h := _hauteur(c, x, z)
			var proche := _plus_proche(x, z)
			var ref := _echantillons[int(proche.x)].y
			# L'herbe varie un peu ; le fond du ravin est de terre et de roche,
			# les sommets un peu plus secs.
			var teinte := couleur.lightened(0.08 * teintes.get_noise_2d(x, z)).darkened(0.06 * maxf(-teintes.get_noise_2d(z, x), 0.0))
			var profondeur := clampf((ref - h - 1.5) / 6.0, 0.0, 1.0)
			teinte = teinte.lerp(Color(0.42, 0.36, 0.3), profondeur)
			var altitude := clampf((h - ref - relief * 0.5) / maxf(relief, 0.01), 0.0, 1.0)
			teinte = teinte.lerp(Color(0.55, 0.6, 0.3), altitude * 0.5)
			outil.set_color(teinte)
			outil.add_vertex(Vector3(x, h, z))
	for r in lignes - 1:
		for q in colonnes - 1:
			var a := r * colonnes + q
			var b := a + 1
			var cc := a + colonnes
			var d := cc + 1
			outil.add_index(a)
			outil.add_index(b)
			outil.add_index(cc)
			outil.add_index(b)
			outil.add_index(d)
			outil.add_index(cc)
	outil.generate_normals()
	var maillage := outil.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	# Tourné dans un sens ou dans l'autre selon le repère : les deux faces.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var affichage := MeshInstance3D.new()
	affichage.mesh = maillage
	affichage.material_override = m
	affichage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(affichage)
