class_name ItemTable
extends Resource

## La table de tirage, qui dépend de la place au classement : c'est elle qui
## rend le jeu vivant, pas les objets eux-mêmes (spec, 7.2). En tête surtout
## des bananes, pour se protéger ; en fond de peloton des carapaces rouges et
## des triples champignons, pour revenir.
##
## Une ligne par tranche de classement, de la tête à la queue ; une colonne par
## objet, dans l'ordre de ItemKind.TIRABLES. Les poids n'ont pas besoin de
## faire 100 : seule leur proportion compte.

@export var lignes: Array[PackedFloat32Array] = [
	#                   champi  triple  banane  verte  rouge
	PackedFloat32Array([10.0,   0.0,    60.0,   30.0,  0.0]),
	PackedFloat32Array([20.0,   0.0,    35.0,   35.0,  10.0]),
	PackedFloat32Array([25.0,   5.0,    25.0,   30.0,  15.0]),
	PackedFloat32Array([25.0,   10.0,   15.0,   25.0,  25.0]),
	PackedFloat32Array([25.0,   15.0,   10.0,   20.0,  30.0]),
	PackedFloat32Array([20.0,   25.0,   5.0,    15.0,  35.0]),
	PackedFloat32Array([15.0,   35.0,   0.0,    10.0,  40.0]),
	PackedFloat32Array([10.0,   45.0,   0.0,    5.0,   40.0]),
]


## La ligne qui s'applique à cette place. La table ne suppose pas huit
## concurrents : la place est ramenée à la même fraction du peloton.
func ligne_pour(place: int, concurrents: int) -> int:
	if lignes.size() <= 1 or concurrents <= 1:
		return 0
	var fraction := float(clampi(place, 1, concurrents) - 1) / float(concurrents - 1)
	return clampi(roundi(fraction * float(lignes.size() - 1)), 0, lignes.size() - 1)


func tirer(place: int, concurrents: int, rng: RandomNumberGenerator) -> int:
	if lignes.is_empty():
		return ItemKind.MUSHROOM
	var poids := lignes[ligne_pour(place, concurrents)]
	var n := mini(poids.size(), ItemKind.TIRABLES.size())
	var total := 0.0
	for i in n:
		total += maxf(poids[i], 0.0)
	# Une ligne vide ou mal saisie donne quand même quelque chose : une boîte
	# qui ne rend rien passerait pour un bug.
	if total <= 0.0:
		return ItemKind.MUSHROOM
	var tirage := rng.randf() * total
	for i in n:
		tirage -= maxf(poids[i], 0.0)
		if tirage < 0.0:
			return ItemKind.TIRABLES[i]
	return ItemKind.TIRABLES[n - 1]
