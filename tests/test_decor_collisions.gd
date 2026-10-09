extends GutTest

## À hauteur de kart, la collision de chaque décor colle à ce qu'on voit : elle
## ne dépasse pas du modèle de plus de 15 cm, et ne laisse pas de partie
## pleine du modèle sans collision au-delà de 15 cm.
##
## « À hauteur de kart » : la caisse du kart va de 3 à 73 cm. Là où elle
## touche la collision, le modèle doit être à moins de 15 cm, à l'une de ces
## hauteurs ; un rocher plus large au pied qu'à 70 cm l'arrête à son pied,
## pas sur du vide. Et inversement.
##
## Une instance isolée de chaque type, à l'échelle 1, posée loin de tout :
## des rayons horizontaux, parallèles, de quatre côtés et quatre diagonales, à
## 0,1, 0,4 et 0,7 m, contre la collision d'un côté et une copie en trimesh
## du modèle de l'autre.

const TOLERANCE := 0.15
const HAUTEURS := [0.1, 0.4, 0.7]
## La caisse du kart, de son bas à son haut, au-dessus du sol.
const KART_BAS := 0.03
const KART_HAUT := 0.73
const COUCHE_MODELE := 1 << 5
const PORTEE := 30.0
const PAS := 0.1
## Loin de tout ce qu'un autre test aurait laissé.
const ICI := Vector3(5000.0, 0.0, 5000.0)

## Les rayons qui ont vu un modèle : sans eux, le test ne mesurerait rien.
var _vus := 0


func _espace() -> PhysicsDirectSpaceState3D:
	return get_viewport().world_3d.direct_space_state


## Le premier contact sur ce rayon, sur ces couches ; null sinon.
func _touche(depuis: Vector3, vers: Vector3, couches: int) -> Variant:
	var requete := PhysicsRayQueryParameters3D.create(depuis, depuis + vers * PORTEE, couches)
	requete.hit_back_faces = true
	var r := _espace().intersect_ray(requete)
	return r.position if not r.is_empty() else null


## Y a-t-il quelque chose de ces couches à moins de TOLERANCE de ce point,
## à hauteur de kart ?
func _pres(point: Vector3, couches: int) -> bool:
	var colonne := CylinderShape3D.new()
	colonne.radius = TOLERANCE
	colonne.height = KART_HAUT - KART_BAS
	var requete := PhysicsShapeQueryParameters3D.new()
	requete.shape = colonne
	requete.transform = Transform3D(Basis(), Vector3(point.x, ICI.y + (KART_BAS + KART_HAUT) * 0.5, point.z))
	requete.collision_mask = couches
	return not _espace().intersect_shape(requete, 1).is_empty()


## Les écarts du type : combien de rayons heurtent la collision loin du
## modèle (elle dépasse), et le modèle loin de la collision (elle manque).
func _ecarts(quoi: TrackDecor.Objet) -> Vector2i:
	var decor := TrackDecor.new()
	decor.objet = quoi
	var poses: Array[Transform3D] = [Transform3D(Basis(), ICI)]
	var corps := decor.corps_de_collision(poses)
	decor.free()
	if corps == null:
		return Vector2i.ZERO
	var modele := StaticBody3D.new()
	modele.collision_layer = COUCHE_MODELE
	var forme := CollisionShape3D.new()
	var trimesh := TrackDecor.maillage_de(quoi).create_trimesh_shape() as ConcavePolygonShape3D
	trimesh.backface_collision = true
	forme.shape = trimesh
	modele.add_child(forme)
	modele.position = ICI
	add_child(modele)
	add_child(corps)
	# Le monde à part doit voir ses corps avant qu'on y lance des rayons.
	await wait_physics_frames(1)
	var boite := TrackDecor.maillage_de(quoi).get_aabb()
	var rayon := maxf(Vector2(boite.position.x, boite.position.z).length(),
		Vector2(boite.end.x, boite.end.z).length()) + 1.0
	var depasse := 0
	var manque := 0
	var vus := 0
	for k in 8:
		var angle := TAU * float(k) / 8.0
		var vers := Vector3(cos(angle), 0.0, sin(angle))
		var travers := Vector3(-vers.z, 0.0, vers.x)
		for h: float in HAUTEURS:
			var l := -rayon
			while l <= rayon:
				var depuis := ICI - vers * (rayon + 1.0) + travers * l + Vector3.UP * h
				var pm: Variant = _touche(depuis, vers, COUCHE_MODELE)
				var pc: Variant = _touche(depuis, vers, Kart.COUCHE_DECOR)
				if pm != null:
					vus += 1
					if not _pres(pm, Kart.COUCHE_DECOR):
						manque += 1
				if pc != null and not _pres(pc, COUCHE_MODELE):
					depasse += 1
				l += PAS
	modele.free()
	corps.free()
	_vus += vus
	return Vector2i(depasse, manque)


func test_la_collision_colle_au_modele_a_hauteur_de_kart() -> void:
	await wait_physics_frames(1)
	var fautifs := []
	for nom in TrackDecor.Objet.keys():
		var quoi: TrackDecor.Objet = TrackDecor.Objet[nom]
		if TrackDecor.forme_de(quoi).is_empty():
			continue
		var e: Vector2i = await _ecarts(quoi)
		if e != Vector2i.ZERO:
			fautifs.append("%s (%d rayons où elle dépasse, %d où elle manque)" % [nom, e.x, e.y])
	assert_gt(_vus, 1000, "les rayons voient les modèles")
	for f in fautifs:
		print("décor décollé : ", f)
	assert_eq(fautifs.size(), 0, "collisions décollées du modèle : %s" % ", ".join(fautifs))

