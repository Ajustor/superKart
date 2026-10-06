@tool
class_name TrackTunnel
extends TrackWall

## Un passage sous terre : la route s'enfonce sous une voûte, entre deux
## parois, éclairée de loin en loin par des lampes au plafond. Par-dessus, un
## massif de roche (ou de glace, ou de terre) qu'on voit de l'extérieur, et
## deux portails qui marquent l'entrée et la sortie.
##
## Les parois sont des murs comme les autres (TrackWall) : le kart y glisse,
## les carapaces y rebondissent. La voûte et le massif, eux, ne se touchent
## pas — personne ne saute assez haut pour y cogner.
##
## Pour passer SOUS une autre partie du circuit, c'est le tracé qui descend :
## au moins vingt mètres sous la route du dessus (voir docs/outil-circuits.md),
## et un massif moins haut que cet écart.

## Hauteur de la voûte au-dessus des parois, en mètres.
@export_range(0.5, 10.0, 0.25) var fleche: float = 3.0:
	set(valeur):
		fleche = valeur
		_modifie()

## Épaisseur du massif au-dessus de la voûte, en mètres. Zéro : un tube nu,
## sans montagne par-dessus.
@export_range(0.0, 40.0, 0.5) var montagne: float = 8.0:
	set(valeur):
		montagne = valeur
		_modifie()

@export var couleur_roche: Color = Color(0.42, 0.36, 0.3):
	set(valeur):
		couleur_roche = valeur
		_modifie()

@export var couleur_lampes: Color = Color(1.0, 0.85, 0.5):
	set(valeur):
		couleur_lampes = valeur
		_modifie()

## Mètres entre deux lampes du plafond ; zéro, pas de lampe.
@export_range(0.0, 50.0, 0.5) var espacement_lampes: float = 10.0:
	set(valeur):
		espacement_lampes = valeur
		_modifie()

## Segments de l'arc de la voûte.
const ARC := 10


func _init() -> void:
	longueur = 60.0
	cote = Cote.LES_DEUX
	hauteur = 4.5
	epaisseur = 0.8
	marge = 0.2
	couleur = Color(0.48, 0.42, 0.36)
	couleur_bis = Color(0.4, 0.35, 0.3)


