extends GutTest

## La collision du décor colle à ce qu'on voit à hauteur de kart, EN MÈTRES,
## à toutes les échelles où les circuits posent chaque objet, et pour les
## rangées enterrées (hauteur < 0) : là où le kart passe vraiment.
##
## Une rangée pose ses objets à `echelle` × 0,85 à 1,15 (un objet seul : à
## `echelle` tout juste), `hauteur` mètres au-dessus du sol. Pour chaque type
## qui se touche : l'instance la plus petite et la plus grande des circuits,
## et la rangée la plus enterrée s'il y en a une.
##
## Mesure, sur la tranche de la caisse (5 à 73 cm au-dessus du sol) :
## - des rayons horizontaux parallèles, 16 directions, tous les 5 cm ; sur
##   chacun, le premier contact à l'une des hauteurs de la tranche (la caisse
##   les touche toutes à la fois), contre la collision d'un côté et une copie
##   en trimesh du modèle de l'autre ;
## - « dépasse » : un contact de collision à plus de 15 cm du plus proche
##   contact visible (des rayons verticaux vérifient : une feuille à plat
##   échappe aux rayons horizontaux) ; « manque » : un contact visible à plus
##   de 15 cm de la collision ;
## - « trop haute » : un rebord bas et large (moins de 30 cm de haut sur plus
##   de 25 cm : une jupe, une dalle, le pied d'un panneau) ne porte pas un
##   mur. Là où la collision touche un tel rebord, elle ne monte pas plus de
##   15 cm au-dessus de lui : la jupe de 20 cm d'un bloc de sculk n'est pas un
##   mur de 1,2 m. Un flanc en pente (un rocher, un cône) remonte au-dessus de
##   30 cm en moins de 25 cm : ce n'est pas un rebord.

const TOLERANCE := 0.15
const KART_BAS := 0.05
const KART_HAUT := 0.73
## En dessous, ce qu'on voit n'est qu'un rebord.
const LEVRE := 0.3
## La largeur d'un rebord : la tolérance, et les 10 cm qu'une enveloppe
## convexe peut laisser entre deux morceaux (TrackDecor.CREUX).
const LARGEUR_DE_REBORD := 0.25
const N_HAUTEURS := 12
const DIRECTIONS := 16
const PAS := 0.05
const COUCHE_MODELE := 1 << 6
## Loin de tout ce qu'un autre test aurait laissé.
const ICI := Vector3(-6000.0, 0.0, 6000.0)
const DECOR := "res://scripts/track/features/track_decor.gd"


func _espace() -> PhysicsDirectSpaceState3D:
	return get_viewport().world_3d.direct_space_state


## Les rangées solides des circuits : [objet, echelle, hauteur, espacement].
func _rangees() -> Array:
	var rangees := []
	for info in TrackCatalog.PISTES + TrackCatalog.ARENES:
		var etat := info.scene.get_state()
		for n in etat.get_node_count():
			var proprietes := {}
			for p in etat.get_node_property_count(n):
				proprietes[etat.get_node_property_name(n, p)] = etat.get_node_property_value(n, p)
			var script: Variant = proprietes.get(&"script")
			if not (script is Script) or (script as Script).resource_path != DECOR:
				continue
			if not proprietes.get(&"solide", true):
				continue
			var objet: int = proprietes.get(&"objet", TrackDecor.Objet.PALMIER)
			if TrackDecor.flotte(objet) or TrackDecor.forme_de(objet).is_empty():
				continue
			rangees.append([objet, float(proprietes.get(&"echelle", 1.0)), float(proprietes.get(&"hauteur", 0.0)),
				float(proprietes.get(&"espacement", 20.0))])
	return rangees


## Par type : les cas à mesurer, [taille, hauteur, nom].
func _cas() -> Dictionary:
	var cas := {}
	var bornes := {}
	for r: Array in _rangees():
		var objet: int = r[0]
		var echelle: float = r[1]
		var hauteur: float = r[2]
		var petit := echelle * (0.85 if r[3] > 0.0 else 1.0)
		var grand := echelle * (1.15 if r[3] > 0.0 else 1.0)
		var b: Dictionary = bornes.get(objet, {petit = INF, grand = 0.0, enterre = 0.0, enterre_taille = 1.0})
		b.petit = minf(b.petit, petit)
		b.grand = maxf(b.grand, grand)
		if hauteur < b.enterre:
			b.enterre = hauteur
			b.enterre_taille = grand
		bornes[objet] = b
	for objet: int in bornes:
		var b: Dictionary = bornes[objet]
		var liste := [[b.petit, 0.0, "×%.2f" % b.petit]]
		if b.grand > b.petit:
			liste.append([b.grand, 0.0, "×%.2f" % b.grand])
		if b.enterre < 0.0:
			liste.append([b.enterre_taille, b.enterre, "×%.2f enterré de %.1f m" % [b.enterre_taille, -b.enterre]])
		cas[objet] = liste
	return cas


## Le premier contact sur ce segment, sur ces couches ; {} sinon.
func _rayon(depuis: Vector3, vers: Vector3, couches: int) -> Dictionary:
	var requete := PhysicsRayQueryParameters3D.create(depuis, vers, couches)
	requete.hit_back_faces = true
	return _espace().intersect_ray(requete)


