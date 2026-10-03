class_name AtelierPieces
extends RefCounted

## La forme de chaque pièce du garage (ModeleKart) : des formes simples
## assemblées en une seule maillage à couleurs de sommets, comme les pilotes.
## Une carrosserie ou un aileron prend la couleur du kart (`teinte`) là où il
## le faut ; les roues ont leurs propres couleurs.
##
## Les carrosseries et les ailerons se posent dans le repère de la caisse
## (Body) : le plancher y est à 0,3 m, le nez finit à 1,07 m devant (z
## négatif), le moteur à 0,84 m derrière, le pilote est assis en (0 ; 0,44 ;
## 0,17). Les roues se dessinent dans le repère d'un cylindre debout : le nœud
## Tire de la scène les couche sur le côté. Leurs deux faces se voient — une
## à gauche du kart, l'autre à droite —, les décors vont donc des deux côtés.

const BLANC := Color(0.93, 0.94, 0.96)
const SOMBRE := Color(0.14, 0.14, 0.16)
const CHROME := Color(0.8, 0.81, 0.84)
const OR := Color(1.0, 0.8, 0.25)
const ROUGE := Color(0.85, 0.15, 0.12)
const JAUNE := Color(1.0, 0.85, 0.15)


static func _b(taille: Vector3) -> BoxMesh:
	return Personnage._boite(taille)


static func _c(bas: float, haut: float, hauteur: float, cotes: int = 12) -> CylinderMesh:
	return Personnage._cylindre(bas, haut, hauteur, cotes)


static func _s(rayon: float) -> SphereMesh:
	return Personnage._boule(rayon)


static func _g(rayon: float, longueur: float) -> CapsuleMesh:
	return Personnage._gelule(rayon, longueur)


static func _t(interieur: float, exterieur: float) -> TorusMesh:
	return Personnage._anneau(interieur, exterieur)


# --- Carrosseries ----------------------------------------------------------------

