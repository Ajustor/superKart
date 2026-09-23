class_name ItemIcons
extends RefCounted

## Les pictogrammes d'objets, dessinés au trait plutôt que chargés : le dépôt
## n'a pas d'images, et une forme simple se lit mieux d'un coup d'œil qu'un
## dessin détaillé réduit à 40 pixels.


static func dessiner(toile: CanvasItem, objet: int, centre: Vector2, r: float) -> void:
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