## Plus proche voisin dans un nuage de points 2D.
class _Nuage:
	const CASE := 0.25
	var cases := {}
	var vide := true

	func ajouter(p: Vector2) -> void:
		vide = false
		var k := Vector2i(floori(p.x / CASE), floori(p.y / CASE))
		if not cases.has(k):
			cases[k] = PackedVector2Array()
		var liste: PackedVector2Array = cases[k]
		liste.append(p)
		cases[k] = liste

	func distance(p: Vector2) -> float:
		if vide:
			return INF
		var k := Vector2i(floori(p.x / CASE), floori(p.y / CASE))
		var mieux := INF
		for r in 400:
			if mieux < float(r - 1) * CASE:
				break
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if maxi(absi(dx), absi(dz)) != r:
						continue
					var c := k + Vector2i(dx, dz)
					if cases.has(c):
						for q: Vector2 in cases[c]:
							mieux = minf(mieux, p.distance_to(q))
		return mieux


## Les points d'un disque, tous les 5 cm.
func _disque(p: Vector2, portee: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var n := ceili(portee / 0.05)
	for dx in range(-n, n + 1):
		for dz in range(-n, n + 1):
			var q := p + Vector2(dx, dz) * 0.05
			if q.distance_to(p) <= portee:
				points.append(q)
	return points


## Le modèle est-il là, à hauteur de caisse, à moins de `portee` de ce point ?
## Des rayons verticaux : ils voient ce qu'un rayon horizontal rate entre deux
## hauteurs (une feuille à plat, le dessus d'une dalle).
func _modele_pres(p: Vector2, portee: float) -> bool:
	for q in _disque(p, portee):
		if not _rayon(Vector3(q.x, ICI.y + KART_HAUT, q.y), Vector3(q.x, ICI.y + KART_BAS, q.y), COUCHE_MODELE).is_empty():
			return true
	return false


## Le plus haut du modèle à moins de `portee` de ce point, vu d'en haut (un
## toit compte : sous lui, ce n'est pas un rebord), au-dessus du sol. -INF :
## rien.
func _haut_du_modele(p: Vector2, portee: float) -> float:
	var haut := -INF
	for q in _disque(p, portee):
		var r := _rayon(Vector3(q.x, ICI.y + 100.0, q.y), Vector3(q.x, ICI.y + KART_BAS, q.y), COUCHE_MODELE)
		if not r.is_empty():
			haut = maxf(haut, r.position.y - ICI.y)
	return haut


## Les écarts d'un cas : [dépasse, manque, trop haute] en mètres, et où.
func _ecarts(objet: int, taille: float, hauteur: float) -> Array:
	var decor := TrackDecor.new()
	decor.objet = objet as TrackDecor.Objet
	decor.hauteur = hauteur
	# Le pied de l'objet, `hauteur` sous (ou sur) le sol ; le sol est à ICI.y.
	var pose := Transform3D(Basis().scaled(Vector3.ONE * taille), ICI + Vector3.UP * hauteur)
	var poses: Array[Transform3D] = [pose]
	var corps := decor.corps_de_collision(poses)
	decor.free()
	var faces := pose * TrackDecor.maillage_de(objet as TrackDecor.Objet).get_faces()
	var modele := StaticBody3D.new()
	modele.collision_layer = COUCHE_MODELE
	modele.collision_mask = 0
	var trimesh := ConcavePolygonShape3D.new()
	trimesh.backface_collision = true
	trimesh.set_faces(faces)
	var forme := CollisionShape3D.new()
	forme.shape = trimesh
	modele.add_child(forme)
	add_child(modele)
	if corps != null:
		add_child(corps)
	await wait_physics_frames(1)
	# L'étendue à mesurer : la collision et le modèle sur la tranche.
	var etendue := 0.0
	var y_bas := ICI.y + KART_BAS
	var y_haut := ICI.y + KART_HAUT
	for i in range(0, faces.size(), 3):
		var lo := minf(faces[i].y, minf(faces[i + 1].y, faces[i + 2].y))
		var hi := maxf(faces[i].y, maxf(faces[i + 1].y, faces[i + 2].y))
		if hi < y_bas or lo > y_haut:
			continue
		for j in 3:
			etendue = maxf(etendue, Vector2(faces[i + j].x - ICI.x, faces[i + j].z - ICI.z).length())
	if corps != null:
		for cs in corps.get_children():
			var s := (cs as CollisionShape3D).shape
			var r := 0.0
			if s is ConvexPolygonShape3D:
				for p in (s as ConvexPolygonShape3D).points:
					r = maxf(r, Vector2(p.x, p.z).length())
			elif s is CylinderShape3D:
				r = (s as CylinderShape3D).radius
			elif s is BoxShape3D:
				r = Vector2((s as BoxShape3D).size.x, (s as BoxShape3D).size.z).length() * 0.5
			etendue = maxf(etendue, r + Vector2((cs as Node3D).position.x - ICI.x, (cs as Node3D).position.z - ICI.z).length())
	etendue += 0.3
	# Les rayons horizontaux : sur chaque ligne, le premier contact sur toute
	# la tranche ; pour la collision, aussi la hauteur de ce premier contact
	# (la plus haute des hauteurs qui le touchent au même endroit).
	var vus := _Nuage.new()
	var touches := _Nuage.new()
	var vus_haut := _Nuage.new()
	var lignes := []
	for k in DIRECTIONS:
		var a := TAU * float(k) / float(DIRECTIONS)
		var vers := Vector3(cos(a), 0.0, sin(a))
		var travers := Vector3(-vers.z, 0.0, vers.x)
		var l := -etendue
		while l <= etendue:
			var premier_m := {}
			var premier_c := {}
			var contacts_c := []
			for i in N_HAUTEURS:
				var y := lerpf(y_bas, y_haut, float(i) / float(N_HAUTEURS - 1))
				var base := Vector3(ICI.x, y, ICI.z) + travers * l
				var depuis := base - vers * (etendue + 0.5)
				var jusqu := base + vers * (etendue + 0.5)
				var m := _rayon(depuis, jusqu, COUCHE_MODELE)
				if not m.is_empty():
					var pm := Vector2(m.position.x, m.position.z)
					if y - ICI.y >= LEVRE:
						vus_haut.ajouter(pm)
					if premier_m.is_empty() or depuis.distance_to(m.position) < premier_m.t:
						premier_m = {p = pm, t = depuis.distance_to(m.position)}
				var c := _rayon(depuis, jusqu, Kart.COUCHE_DECOR)
				if not c.is_empty():
					var t := depuis.distance_to(c.position)
					contacts_c.append([t, y - ICI.y])
					if premier_c.is_empty() or t < premier_c.t:
						premier_c = {p = Vector2(c.position.x, c.position.z), t = t}
			if not premier_m.is_empty():
				vus.ajouter(premier_m.p)
			if not premier_c.is_empty():
				touches.ajouter(premier_c.p)
				premier_c.haut = 0.0
				for ct: Array in contacts_c:
					if ct[0] <= premier_c.t + 0.02:
						premier_c.haut = maxf(premier_c.haut, ct[1])
			lignes.append([premier_m, premier_c])
			l += PAS
	var depasse := 0.0
	var manque := 0.0
	var trop_haute := 0.0
	var ou := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var centre := Vector2(ICI.x, ICI.z)
	var hauts := {}
	for ligne: Array in lignes:
		var m: Dictionary = ligne[0]
		var c: Dictionary = ligne[1]
		if not c.is_empty() and (m.is_empty() or m.t > c.t + 0.005):
			var e := minf(vus.distance(c.p), INF if m.is_empty() else m.t - c.t)
			if e > TOLERANCE and _modele_pres(c.p, TOLERANCE):
				e = TOLERANCE
			if e > depasse:
				depasse = e
				ou[0] = c.p - centre
		if not m.is_empty() and (c.is_empty() or c.t > m.t + 0.005):
			var e := minf(touches.distance(m.p), INF if c.is_empty() else c.t - m.t)
			if e > manque:
				manque = e
				ou[1] = m.p - centre
		# Un mur au bord d'un rebord : la collision monte haut là où, de près,
		# on ne voit qu'un rebord bas et large.
		if not c.is_empty() and c.haut > LEVRE + TOLERANCE and vus_haut.distance(c.p) > TOLERANCE:
			var cle := Vector2i(floori(c.p.x / 0.05), floori(c.p.y / 0.05))
			if not hauts.has(cle):
				hauts[cle] = _haut_du_modele(c.p, LARGEUR_DE_REBORD)
			var visible: float = hauts[cle]
			if visible > -INF and visible < LEVRE and c.haut - visible > trop_haute:
				trop_haute = c.haut - visible
				ou[2] = c.p - centre
	modele.free()
	if corps != null:
		corps.free()
	return [depasse, manque, trop_haute, ou]


func test_la_collision_colle_au_modele_a_toutes_les_echelles() -> void:
	await wait_physics_frames(1)
	var cas := _cas()
	assert_gt(cas.size(), 30, "les circuits posent des dizaines de types solides")
	var fautifs := []
	var lignes := []
	for objet: int in cas:
		for c: Array in cas[objet]:
			var e: Array = await _ecarts(objet, c[0], c[1])
			var nom := "%s %s" % [TrackDecor.Objet.keys()[objet], c[2]]
			lignes.append("%-38s dépasse %5.2f  manque %5.2f  trop haute %5.2f" % [nom, e[0], e[1], e[2]])
			if e[0] > TOLERANCE or e[1] > TOLERANCE or e[2] > TOLERANCE:
				fautifs.append("%s (dépasse %.2f, manque %.2f, trop haute %.2f)" % [nom, e[0], e[1], e[2]])
				lignes.append("    où, par rapport au pied : dépasse %s, manque %s, trop haute %s" % e[3])
	for l in lignes:
		print("décor à l'échelle : ", l)
	assert_eq(fautifs.size(), 0, "%d cas décollés du modèle : %s" % [fautifs.size(), ", ".join(fautifs)])
