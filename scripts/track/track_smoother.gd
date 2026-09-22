class_name TrackSmoother

## Retouche une courbe de circuit pour qu'elle soit roulable, et lui donne du
## dévers. Comme TrackCurve et KartMotor, cette classe ne connaît ni la scène ni
## les nœuds : elle ne fait que du calcul sur une Curve3D, et se teste donc
## entièrement sans lancer le moteur de rendu.
##
## Les outils de `tools/` ne sont que des enveloppes autour d'elle : la logique
## qui décide de déplacer un point de contrôle mérite des tests, pas un script
## qu'on lance une fois et qu'on oublie.

## Part de la distance au voisin reportée sur la poignée. Un tiers redonne la
## tangente de Catmull-Rom, qui passe par les points sans les dépasser.
const TENSION := 1.0 / 3.0

## Pas d'extrusion du TrackBuilder. C'est à cette échelle qu'un pli devient un
## mur, donc c'est à cette échelle qu'on mesure.
const PAS := 2.0


## Une courbe fermée répète son premier point à la fin.
static func est_fermee(curve: Curve3D) -> bool:
	var n := curve.point_count
	return n > 2 and curve.get_point_position(0).distance_to(
		curve.get_point_position(n - 1)) < 0.01


## Index du voisin, en sautant par-dessus le point de fermeture qui fait
## doublon — sans quoi la tangente y serait nulle.
static func voisin(curve: Curve3D, i: int, fermee: bool) -> int:
	var n := curve.point_count
	if fermee:
		if i < 0:
			return n - 2
		if i >= n - 1:
			return 1
		return i
	return i if i >= 0 and i < n else -1


## Donne à chaque point des poignées colinéaires déduites de ses voisins. Un
## point sans poignée fait un angle vif, invisible à l'écran mais où le ruban
## extrudé se replie ; des poignées colinéaires rendent la tangente continue.
##
## `seulement_les_vides` préserve le travail fait à la main : on ne touche
## qu'aux points que personne n'a encore réglés.
static func poser_les_poignees(curve: Curve3D, seulement_les_vides: bool = true) -> int:
	var n := curve.point_count
	var fermee := est_fermee(curve)
	var poses := 0
	for i in n:
		if fermee and i == n - 1:
			continue
		if seulement_les_vides and (curve.get_point_in(i).length() > 0.01
				or curve.get_point_out(i).length() > 0.01):
			continue
		var avant := voisin(curve, i - 1, fermee)
		var apres := voisin(curve, i + 1, fermee)
		if avant < 0 or apres < 0:
			continue
		var tangente := (curve.get_point_position(apres)
			- curve.get_point_position(avant)) * TENSION * 0.5
		curve.set_point_in(i, -tangente)
		curve.set_point_out(i, tangente)
		poses += 1
	if fermee and n > 1:
		# La jointure doit porter les mêmes poignées que le premier point, sinon
		# elle fait un angle que personne ne voit venir — sur la ligne d'arrivée.
		curve.set_point_in(n - 1, curve.get_point_in(0))
		curve.set_point_out(n - 1, curve.get_point_out(0))
	return poses


## Rayon local le plus serré de toute la courbe, en mètres.
static func rayon_le_plus_serre(curve: Curve3D, half_width: float = 9.0) -> float:
	var c := TrackCurve.new(curve, half_width)
	var pire := INF
	var d := 0.0
	while d < c.length:
		pire = minf(pire, c.kink_radius_at(d, PAS))
		d += PAS
	return pire


## Variation de dévers tolérée, en radians par mètre parcouru. À cette valeur,
## passer de plat à vingt degrés demande une trentaine de mètres — une entrée
## de virage relevé, pas une marche.
const TORSION_MAX := 0.012


## Plafond de longueur de poignée, en part de la distance au voisin le plus
## proche. Au-delà, la courbe déborde du polygone de ses points et finit par
## faire une boucle.
const POIGNEE_MAX := 0.45


