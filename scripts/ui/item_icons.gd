class_name ItemIcons
extends RefCounted

## Les pictogrammes d'objets : les photos des modèles 3D du jeu
## (resources/icones_objets/, faites par tools/icones_objets.gd), et à défaut
## un dessin au trait — l'éclair, qui n'a pas de modèle, l'est toujours.

const DOSSIER := "res://resources/icones_objets/"
## Le nom de la photo de chaque objet.
const PHOTOS := {
	ItemKind.MUSHROOM: "champignon",
	ItemKind.BANANA: "banane",
	ItemKind.GREEN_SHELL: "carapace_verte",
	ItemKind.RED_SHELL: "carapace_rouge",
	ItemKind.BLUE_SHELL: "carapace_bleue",
	ItemKind.STAR: "etoile",
	ItemKind.FAKE_BOX: "fausse_boite",
}
static var _photos: Dictionary = {}


## La photo `nom`, chargée une fois ; null si elle manque.
static func photo(nom: String) -> Texture2D:
	if not _photos.has(nom):
		var chemin := DOSSIER + nom + ".png"
		_photos[nom] = load(chemin) as Texture2D if ResourceLoader.exists(chemin) else null
	return _photos[nom]


## Pose la photo `nom` dans le carré de demi-côté r autour de centre. Faux si
## elle manque.
static func poser(toile: CanvasItem, nom: String, centre: Vector2, r: float, teinte := Color.WHITE) -> bool:
	var texture := photo(nom)
	if texture == null:
		return false
	toile.draw_texture_rect(texture, Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0), false, teinte)
	return true


## Le point d'interrogation d'une caisse, blanc cerclé de noir.
static func signe(toile: CanvasItem, texte: String, centre: Vector2, r: float) -> void:
	var police := ThemeDB.fallback_font
	var taille := int(r * 1.1)
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var ou := centre + Vector2(-largeur * 0.5, taille * 0.35)
	toile.draw_string_outline(police, ou, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, maxi(2, int(r * 0.12)), Color.BLACK)
	toile.draw_string(police, ou, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color.WHITE)


static func dessiner(toile: CanvasItem, objet: int, centre: Vector2, r: float) -> void:
	if PHOTOS.has(objet) and poser(toile, PHOTOS[objet], centre, r * 1.15):
		if objet == ItemKind.FAKE_BOX:
			signe(toile, "¿", centre, r)
		return
	if objet == ItemKind.TRIPLE_MUSHROOM and photo("champignon") != null:
		var petit := r * 0.62
		poser(toile, "champignon", centre + Vector2(0, -r * 0.4), petit)
		poser(toile, "champignon", centre + Vector2(-r * 0.48, r * 0.38), petit)
		poser(toile, "champignon", centre + Vector2(r * 0.48, r * 0.38), petit)
		return
	match objet:
		ItemKind.MUSHROOM:
			_champignon(toile, centre, r)
		ItemKind.TRIPLE_MUSHROOM:
			var petit := r * 0.55
			_champignon(toile, centre + Vector2(0, -r * 0.42), petit)
			_champignon(toile, centre + Vector2(-r * 0.48, r * 0.38), petit)
			_champignon(toile, centre + Vector2(r * 0.48, r * 0.38), petit)
		ItemKind.BANANA:
			toile.draw_arc(centre + Vector2(r * 0.25, -r * 0.2), r * 0.7, deg_to_rad(95.0), deg_to_rad(215.0),
				20, Color(1.0, 0.86, 0.15), r * 0.36, true)
			toile.draw_line(centre + Vector2(-r * 0.3, -r * 0.62), centre + Vector2(-r * 0.12, -r * 0.82),
				Color(0.35, 0.25, 0.1), r * 0.14)
		ItemKind.GREEN_SHELL:
			_carapace(toile, centre, r, Color(0.15, 0.75, 0.2))
		ItemKind.RED_SHELL:
			_carapace(toile, centre, r, Color(0.9, 0.12, 0.1))
		ItemKind.BLUE_SHELL:
			# Des ailes blanches de part et d'autre, puis la carapace.
			for cote in [-1.0, 1.0]:
				toile.draw_colored_polygon(PackedVector2Array([
					centre + Vector2(cote * r * 0.45, -r * 0.2),
					centre + Vector2(cote * r * 1.05, -r * 0.6),
					centre + Vector2(cote * r * 0.95, r * 0.05),
				]), Color(0.97, 0.97, 1.0))
			_carapace(toile, centre, r * 0.9, Color(0.15, 0.35, 1.0))
		ItemKind.LIGHTNING:
			# Large, cerclé de sombre : à côté des photos des autres objets, un
			# trait fin se perdait.
			var points := PackedVector2Array()
			for p in [Vector2(0.35, -1.05), Vector2(-0.7, 0.15), Vector2(-0.05, 0.15), Vector2(-0.4, 1.05),
					Vector2(0.7, -0.2), Vector2(0.05, -0.2)]:
				points.append(centre + p * r)
			toile.draw_colored_polygon(points, Color(1.0, 0.86, 0.15))
			var contour := points.duplicate()
			contour.append(points[0])
			toile.draw_polyline(contour, Color(0.35, 0.2, 0.0), maxf(2.0, r * 0.08), true)
		ItemKind.STAR:
			toile.draw_colored_polygon(etoile(centre, r * 0.95, r * 0.42), Color(1.0, 0.85, 0.15))
			toile.draw_circle(centre + Vector2(-r * 0.15, -r * 0.05), r * 0.08, Color(0.1, 0.1, 0.1))
			toile.draw_circle(centre + Vector2(r * 0.15, -r * 0.05), r * 0.08, Color(0.1, 0.1, 0.1))
		ItemKind.FAKE_BOX:
			var cote := r * 1.5
			var cadre := Rect2(centre - Vector2(cote, cote) * 0.5, Vector2(cote, cote))
			toile.draw_rect(cadre, Color(1.0, 0.45, 0.4, 0.85))
			toile.draw_rect(cadre, Color.WHITE, false, 2.0)
			toile.draw_string(ThemeDB.fallback_font, centre + Vector2(-r * 0.25, r * 0.35), "¿",
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.1), Color.WHITE)
		ItemKind.COINS:
			piece(toile, centre + Vector2(-r * 0.3, r * 0.15), r * 0.55)
			piece(toile, centre + Vector2(r * 0.3, -r * 0.15), r * 0.55)


