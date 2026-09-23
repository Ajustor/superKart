@tool
class_name TrackRamp
extends TrackFeature

## Une vraie rampe, en relief et solide : le kart la monte, et décolle au
## sommet avec la vitesse verticale qu'elle lui a donnée. Plus elle est haute
## et courte, plus l'angle de sortie est raide ; plus on l'aborde vite, plus
## on va loin. Contrairement au tremplin (une zone peinte qui donne une
## impulsion fixe), c'est la géométrie qui fait le saut.
##
## Une rampe au bord d'un TrackGap permet de franchir le vide.

enum Profil {
	## Pente constante : l'angle de sortie est celui de toute la rampe.
	DROIT,
	## Douce au pied, raide au sommet, comme un tremplin de ski : on l'aborde
	## sans choc, et l'angle de sortie est le double de la pente moyenne.
	INCURVE,
}

## Hauteur du sommet au-dessus de la route, en mètres.
@export_range(0.2, 10.0, 0.1) var hauteur: float = 1.8:
	set(valeur):
		hauteur = valeur
		_modifie()

@export var profil: Profil = Profil.INCURVE:
	set(valeur):
		profil = valeur
		_modifie()

@export var couleur: Color = Color(0.2, 0.55, 0.95):
	set(valeur):
		couleur = valeur
		_modifie()


func _init() -> void:
	longueur = 10.0
	largeur = 8.0


## Hauteur de la rampe à cette fraction de sa longueur, de 0 au pied à 1 au
## sommet.
func hauteur_a(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return hauteur * (t * t if profil == Profil.INCURVE else t)


## Angle de sortie au sommet, en degrés : celui qui décide du vol.
func angle_de_sortie() -> float:
	var pente := hauteur / longueur
	if profil == Profil.INCURVE:
		pente *= 2.0
	return rad_to_deg(atan(pente))


## Vitesse verticale donnée à un kart qui quitte le sommet à `vitesse` m/s.
func vitesse_verticale(vitesse: float) -> float:
	return vitesse * sin(deg_to_rad(angle_de_sortie()))


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var materiau := StandardMaterial3D.new()
	materiau.vertex_color_use_as_albedo = true
	materiau.roughness = 0.6
	TrackFeature._poser(racine, _maillage(c), materiau, true)


## Le dessus en pente, les deux flancs, et la face arrière verticale au sommet.
func _maillage(c: TrackCurve) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := decalage - largeur * 0.5
	var r := decalage + largeur * 0.5
	var sections := _sections(0.5)
	var clair := couleur.lightened(0.35)
	for i in sections.size() - 1:
		var d0 := sections[i]
		var d1 := sections[i + 1]
		var h0 := hauteur_a((d0 - debut) / longueur)
		var h1 := hauteur_a((d1 - debut) / longueur)
		var g0 := point(c, d0, g, h0)
		var r0 := point(c, d0, r, h0)
		var g1 := point(c, d1, g, h1)
		var r1 := point(c, d1, r, h1)
		# Des bandes claires tous les mètres : la pente se lit à l'œil.
		outil.set_color(clair if int(floor(d0 - debut)) % 2 == 0 else couleur)
		TrackWall._quad(outil, g0, g1, r1, r0)
		outil.set_color(couleur.darkened(0.3))
		TrackWall._quad(outil, point(c, d0, g, 0.0), point(c, d1, g, 0.0), g1, g0)
		TrackWall._quad(outil, point(c, d1, r, 0.0), point(c, d0, r, 0.0), r0, r1)
	var fin := debut + longueur
	outil.set_color(couleur.darkened(0.45))
	TrackWall._quad(outil, point(c, fin, g, 0.0), point(c, fin, r, 0.0),
		point(c, fin, r, hauteur), point(c, fin, g, hauteur))
	outil.generate_normals()
	return outil.commit()