## Ouvre les virages jusqu'à ce qu'aucun ne soit plus serré que `rayon_min`.
## Le kart tourne au mieux à 8,5 m en dérapage : en deçà il ne négocie pas le
## virage, il s'encastre dedans.
##
## Deux leviers, dans cet ordre. D'abord ALLONGER les poignées du point fautif :
## la courbure à un point de contrôle varie comme l'inverse de la longueur de sa
## poignée, et allonger ne déplace pas le tracé d'un centimètre. Mesuré sur le
## circuit 1, le seul virage impraticable venait de là — une poignée de 13,7 m
## là où ses voisines en faisaient 23 à 27.
##
## Seulement si les poignées butent sur leur plafond, DÉPLACER le point vers le
## milieu de ses voisins. C'est le dernier recours parce que c'est le seul qui
## change le dessin du circuit, et le déplacement reste plafonné.
##
## Rend un compte rendu plutôt qu'un booléen : quand ça ne suffit pas, l'auteur
## a besoin de savoir de combien on a bougé et ce qu'il reste à faire.
static func elargir(curve: Curve3D, rayon_min: float, ecart_max: float = 8.0,
		passes: int = 300, half_width: float = 9.0) -> Dictionary:
	var n := curve.point_count
	var fermee := est_fermee(curve)
	var origine: Array[Vector3] = []
	for i in n:
		origine.append(curve.get_point_position(i))

	var avant := rayon_le_plus_serre(curve, half_width)
	var faites := 0
	var allonges := {}
	var deplaces := {}

	for p in passes:
		var c := TrackCurve.new(curve, half_width)
		var serres := c.tight_spots(rayon_min, PAS)
		if serres.is_empty():
			break
		faites += 1

		var fautifs := {}
		for endroit in serres:
			var i := _point_le_plus_proche(curve, c, float(endroit[0]), fermee)
			if i >= 0:
				fautifs[i] = true
		if fautifs.is_empty():
			break

		for i in fautifs:
			var avant_i := voisin(curve, i - 1, fermee)
			var apres_i := voisin(curve, i + 1, fermee)
			if avant_i < 0 or apres_i < 0:
				continue

			var reference := rayon_le_plus_serre(curve, half_width)

			# Essai 1 : allonger la poignée, qui ne déplace pas le tracé.
			# Accepté seulement s'il améliore : sur un virage déjà très pincé,
			# une poignée trop longue fait boucler la courbe et resserre encore.
			var plafond: float = POIGNEE_MAX * minf(
				curve.get_point_position(i).distance_to(curve.get_point_position(avant_i)),
				curve.get_point_position(i).distance_to(curve.get_point_position(apres_i)))
			var sortie := curve.get_point_out(i)
			if sortie.length() < 0.01:
				sortie = (curve.get_point_position(apres_i)
					- curve.get_point_position(avant_i)) * TENSION * 0.5

			if sortie.length() < plafond:
				var garde_in := curve.get_point_in(i)
				var garde_out := curve.get_point_out(i)
				var tangente := sortie.normalized() * minf(sortie.length() * 1.10, plafond)
				curve.set_point_in(i, -tangente)
				curve.set_point_out(i, tangente)
				_recopier_la_jointure(curve, i, fermee)
				if rayon_le_plus_serre(curve, half_width) > reference:
					allonges[i] = true
					continue
				curve.set_point_in(i, garde_in)
				curve.set_point_out(i, garde_out)
				_recopier_la_jointure(curve, i, fermee)

			# Essai 2 : écarter le point lui-même. Dernier recours, parce que
			# c'est le seul levier qui change le dessin du circuit.
			var milieu := (curve.get_point_position(avant_i)
				+ curve.get_point_position(apres_i)) * 0.5
			var ou: Vector3 = curve.get_point_position(i).lerp(milieu, 0.12)
			var depuis := ou - origine[i]
			if depuis.length() > ecart_max:
				ou = origine[i] + depuis.normalized() * ecart_max
			var garde_pos := curve.get_point_position(i)
			curve.set_point_position(i, ou)
			if fermee and (i == 0 or i == n - 1):
				# Les deux extrémités sont le même point : les désolidariser
				# ouvrirait le circuit sur la ligne de départ.
				curve.set_point_position(0, ou)
				curve.set_point_position(n - 1, ou)
			# Les poignées des trois points concernés suivent le déplacement.
			for j in [avant_i, i, apres_i]:
				_reposer_une_poignee(curve, j, fermee)
			if rayon_le_plus_serre(curve, half_width) > reference:
				deplaces[i] = true
			else:
				curve.set_point_position(i, garde_pos)
				if fermee and (i == 0 or i == n - 1):
					curve.set_point_position(0, garde_pos)
					curve.set_point_position(n - 1, garde_pos)
				for j in [avant_i, i, apres_i]:
					_reposer_une_poignee(curve, j, fermee)

	var apres := rayon_le_plus_serre(curve, half_width)
	var deplace := 0.0
	for i in n:
		deplace = maxf(deplace, curve.get_point_position(i).distance_to(origine[i]))

	return {
		"rayon_avant": avant,
		"rayon_apres": apres,
		"objectif": rayon_min,
		"atteint": apres >= rayon_min,
		"passes": faites,
		"points_allonges": allonges.size(),
		"points_deplaces": deplaces.size(),
		"deplacement_max": deplace,
	}