static func _champignon(toile: CanvasItem, centre: Vector2, r: float) -> void:
	# Le pied, puis le chapeau en demi-disque, puis les pois.
	toile.draw_rect(Rect2(centre + Vector2(-r * 0.3, 0.0), Vector2(r * 0.6, r * 0.6)), Color(0.98, 0.93, 0.82))
	var chapeau := PackedVector2Array()
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		chapeau.append(centre + Vector2(cos(a), sin(a)) * r * 0.85 + Vector2(0, r * 0.05))
	toile.draw_colored_polygon(chapeau, Color(0.9, 0.15, 0.12))
	toile.draw_circle(centre + Vector2(0.0, -r * 0.45), r * 0.18, Color.WHITE)
	toile.draw_circle(centre + Vector2(-r * 0.5, -r * 0.18), r * 0.13, Color.WHITE)
	toile.draw_circle(centre + Vector2(r * 0.5, -r * 0.18), r * 0.13, Color.WHITE)


static func _carapace(toile: CanvasItem, centre: Vector2, r: float, couleur: Color) -> void:
	toile.draw_circle(centre, r * 0.8, Color(0.97, 0.97, 0.95))
	toile.draw_circle(centre, r * 0.64, couleur)
	# Les écailles : un hexagone clair au milieu.
	var hexagone := PackedVector2Array()
	for i in 6:
		var a := TAU * float(i) / 6.0
		hexagone.append(centre + Vector2(cos(a), sin(a)) * r * 0.26)
	toile.draw_colored_polygon(hexagone, couleur.lightened(0.45))


## Une étoile à cinq branches, pointe en haut.
static func etoile(centre: Vector2, grand: float, petit: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * float(i) / 5.0
		points.append(centre + Vector2(cos(a), sin(a)) * (grand if i % 2 == 0 else petit))
	return points


static func piece(toile: CanvasItem, centre: Vector2, r: float) -> void:
	if poser(toile, "piece", centre, r * 1.15):
		return
	toile.draw_circle(centre, r, Color(0.85, 0.62, 0.1))
	toile.draw_circle(centre, r * 0.78, Color(1.0, 0.84, 0.2))
	toile.draw_rect(Rect2(centre - Vector2(r * 0.12, r * 0.45), Vector2(r * 0.24, r * 0.9)), Color(0.85, 0.62, 0.1))