static func carrosserie(a: Personnage.Atelier, teinte: Color, i: int) -> void:
	var fonce := teinte.darkened(0.45)
	match i:
		ModeleKart.STANDARD:
			a.ajouter(_b(Vector3(0.7, 0.08, 0.08)), Vector3(0, 0.28, -1.1), BLANC)
		ModeleKart.FUSEE:
			# Un nez en ogive, deux dérives, deux tuyères.
			a.ajouter(_c(0.2, 0.02, 0.45), Vector3(0, 0.34, -1.28), teinte, Vector3(-90, 0, 0))
			for x in [-0.3, 0.3]:
				a.ajouter(_b(Vector3(0.04, 0.3, 0.3)), Vector3(x, 0.55, 0.72), teinte, Vector3(20, 0, 0))
				a.ajouter(_c(0.06, 0.07, 0.16), Vector3(x * 0.4, 0.5, 0.9), SOMBRE, Vector3(90, 0, 0))
		ModeleKart.PLUME:
			for x in [-0.58, 0.58]:
				a.ajouter(_b(Vector3(0.3, 0.02, 0.5)), Vector3(x, 0.42, 0.0), BLANC, Vector3(0, 0, -8.0 * signf(x)))
			a.ajouter(_t(0.26, 0.3), Vector3(0, 0.62, 0.42), CHROME, Vector3(90, 0, 0), Vector3(1, 1, 1.4))
		ModeleKart.DERIVEUR:
			for x in [-0.5, 0.5]:
				a.ajouter(_b(Vector3(0.08, 0.1, 1.4)), Vector3(x, 0.24, 0.0), teinte)
			a.ajouter(_b(Vector3(0.9, 0.03, 0.25)), Vector3(0, 0.24, -1.05), SOMBRE)
		ModeleKart.COSTAUD:
			for x in [-0.25, 0.25]:
				a.ajouter(_c(0.03, 0.03, 0.3, 8), Vector3(x, 0.42, -1.12), CHROME)
			a.ajouter(_c(0.035, 0.035, 0.62, 8), Vector3(0, 0.56, -1.12), CHROME, Vector3(0, 0, 90))
			a.ajouter(_c(0.035, 0.035, 0.62, 8), Vector3(0, 0.36, -1.14), CHROME, Vector3(0, 0, 90))
			for x in [-0.55, 0.55]:
				a.ajouter(_b(Vector3(0.06, 0.25, 0.7)), Vector3(x, 0.38, 0.0), SOMBRE)
		ModeleKart.BUGGY:
			for x in [-0.34, 0.34]:
				for z in [-0.12, 0.5]:
					a.ajouter(_c(0.025, 0.025, 0.72, 8), Vector3(x, 0.74, z), SOMBRE)
				a.ajouter(_c(0.025, 0.025, 0.62, 8), Vector3(x, 1.1, 0.19), SOMBRE, Vector3(90, 0, 0))
			for z in [-0.12, 0.5]:
				a.ajouter(_c(0.025, 0.025, 0.7, 8), Vector3(0, 1.1, z), SOMBRE, Vector3(0, 0, 90))
			for x in [-0.18, 0.18]:
				a.ajouter(_s(0.06), Vector3(x, 1.14, -0.14), Color(1.0, 0.92, 0.55))
			a.ajouter(_b(Vector3(0.8, 0.12, 0.1)), Vector3(0, 0.3, -1.12), teinte)
		ModeleKart.BAIGNOIRE:
			# Une baignoire émaillée sur pieds de lion, un canard sur le nez,
			# de la mousse sur les bords.
			var email := Color(0.97, 0.97, 0.99)
			for x in [-0.44, 0.44]:
				a.ajouter(_b(Vector3(0.07, 0.3, 1.25)), Vector3(x, 0.5, 0.12), email)
			a.ajouter(_b(Vector3(0.95, 0.3, 0.07)), Vector3(0, 0.5, -0.5), email)
			a.ajouter(_b(Vector3(0.95, 0.36, 0.07)), Vector3(0, 0.53, 0.74), email)
			a.ajouter(_b(Vector3(0.85, 0.04, 1.15)), Vector3(0, 0.37, 0.12), teinte)
			for x in [-0.4, 0.4]:
				for z in [-0.42, 0.66]:
					a.ajouter(_s(0.06), Vector3(x, 0.3, z), OR)
			a.ajouter(_c(0.03, 0.03, 0.22, 8), Vector3(0.3, 0.7, 0.74), CHROME)
			a.ajouter(_c(0.03, 0.03, 0.14, 8), Vector3(0.3, 0.8, 0.68), CHROME, Vector3(90, 0, 0))
			for k in 9:
				var x := -0.42 + 0.84 * fmod(k * 0.37, 1.0)
				var z := -0.45 + 1.15 * fmod(k * 0.61, 1.0)
				a.ajouter(_s(0.05 + 0.02 * (k % 3)), Vector3(x, 0.66, z), Color(0.88, 0.95, 1.0))
			# Le canard.
			a.ajouter(_s(0.1), Vector3(0, 0.48, -0.86), JAUNE, Vector3.ZERO, Vector3(1, 0.8, 1.2))
			a.ajouter(_s(0.065), Vector3(0, 0.6, -0.92), JAUNE)
			a.ajouter(_b(Vector3(0.06, 0.025, 0.07)), Vector3(0, 0.59, -0.99), Color(1.0, 0.5, 0.1))
			for x in [-0.03, 0.03]:
				a.ajouter(_s(0.012), Vector3(x, 0.625, -0.975), SOMBRE)
		ModeleKart.CADDIE:
			# Un panier en fil de fer et sa poignée rouge.
			var fil := CHROME
			for x in [-0.46, 0.46]:
				for k in 7:
					a.ajouter(_c(0.012, 0.012, 0.5, 6), Vector3(x, 0.58, -0.6 + k * 0.22), fil)
				for y in [0.42, 0.6, 0.82]:
					a.ajouter(_c(0.014, 0.014, 1.34, 6), Vector3(x, y, 0.06), fil, Vector3(90, 0, 0))
			for k in 5:
				a.ajouter(_c(0.012, 0.012, 0.5, 6), Vector3(-0.36 + k * 0.18, 0.58, -0.6), fil)
			for y in [0.42, 0.6, 0.82]:
				a.ajouter(_c(0.014, 0.014, 0.92, 6), Vector3(0, y, -0.6), fil, Vector3(0, 0, 90))
			for x in [-0.4, 0.4]:
				a.ajouter(_c(0.018, 0.018, 0.45, 6), Vector3(x, 0.95, 0.78), fil, Vector3(-30, 0, 0))
			a.ajouter(_c(0.035, 0.035, 0.86, 10), Vector3(0, 1.14, 0.9), ROUGE, Vector3(0, 0, 90))
			a.ajouter(_b(Vector3(0.3, 0.2, 0.02)), Vector3(0, 0.55, -0.62), teinte)
		ModeleKart.SOUCOUPE:
			# Un disque à hublots lumineux et un halo vert dessous.
			a.ajouter(_c(0.95, 0.75, 0.1, 24), Vector3(0, 0.36, 0.05), CHROME)
			a.ajouter(_c(0.75, 0.95, 0.06, 24), Vector3(0, 0.28, 0.05), teinte)
			a.ajouter(_c(0.45, 0.45, 0.02, 20), Vector3(0, 0.24, 0.05), Color(0.4, 1.0, 0.5))
			for k in 12:
				var angle := TAU * k / 12.0
				a.ajouter(_s(0.04), Vector3(cos(angle) * 0.86, 0.36, 0.05 + sin(angle) * 0.86),
					JAUNE if k % 2 == 0 else Color(0.4, 1.0, 0.6))
			a.ajouter(_c(0.015, 0.015, 0.35, 6), Vector3(0, 0.95, 0.5), SOMBRE)
			a.ajouter(_s(0.05), Vector3(0, 1.13, 0.5), Color(0.4, 1.0, 0.5))
		ModeleKart.CITROUILLE:
			# Un potiron pour capot, côtes et tige, et des volutes dorées.
			var orange := Color(0.98, 0.55, 0.12)
			for k in 5:
				var x := -0.28 + k * 0.14
				a.ajouter(_s(0.22), Vector3(x, 0.5, -0.66), orange, Vector3.ZERO, Vector3(0.75, 1.0, 1.3))
			a.ajouter(_c(0.035, 0.05, 0.16, 8), Vector3(0, 0.78, -0.66), Color(0.3, 0.55, 0.15), Vector3(10, 0, 0))
			a.ajouter(_t(0.05, 0.08), Vector3(0.12, 0.72, -0.6), Color(0.3, 0.6, 0.2), Vector3(70, 0, 0))
			for x in [-0.52, 0.52]:
				a.ajouter(_t(0.12, 0.15), Vector3(x, 0.45, 0.2), OR, Vector3(0, 0, 90))
				a.ajouter(_c(0.02, 0.02, 1.3, 6), Vector3(x, 0.62, 0.1), OR, Vector3(90, 0, 0))
			a.ajouter(_t(0.14, 0.17), Vector3(0, 0.6, 0.82), OR, Vector3(90, 0, 0))
		ModeleKart.REQUIN:
			# Un aileron dorsal, une queue, un museau à dents.
			var gris := Color(0.6, 0.65, 0.7)
			a.ajouter(_b(Vector3(0.05, 0.5, 0.45)), Vector3(0, 0.85, 0.55), teinte, Vector3(32, 0, 0))
			a.ajouter(_b(Vector3(0.05, 0.4, 0.22)), Vector3(0, 0.66, 1.0), teinte, Vector3(40, 0, 0))
			a.ajouter(_b(Vector3(0.05, 0.32, 0.2)), Vector3(0, 0.36, 1.0), teinte, Vector3(-40, 0, 0))
			a.ajouter(_s(0.24), Vector3(0, 0.38, -1.02), gris, Vector3.ZERO, Vector3(1.3, 0.7, 1.4))
			for k in 7:
				var x := -0.2 + k * 0.066
				a.ajouter(_b(Vector3(0.035, 0.05, 0.03)), Vector3(x, 0.31, -1.29 + absf(x) * 0.4), BLANC)
			for x in [-0.2, 0.2]:
				a.ajouter(_s(0.035), Vector3(x, 0.46, -1.1), SOMBRE)
				a.ajouter(_b(Vector3(0.3, 0.03, 0.18)), Vector3(x * 2.6, 0.32, -0.3), teinte, Vector3(0, 0, -20.0 * signf(x)))
		ModeleKart.CHRONOMOBILE:
			# Inox brossé, portes papillon, bandes bleues et le condensateur
			# qui luit à l'arrière.
			var inox := Color(0.72, 0.74, 0.77)
			var bleu := Color(0.35, 0.75, 1.0)
			for x in [-0.5, 0.5]:
				a.ajouter(_b(Vector3(0.08, 0.24, 1.5)), Vector3(x, 0.38, 0.0), inox)
				a.ajouter(_b(Vector3(0.09, 0.03, 1.4)), Vector3(x, 0.28, 0.0), bleu)
				a.ajouter(_b(Vector3(0.45, 0.03, 0.55)), Vector3(x * 1.15, 0.78, 0.05), inox,
					Vector3(0, 0, 55.0 * signf(x)))
			a.ajouter(_b(Vector3(0.7, 0.06, 0.4)), Vector3(0, 0.4, -0.95), inox, Vector3(8, 0, 0))
			a.ajouter(_b(Vector3(0.5, 0.18, 0.04)), Vector3(0, 0.55, 0.86), SOMBRE)
			for angle in [0.0, 120.0, 240.0]:
				a.ajouter(_b(Vector3(0.025, 0.09, 0.02)), Vector3(0, 0.55, 0.89) + Vector3(sin(deg_to_rad(angle)),
					cos(deg_to_rad(angle)), 0) * 0.045, Color(1.0, 0.95, 0.6), Vector3(0, 0, -angle))
			for x in [-0.4, 0.4]:
				a.ajouter(_b(Vector3(0.14, 0.05, 0.03)), Vector3(x, 0.42, 0.78), ROUGE)
		ModeleKart.HOT_DOG:
			# Deux moitiés de pain pour flancs, la saucisse en nez, la moutarde.
			var pain := Color(0.9, 0.68, 0.38)
			for x in [-0.5, 0.5]:
				a.ajouter(_g(0.17, 1.7), Vector3(x, 0.42, 0.0), pain, Vector3(90, 0, 0))
			a.ajouter(_g(0.13, 1.0), Vector3(0, 0.4, -0.85), Color(0.75, 0.28, 0.18), Vector3(90, 0, 0))
			for k in 6:
				a.ajouter(_b(Vector3(0.12, 0.025, 0.03)), Vector3(0.04 * (1 - 2 * (k % 2)), 0.53, -1.1 + k * 0.09),
					JAUNE, Vector3(0, 35.0 * (1 - 2 * (k % 2)), 0))
			a.ajouter(_b(Vector3(0.1, 0.02, 0.03)), Vector3(0, 0.535, -0.62), ROUGE)
		ModeleKart.TRACTEUR:
			# Un capot, un pot d'échappement, des garde-boue et deux phares.
			a.ajouter(_b(Vector3(0.55, 0.36, 0.62)), Vector3(0, 0.55, -0.7), teinte)
			a.ajouter(_b(Vector3(0.5, 0.28, 0.03)), Vector3(0, 0.53, -1.02), SOMBRE)
			for k in 4:
				a.ajouter(_b(Vector3(0.46, 0.02, 0.035)), Vector3(0, 0.45 + k * 0.06, -1.035), CHROME)
			a.ajouter(_c(0.045, 0.045, 0.55, 10), Vector3(0.18, 0.95, -0.58), SOMBRE)
			a.ajouter(_c(0.06, 0.05, 0.05, 10), Vector3(0.18, 1.24, -0.58), SOMBRE)
			for x in [-0.57, 0.57]:
				a.ajouter(_b(Vector3(0.28, 0.05, 0.5)), Vector3(x, 0.66, 0.62), teinte)
				a.ajouter(_b(Vector3(0.28, 0.2, 0.05)), Vector3(x, 0.56, 0.88), teinte)
			for x in [-0.2, 0.2]:
				a.ajouter(_s(0.06), Vector3(x, 0.66, -1.03), Color(1.0, 0.95, 0.6))
			a.ajouter(_b(Vector3(0.6, 0.06, 0.12)), Vector3(0, 0.28, -1.1), JAUNE)
		ModeleKart.CHAUVE_SOURIS:
			# Noir mat, un long nez, des ailerons en ailes de chauve-souris,
			# l'emblème jaune et la turbine qui rougeoie.
			var noir := Color(0.08, 0.08, 0.1)
			a.ajouter(_b(Vector3(0.36, 0.12, 0.6)), Vector3(0, 0.34, -1.2), noir)
			for x in [-1.0, 1.0]:
				a.ajouter(_b(Vector3(0.05, 0.42, 0.55)), Vector3(x * 0.42, 0.66, 0.72), noir, Vector3(-25, 0, 22.0 * x))
				a.ajouter(_b(Vector3(0.05, 0.16, 0.3)), Vector3(x * 0.52, 0.42, -0.8), noir, Vector3(0, 0, 25.0 * x))
			a.ajouter(_s(0.11), Vector3(0, 0.41, -1.05), JAUNE, Vector3.ZERO, Vector3(1.3, 0.3, 0.8))
			a.ajouter(_b(Vector3(0.16, 0.03, 0.06)), Vector3(0, 0.44, -1.05), noir)
			a.ajouter(_c(0.13, 0.13, 0.12, 14), Vector3(0, 0.48, 0.9), noir, Vector3(90, 0, 0))
			a.ajouter(_c(0.08, 0.08, 0.13, 12), Vector3(0, 0.48, 0.91), Color(1.0, 0.45, 0.1), Vector3(90, 0, 0))
			a.ajouter(_b(Vector3(0.14, 0.04, 0.06)), Vector3(0, 0.33, -0.94), fonce)