## Recalcule la poignée d'un seul point depuis ses voisins, en gardant sa
## longueur actuelle : déplacer un point change la direction de sa tangente,
## mais pas l'ouverture qu'on lui a patiemment donnée.
static func _reposer_une_poignee(curve: Curve3D, i: int, fermee: bool) -> void:
	var avant := voisin(curve, i - 1, fermee)
	var apres := voisin(curve, i + 1, fermee)
	if avant < 0 or apres < 0:
		return
	var direction := curve.get_point_position(apres) - curve.get_point_position(avant)
	if direction.length_squared() < 0.000001:
		return
	var longueur := maxf(curve.get_point_out(i).length(),
		direction.length() * TENSION * 0.5)
	var tangente := direction.normalized() * longueur
	curve.set_point_in(i, -tangente)
	curve.set_point_out(i, tangente)
	_recopier_la_jointure(curve, i, fermee)


## Le point de fermeture doit porter les mêmes poignées que le premier.
static func _recopier_la_jointure(curve: Curve3D, i: int, fermee: bool) -> void:
	if not fermee:
		return
	var n := curve.point_count
	if i == 0:
		curve.set_point_in(n - 1, curve.get_point_in(0))
		curve.set_point_out(n - 1, curve.get_point_out(0))
	elif i == n - 1:
		curve.set_point_in(0, curve.get_point_in(n - 1))
		curve.set_point_out(0, curve.get_point_out(n - 1))


## Le point de contrôle le plus proche d'une distance le long de la courbe.
static func _point_le_plus_proche(curve: Curve3D, c: TrackCurve, distance: float,
		fermee: bool) -> int:
	var n := curve.point_count
	var meilleur := -1
	var ecart := INF
	for i in n:
		if fermee and i == n - 1:
			continue
		var d := c.distance_of(curve.get_point_position(i))
		var delta: float = minf(absf(d - distance), c.length - absf(d - distance))
		if delta < ecart:
			ecart = delta
			meilleur = i
	return meilleur


