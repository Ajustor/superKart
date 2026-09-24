class_name ItemTable
extends Resource

## La table de tirage, qui dépend de la place au classement : c'est elle qui
## rend le jeu vivant, pas les objets eux-mêmes (spec, 7.2). En tête surtout
## des bananes, des fausses boîtes et des pièces, pour se protéger ; en fond
## de peloton des carapaces rouges, des triples champignons, des étoiles, et
## les rares carapaces bleues et éclairs qui rebattent les cartes.
##
## Une ligne par tranche de classement, de la tête à la queue ; une colonne par
## objet, dans l'ordre de ItemKind.TIRABLES. Les poids n'ont pas besoin de
## faire 100 : seule leur proportion compte.

@export var lignes: Array[PackedFloat32Array] = [
	# champi triple banane verte rouge bleue éclair étoile fausse pièces
	PackedFloat32Array([8.0, 0.0, 55.0, 20.0, 0.0, 0.0, 0.0, 0.0, 10.0, 7.0]),
	PackedFloat32Array([18.0, 0.0, 30.0, 28.0, 8.0, 0.0, 0.0, 0.0, 8.0, 8.0]),
	PackedFloat32Array([22.0, 5.0, 20.0, 26.0, 13.0, 0.0, 0.0, 3.0, 6.0, 5.0]),
	PackedFloat32Array([22.0, 9.0, 12.0, 22.0, 20.0, 2.0, 0.0, 6.0, 3.0, 4.0]),
	PackedFloat32Array([20.0, 14.0, 8.0, 17.0, 24.0, 4.0, 1.0, 9.0, 1.0, 2.0]),
	PackedFloat32Array([16.0, 21.0, 4.0, 12.0, 27.0, 5.0, 2.0, 12.0, 0.0, 1.0]),
	PackedFloat32Array([12.0, 28.0, 0.0, 8.0, 29.0, 6.0, 4.0, 13.0, 0.0, 0.0]),
	PackedFloat32Array([8.0, 32.0, 0.0, 4.0, 28.0, 6.0, 8.0, 14.0, 0.0, 0.0]),
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