# --- Roues ---------------------------------------------------------------------

## Un décor posé sur les deux faces de la roue, à `rayon` de l'axe et sous cet
## angle (en degrés).
static func _sur_les_faces(a: Personnage.Atelier, forme: PrimitiveMesh, demi_largeur: float, rayon: float,
		angle: float, couleur: Color) -> void:
	var p := Vector3(cos(deg_to_rad(angle)) * rayon, 0, sin(deg_to_rad(angle)) * rayon)
	for cote in [-1.0, 1.0]:
		a.ajouter(forme, p + Vector3(0, cote * demi_largeur, 0), couleur, Vector3(0, -angle, 0))


static func roue(a: Personnage.Atelier, _teinte: Color, i: int) -> void:
	var r := ModeleKart.roues(i)
	var rayon: float = r.rayon
	var largeur: float = r.largeur
	var jante: float = r.jante
	var demi := largeur * 0.5
	match i:
		ModeleKart.BOUEES:
			# Une bouée : un tore rayé, pas un cylindre.
			var epaisseur := largeur * 0.5
			a.ajouter(_t(rayon - epaisseur * 2.0, rayon), Vector3.ZERO, r.pneu, Vector3.ZERO,
				Vector3(1, largeur / epaisseur * 0.5, 1))
			for k in 4:
				_sur_les_faces(a, _b(Vector3(0.05, 0.02, 0.06)), demi * 0.75, rayon - epaisseur, 45.0 + k * 90.0,
					r.couleur_jante)
			a.ajouter(_c(jante * 0.5, jante * 0.5, largeur * 0.5, 10), Vector3.ZERO, SOMBRE)
			return
		ModeleKart.DONUTS:
			var epaisseur := largeur * 0.55
			a.ajouter(_t(jante, rayon), Vector3.ZERO, r.pneu, Vector3.ZERO, Vector3(1, largeur / epaisseur, 1))
			# Le glaçage, sur les deux faces, et les vermicelles.
			for cote in [-1.0, 1.0]:
				a.ajouter(_c(rayon * 0.92, rayon * 0.92, 0.012, 18), Vector3(0, cote * demi * 0.8, 0), r.couleur_jante)
			a.ajouter(_c(jante, jante, largeur + 0.03, 12), Vector3.ZERO, Color(0.2, 0.12, 0.08))
			var couleurs := [Color(0.3, 0.7, 1.0), JAUNE, BLANC, Color(0.4, 0.9, 0.4)]
			for k in 10:
				_sur_les_faces(a, _b(Vector3(0.03, 0.012, 0.01)), demi * 0.8 + 0.008,
					jante + 0.02 + (rayon - jante - 0.04) * fmod(k * 0.43, 1.0), k * 37.0, couleurs[k % 4])
			return
		ModeleKart.PIERRE:
			# Une meule taillée : peu de côtés, un trou au milieu.
			a.ajouter(_c(rayon, rayon * 0.96, largeur, 7), Vector3.ZERO, r.pneu)
			a.ajouter(_c(jante, jante, largeur + 0.02, 8), Vector3.ZERO, r.couleur_jante)
			for k in 3:
				_sur_les_faces(a, _b(Vector3(0.04, 0.01, 0.025)), demi, rayon * 0.6, 40.0 + k * 120.0,
					Color(0.45, 0.43, 0.4))
			return
		ModeleKart.COOKIES:
			a.ajouter(_c(rayon, rayon * 0.97, largeur, 16), Vector3.ZERO, r.pneu)
			for k in 9:
				_sur_les_faces(a, _b(Vector3(0.035, 0.02, 0.03)), demi, 0.03 + (rayon - 0.06) * fmod(k * 0.53, 1.0),
					k * 41.0, r.couleur_jante)
			return
		ModeleKart.FROMAGES:
			a.ajouter(_c(rayon, rayon, largeur, 18), Vector3.ZERO, r.pneu)
			a.ajouter(_c(rayon + 0.004, rayon + 0.004, largeur * 0.6, 18), Vector3.ZERO, r.couleur_jante)
			for k in 6:
				_sur_les_faces(a, _c(0.022 + 0.01 * (k % 2), 0.022 + 0.01 * (k % 2), 0.01, 10), demi,
					0.04 + (rayon - 0.07) * fmod(k * 0.37, 1.0), k * 63.0, r.couleur_jante)
			return
		ModeleKart.WESTERN:
			# Une jante de bois, des rayons, un moyeu.
			a.ajouter(_t(rayon - 0.035, rayon), Vector3.ZERO, r.pneu, Vector3.ZERO, Vector3(1, largeur / 0.035, 1))
			a.ajouter(_c(jante, jante, largeur + 0.02, 10), Vector3.ZERO, r.couleur_jante)
			for k in 8:
				var angle := k * 45.0
				var milieu := (rayon + jante) * 0.5 - 0.01
				a.ajouter(_b(Vector3(rayon - jante - 0.02, largeur * 0.5, 0.02)),
					Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle))) * milieu, r.couleur_jante,
					Vector3(0, -angle, 0))
			return
	# Les autres : un pneu et sa jante, plus leurs décors.
	a.ajouter(_c(rayon, rayon, largeur, 18), Vector3.ZERO, r.pneu)
	if jante > 0.0:
		a.ajouter(_c(jante, jante, largeur + 0.012, 14), Vector3.ZERO, r.couleur_jante)
	match i:
		ModeleKart.MONSTRE:
			for k in 10:
				var angle := TAU * k / 10.0
				a.ajouter(_b(Vector3(0.05, largeur * 0.9, 0.035)), Vector3(cos(angle), 0.0, sin(angle)) * rayon,
					r.pneu, Vector3(0.0, -rad_to_deg(angle), 0.0))
		ModeleKart.PIZZAS:
			# Fromage fondu et rondelles de pepperoni.
			for cote in [-1.0, 1.0]:
				a.ajouter(_c(jante * 0.9, jante * 0.9, 0.01, 16), Vector3(0, cote * (demi + 0.007), 0),
					Color(1.0, 0.85, 0.45))
			for k in 6:
				_sur_les_faces(a, _c(0.026, 0.026, 0.01, 10), demi + 0.012, jante * (0.35 + 0.45 * fmod(k * 0.61, 1.0)),
					k * 60.0 + 15.0, Color(0.7, 0.12, 0.1))
		ModeleKart.VINYLES:
			# Des sillons, et l'étiquette au centre.
			for k in 3:
				var sillon := jante + 0.025 + k * 0.025
				for cote in [-1.0, 1.0]:
					a.ajouter(_t(sillon - 0.002, sillon + 0.002), Vector3(0, cote * demi, 0), Color(0.22, 0.22, 0.25),
						Vector3.ZERO, Vector3(1, 0.3, 1))
			a.ajouter(_c(0.01, 0.01, largeur + 0.03, 6), Vector3.ZERO, SOMBRE)
		ModeleKart.ENGRENAGES:
			for k in 12:
				var angle := TAU * k / 12.0
				a.ajouter(_b(Vector3(0.05, largeur, 0.04)), Vector3(cos(angle), 0.0, sin(angle)) * (rayon + 0.015),
					r.pneu, Vector3(0.0, -rad_to_deg(angle), 0.0))
			for k in 5:
				_sur_les_faces(a, _c(0.02, 0.02, 0.012, 8), demi + 0.004, jante * 0.6, k * 72.0, SOMBRE)
		ModeleKart.BLING:
			# Une étoile de rayons, dorée.
			for k in 6:
				_sur_les_faces(a, _b(Vector3(jante * 0.9, 0.012, 0.025)), demi + 0.008, jante * 0.45, k * 60.0,
					Color(1.0, 0.92, 0.55))
			a.ajouter(_c(0.03, 0.03, largeur + 0.03, 10), Vector3.ZERO, Color(1.0, 0.92, 0.55))
		ModeleKart.NEON:
			for cote in [-1.0, 1.0]:
				a.ajouter(_t(rayon * 0.78, rayon * 0.84), Vector3(0, cote * demi, 0), r.couleur_jante,
					Vector3.ZERO, Vector3(1, 0.3, 1))


