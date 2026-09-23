class_name RaceScoring
extends RefCounted

## Le barème de fin de course. Une table écrite en dur plutôt qu'une formule :
## personne ne retient une formule, tout le monde retient « le premier prend
## quinze ».

const POINTS: Array[int] = [15, 12, 10, 8, 6, 4, 2, 1]


static func points_pour(place: int) -> int:
	if place < 1 or place > POINTS.size():
		return 0
	return POINTS[place - 1]


## « 1er », « 2e »… L'écran de résultats et le HUD disent la même chose.
static func ordinal(place: int) -> String:
	return "1er" if place == 1 else "%de" % place
