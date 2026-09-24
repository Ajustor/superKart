class_name Miroir
extends RefCounted

## Le mode miroir : le circuit retourné gauche-droite, comme dans Mario Kart.
## Les virages à gauche deviennent des virages à droite ; le sens de la
## course, lui, ne change pas.
##
## Tout part de la courbe : ses points passent de x à -x, ses dévers changent
## de signe. Ce qui se place à côté de la route se place par écart latéral à
## la courbe ; un miroir inverse le repère (la droite du tracé devient sa
## gauche), donc chaque écart change de signe, et les murs collés à un bord
## passent à l'autre. Le reste (lave, eau, lumière) est retourné en x.


## La courbe retournée : une copie, la ressource d'origine sert aux autres.
static func courbe(source: Curve3D) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = source.bake_interval
	for i in source.point_count:
		c.add_point(_retourner(source.get_point_position(i)),
			_retourner(source.get_point_in(i)), _retourner(source.get_point_out(i)))
		c.set_point_tilt(i, -source.get_point_tilt(i))
	return c


static func _retourner(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## Retourne un circuit pas encore entré dans l'arbre : sa courbe, ses
## éléments, et ses nœuds de décor.
static func appliquer(piste: Track) -> void:
	piste.curve = courbe(piste.curve)
	for enfant in piste.get_children():
		if enfant is TrackFeature:
			_retourner_element(enfant as TrackFeature)
		elif enfant is Path3D:
			(enfant as Path3D).curve = piste.curve
		elif enfant is Node3D:
			var n := enfant as Node3D
			var t := n.transform
			# x → -x de part et d'autre : position retournée, orientation
			# retournée sans changer le sens des faces (déterminant positif).
			var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
			n.transform = Transform3D(m * t.basis * m, _retourner(t.origin))


static func _retourner_element(e: TrackFeature) -> void:
	e.decalage = -e.decalage
	if e is TrackWall:
		var mur := e as TrackWall
		match mur.cote:
			TrackWall.Cote.GAUCHE:
				mur.cote = TrackWall.Cote.DROITE
			TrackWall.Cote.DROITE:
				mur.cote = TrackWall.Cote.GAUCHE