# --- Ailerons ------------------------------------------------------------------

static func aileron(a: Personnage.Atelier, teinte: Color, i: int) -> void:
	match i:
		ModeleKart.BECQUET:
			for x in [-0.2, 0.2]:
				a.ajouter(_b(Vector3(0.04, 0.1, 0.04)), Vector3(x, 0.66, 0.86), SOMBRE)
			a.ajouter(_b(Vector3(0.7, 0.04, 0.2)), Vector3(0, 0.72, 0.88), teinte)
		ModeleKart.GRAND_AILERON:
			for x in [-0.25, 0.25]:
				a.ajouter(_b(Vector3(0.04, 0.38, 0.06)), Vector3(x, 0.74, 0.9), SOMBRE)
			a.ajouter(_b(Vector3(1.0, 0.05, 0.3)), Vector3(0, 0.94, 0.92), teinte, Vector3(-8, 0, 0))
			for x in [-0.5, 0.5]:
				a.ajouter(_b(Vector3(0.03, 0.18, 0.34)), Vector3(x, 0.94, 0.92), BLANC)
		ModeleKart.AILETTES:
			for x in [-0.22, 0.22]:
				a.ajouter(_b(Vector3(0.03, 0.3, 0.28)), Vector3(x, 0.74, 0.86), teinte, Vector3(0, 0, 18.0 * signf(x)))
		ModeleKart.VOILE:
			a.ajouter(_c(0.02, 0.02, 0.8, 8), Vector3(0, 1.0, 0.78), SOMBRE)
			a.ajouter(_b(Vector3(0.02, 0.55, 0.36)), Vector3(0, 1.05, 0.98), BLANC)
			a.ajouter(_b(Vector3(0.025, 0.12, 0.37)), Vector3(0, 0.84, 0.98), teinte)
		ModeleKart.HELICE:
			a.ajouter(_c(0.025, 0.025, 0.4, 8), Vector3(0, 0.82, 0.86), SOMBRE)
			a.ajouter(_s(0.05), Vector3(0, 1.03, 0.86), ROUGE)
			for angle in [20.0, 110.0]:
				a.ajouter(_b(Vector3(0.95, 0.015, 0.09)), Vector3(0, 1.05, 0.86), teinte, Vector3(0, angle, 6))
		ModeleKart.PARASOL:
			a.ajouter(_c(0.018, 0.018, 1.0, 8), Vector3(0, 1.02, 0.82), BLANC, Vector3(-12, 0, 0))
			a.ajouter(_c(0.62, 0.05, 0.22, 8), Vector3(0, 1.5, 0.92), teinte, Vector3(-12, 0, 0))
			a.ajouter(_c(0.64, 0.62, 0.03, 8), Vector3(0, 1.39, 0.9), BLANC, Vector3(-12, 0, 0))
			a.ajouter(_s(0.035), Vector3(0, 1.62, 0.95), BLANC)
		ModeleKart.AILES_ANGE:
			for x in [-1.0, 1.0]:
				for k in 4:
					var longueur := 0.55 - k * 0.1
					a.ajouter(_g(0.045, longueur), Vector3(x * (0.3 + longueur * 0.35), 0.82 - k * 0.07, 0.8 + k * 0.03),
						BLANC, Vector3(0, 0, x * (60.0 - k * 12.0)))
		ModeleKart.AILES_DRAGON:
			var membrane := teinte.darkened(0.35)
			for x in [-1.0, 1.0]:
				a.ajouter(_c(0.022, 0.022, 0.7, 6), Vector3(x * 0.42, 0.95, 0.8), SOMBRE, Vector3(0, 0, x * 55.0))
				for k in 3:
					a.ajouter(_b(Vector3(0.36, 0.02, 0.24)), Vector3(x * (0.3 + k * 0.14), 0.88 + k * 0.08, 0.86 + k * 0.05),
						membrane, Vector3(-10.0 + k * 8.0, 0, x * (25.0 + k * 8.0)))
				a.ajouter(_c(0.03, 0.0, 0.1, 6), Vector3(x * 0.71, 1.18, 0.8), BLANC, Vector3(0, 0, x * -30.0))
		ModeleKart.CAPE:
			# Elle tombe des épaules du pilote et flotte derrière le kart.
			a.ajouter(_b(Vector3(0.5, 0.025, 0.8)), Vector3(0, 0.68, 0.72), ROUGE, Vector3(33, 0, 0))
			a.ajouter(_b(Vector3(0.62, 0.025, 0.3)), Vector3(0, 0.42, 1.18), ROUGE, Vector3(12, 0, 0))
			for x in [-0.2, 0.2]:
				a.ajouter(_s(0.04), Vector3(x, 0.9, 0.4), OR)
		ModeleKart.DRAPEAU_PIRATE:
			a.ajouter(_c(0.02, 0.02, 0.95, 8), Vector3(0.25, 1.05, 0.82), Color(0.4, 0.28, 0.15))
			a.ajouter(_b(Vector3(0.02, 0.32, 0.48)), Vector3(0.25, 1.33, 1.06), Color(0.06, 0.06, 0.07))
			a.ajouter(_s(0.06), Vector3(0.24, 1.36, 1.06), BLANC)
			for x in [-1.0, 1.0]:
				a.ajouter(_b(Vector3(0.015, 0.03, 0.22)), Vector3(0.24, 1.26, 1.06), BLANC, Vector3(x * 40.0, 0, 0))
		ModeleKart.BALLONS:
			var couleurs := [ROUGE, JAUNE, Color(0.3, 0.6, 1.0), Color(0.4, 0.85, 0.4), teinte]
			var places := [Vector3(-0.25, 1.55, 1.0), Vector3(0.0, 1.7, 0.95), Vector3(0.25, 1.55, 1.0),
				Vector3(-0.12, 1.4, 1.1), Vector3(0.14, 1.42, 1.12)]
			for k in places.size():
				var p: Vector3 = places[k]
				a.ajouter(_s(0.13), p, couleurs[k], Vector3.ZERO, Vector3(1, 1.2, 1))
				# La ficelle descend jusqu'au support.
				var bas := 0.68
				a.ajouter(_c(0.005, 0.005, p.y - bas, 4), Vector3(p.x, (p.y + bas) * 0.5, p.z), BLANC)
			a.ajouter(_b(Vector3(0.1, 0.06, 0.1)), Vector3(0, 0.66, 1.0), SOMBRE)
		ModeleKart.PARABOLE:
			a.ajouter(_c(0.025, 0.025, 0.3, 8), Vector3(0, 0.8, 0.86), SOMBRE)
			a.ajouter(_c(0.05, 0.32, 0.1, 18), Vector3(0, 1.02, 0.9), BLANC, Vector3(-40, 0, 0))
			a.ajouter(_c(0.01, 0.01, 0.3, 6), Vector3(0, 1.12, 0.78), SOMBRE, Vector3(-40, 0, 0))
			a.ajouter(_s(0.035), Vector3(0, 1.22, 0.68), teinte)
		ModeleKart.REACTEUR:
			a.ajouter(_c(0.15, 0.13, 0.55, 16), Vector3(0, 0.74, 0.95), CHROME, Vector3(90, 0, 0))
			a.ajouter(_c(0.1, 0.1, 0.56, 14), Vector3(0, 0.74, 0.95), SOMBRE, Vector3(90, 0, 0))
			a.ajouter(_c(0.09, 0.0, 0.3, 12), Vector3(0, 0.74, 1.36), Color(1.0, 0.55, 0.1), Vector3(90, 0, 0))
			a.ajouter(_c(0.05, 0.0, 0.2, 10), Vector3(0, 0.74, 1.35), JAUNE, Vector3(90, 0, 0))
			for x in [-0.15, 0.15]:
				a.ajouter(_b(Vector3(0.04, 0.12, 0.2)), Vector3(x, 0.62, 0.9), teinte)
		ModeleKart.NAGEOIRE:
			for x in [-1.0, 1.0]:
				a.ajouter(_b(Vector3(0.03, 0.45, 0.2)), Vector3(x * 0.12, 0.78, 1.0), teinte, Vector3(30, 0, x * 35.0))
			a.ajouter(_s(0.07), Vector3(0, 0.62, 0.9), teinte.darkened(0.3))
		ModeleKart.FEUX_ARTIFICE:
			a.ajouter(_b(Vector3(0.5, 0.05, 0.2)), Vector3(0, 0.66, 0.88), SOMBRE)
			var couleurs := [ROUGE, JAUNE, Color(0.3, 0.6, 1.0)]
			for k in 3:
				var x := -0.17 + k * 0.17
				var bascule := -10.0 + k * 10.0
				a.ajouter(_c(0.04, 0.04, 0.42, 10), Vector3(x, 0.92, 0.9), couleurs[k], Vector3(-15, 0, bascule))
				a.ajouter(_c(0.045, 0.0, 0.1, 10), Vector3(x - bascule * 0.004, 1.17, 0.84), BLANC, Vector3(-15, 0, bascule))
				a.ajouter(_c(0.006, 0.006, 0.1, 4), Vector3(x, 0.68, 0.97), SOMBRE)