func _validate_property(property: Dictionary) -> void:
	# Un tunnel a toujours ses deux parois.
	if property.name in ["cote", "decalage", "largeur"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Le plafond est-il au-dessus de ce point du tracé ?
func sous_la_voute(distance: float, longueur_tour: float) -> bool:
	return couvre(distance, longueur_tour)


## Les parois font corps avec la voûte : pas de barrières Kenney.
func _en_barrieres() -> bool:
	return false


func _construire(c: TrackCurve, racine: Node3D) -> void:
	super(c, racine)
	var roche := StandardMaterial3D.new()
	roche.vertex_color_use_as_albedo = true
	roche.roughness = 0.95
	roche.cull_mode = BaseMaterial3D.CULL_DISABLED
	var maillage := _voute(c)
	var affichage := MeshInstance3D.new()
	affichage.mesh = maillage
	affichage.material_override = roche
	racine.add_child(affichage)
	if espacement_lampes > 0.0:
		racine.add_child(_lampes(c))


## La demi-largeur intérieure, d'une paroi à l'autre (face extérieure).
func _demi_ouverture(c: TrackCurve) -> float:
	return c.half_width + marge + epaisseur


## La coupe de la voûte : de la paroi gauche à la paroi droite, en arc.
## Rend des couples (écart, hauteur).
func coupe_interieure(c: TrackCurve) -> PackedVector2Array:
	var w := _demi_ouverture(c)
	var points := PackedVector2Array([Vector2(-w, 0.0)])
	for i in ARC + 1:
		var a := PI * (1.0 - float(i) / float(ARC))
		points.append(Vector2(w * cos(a), hauteur + fleche * sin(a)))
	points.append(Vector2(w, 0.0))
	return points


## La même, gonflée du massif : c'est le flanc de la montagne.
func coupe_exterieure(c: TrackCurve) -> PackedVector2Array:
	var w := _demi_ouverture(c)
	var sommet := hauteur + fleche
	var sx := (w + 1.0 + montagne * 1.4) / w
	var sy := (sommet + montagne) / sommet
	var points := PackedVector2Array()
	for p in coupe_interieure(c):
		points.append(Vector2(p.x * sx, p.y * sy))
	return points


func _voute(c: TrackCurve) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dedans := coupe_interieure(c)
	var dehors := coupe_exterieure(c)
	var sections := _sections(2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(debut * 7.0) + 1
	var plafond := couleur.darkened(0.35)
	for i in sections.size() - 1:
		var d0 := sections[i]
		var d1 := sections[i + 1]
		# Le plafond : l'arc seul, sans les parois qui ont leur maillage.
		for j in range(1, dedans.size() - 2):
			outil.set_color(plafond.darkened(0.08 * float((i + j) % 2)))
			TrackWall._quad(outil, _pt(c, d0, dedans[j]), _pt(c, d1, dedans[j]),
				_pt(c, d1, dedans[j + 1]), _pt(c, d0, dedans[j + 1]))
		if montagne <= 0.0:
			continue
		for j in dehors.size() - 1:
			var teinte := couleur_roche.darkened(rng.randf_range(-0.12, 0.18))
			outil.set_color(teinte)
			TrackWall._quad(outil, _pt(c, d0, dehors[j]), _pt(c, d0, dehors[j + 1]),
				_pt(c, d1, dehors[j + 1]), _pt(c, d1, dehors[j]))
	# Les deux portails : la façade entre la voûte et le flanc, à chaque bout,
	# et un encadrement plus clair autour de l'ouverture.
	if montagne > 0.0:
		for d in [debut, debut + longueur]:
			outil.set_color(couleur_roche.darkened(0.15))
			for j in dedans.size() - 1:
				TrackWall._quad(outil, _pt(c, d, dedans[j]), _pt(c, d, dehors[j]),
					_pt(c, d, dehors[j + 1]), _pt(c, d, dedans[j + 1]))
			outil.set_color(couleur.lightened(0.25))
			for j in dedans.size() - 1:
				var a := dedans[j]
				var b := dedans[j + 1]
				var ea := a + (dehors[j] - a).normalized() * 0.9
				var eb := b + (dehors[j + 1] - b).normalized() * 0.9
				TrackWall._quad(outil, _pt(c, d, a, 0.05), _pt(c, d, ea, 0.05),
					_pt(c, d, eb, 0.05), _pt(c, d, b, 0.05))
	outil.generate_normals()
	return outil.commit()


## Un point de la coupe, posé à cette distance. `avance` : un peu en avant
## (ou en arrière, au portail d'entrée) du plan de coupe.
func _pt(c: TrackCurve, d: float, p: Vector2, avance := 0.0) -> Vector3:
	var sens := -1.0 if is_equal_approx(d, debut) else 1.0
	return TrackFeature.point(c, d, p.x, p.y) + c.forward_at(d) * avance * sens


## Les lampes du plafond, en une seule MultiMesh qui brille.
func _lampes(c: TrackCurve) -> MultiMeshInstance3D:
	var lampe := BoxMesh.new()
	lampe.size = Vector3(1.6, 0.18, 0.5)
	var lumiere := StandardMaterial3D.new()
	lumiere.albedo_color = couleur_lampes
	lumiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lampe.material = lumiere
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = lampe
	var n := maxi(int(floor(longueur / espacement_lampes)), 1)
	multi.instance_count = n
	for i in n:
		var d := debut + espacement_lampes * (float(i) + 0.5)
		multi.set_instance_transform(i, Transform3D(c.basis_at(d),
			TrackFeature.point(c, d, 0.0, hauteur + fleche - 0.12)))
	var affichage := MultiMeshInstance3D.new()
	affichage.multimesh = multi
	affichage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return affichage