## Incline la chaussée dans les virages, proportionnellement à ce que la
## physique demanderait pour y tenir.
##
## PLAFOND MESURÉ, ET IL COMPTE. Sur le circuit 1, l'IA boucle ses trois tours
## à 0, 10 et 18 degrés de dévers — zéro image bloquée à 18 — et n'y arrive plus
## du tout à 22 : le ruban extrudé finit par dresser ses bords en obstacles
## quand la chaussée penche trop. Le défaut est dans TrackBuilder, qui relie
## deux sections par deux triangles sans rien savoir de leur inclinaison
## relative ; tant qu'il n'est pas repris, quinze degrés laissent de la marge.
##
## L'angle idéal d'un virage relevé est atan(v² / (g·r)) : c'est celui où la
## réaction du sol suffit à courber la trajectoire, sans rien demander à
## l'adhérence latérale. On le calcule, puis on le plafonne — un virage relevé
## à 39 degrés est juste sur le papier et illisible à l'écran.
##
## Le signe suit celui du virage : on se penche vers l'intérieur, toujours.
## Les lignes droites restent à plat, la courbure y étant nulle.
static func incliner(curve: Curve3D, angle_max_deg: float = 15.0,
		vitesse: float = 22.0, gravite: float = 30.0,
		half_width: float = 9.0) -> Dictionary:
	var n := curve.point_count
	var fermee := est_fermee(curve)
	var c := TrackCurve.new(curve, half_width)
	var plafond := deg_to_rad(angle_max_deg)
	var pose := 0
	var plus_incline := 0.0

	for i in n:
		if fermee and i == n - 1:
			continue
		var d := c.distance_of(curve.get_point_position(i))
		var virage := c.turn_at(d)
		var rayon := c.radius_at(d)
		var angle := 0.0
		if rayon < 100000.0 and rayon > 0.01:
			angle = atan(vitesse * vitesse / (gravite * rayon))
			angle = minf(angle, plafond) * signf(virage)
		curve.set_point_tilt(i, angle)
		if absf(angle) > 0.001:
			pose += 1
		plus_incline = maxf(plus_incline, absf(angle))

	var torsion := _borner_la_torsion(curve, c, fermee)

	plus_incline = 0.0
	pose = 0
	for i in n:
		if fermee and i == n - 1:
			continue
		var t := absf(curve.get_point_tilt(i))
		plus_incline = maxf(plus_incline, t)
		if t > 0.001:
			pose += 1

	return {
		"points_inclines": pose,
		"devers_max_deg": rad_to_deg(plus_incline),
		"plafond_deg": angle_max_deg,
		"torsion_max_deg_par_m": rad_to_deg(torsion),
	}


## Borne la vitesse à laquelle le dévers change le long de la piste.
##
## Ce n'est pas l'angle qui casse tout, c'est sa dérivée. Mesuré : à 22 degrés
## de plafond, le tracé passait de +21,5 à -5,8 degrés en 70 m ; sur un ruban de
## 18 m de large, ses bords balayent alors plusieurs mètres de haut en peu de
## distance et se dressent en murs. L'IA y restait bloquée 478 images et passait
## 62 % du tour en l'air, contre zéro et 2,3 % à 18 degrés.
##
## Une piste réelle entre et sort d'un virage relevé progressivement. On fait
## pareil : on rapproche les dévers voisins tant que la marche entre eux
## dépasse ce qu'un mètre de route peut absorber.
static func _borner_la_torsion(curve: Curve3D, c: TrackCurve, fermee: bool) -> float:
	var n := curve.point_count
	var derniers := n - 1 if fermee else n
	if derniers < 2:
		return 0.0

	var offsets: Array[float] = []
	for i in derniers:
		offsets.append(c.distance_of(curve.get_point_position(i)))

	for passe in 60:
		var pire := 0.0
		for i in derniers:
			var j := (i + 1) % derniers
			var arc: float = offsets[j] - offsets[i]
			if arc <= 0.0:
				arc += c.length
			if arc < 0.01:
				continue
			var marche: float = curve.get_point_tilt(j) - curve.get_point_tilt(i)
			var tolere := TORSION_MAX * arc
			pire = maxf(pire, absf(marche) / arc)
			if absf(marche) <= tolere:
				continue
			# On partage l'excès entre les deux voisins plutôt que de l'imposer
			# à un seul : sinon la correction se propage dans un seul sens et
			# déforme le dévers de tout un côté du circuit.
			var exces: float = (absf(marche) - tolere) * 0.5 * signf(marche)
			curve.set_point_tilt(i, curve.get_point_tilt(i) + exces)
			curve.set_point_tilt(j, curve.get_point_tilt(j) - exces)
		if pire <= TORSION_MAX:
			break

	if fermee and n > 1:
		curve.set_point_tilt(n - 1, curve.get_point_tilt(0))

	var reste := 0.0
	for i in derniers:
		var j := (i + 1) % derniers
		var arc: float = offsets[j] - offsets[i]
		if arc <= 0.0:
			arc += c.length
		if arc > 0.01:
			reste = maxf(reste, absf(curve.get_point_tilt(j) - curve.get_point_tilt(i)) / arc)
	return reste
