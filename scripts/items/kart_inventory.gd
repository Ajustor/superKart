class_name KartInventory
extends RefCounted

## L'emplacement d'objet d'un kart : un seul, comme le veut la spec. Une boîte
## ramassée avec l'emplacement plein ne donne rien — c'est ce qui oblige à
## utiliser ce qu'on tient plutôt qu'à le garder indéfiniment.

## Durée de la roulette, en secondes. Pendant ce temps l'objet est tiré mais
## pas encore utilisable : le joueur voit défiler les objets, et l'IA ne peut
## pas lancer une carapace à l'image même où elle traverse la boîte.
const DUREE_ROULETTE := 1.0

var objet: int = ItemKind.NONE
var charges: int = 0
var roulette: float = 0.0


func est_vide() -> bool:
	return objet == ItemKind.NONE


## Tiré et sorti de la roulette : prêt à partir.
func pret() -> bool:
	return not est_vide() and roulette <= 0.0


## Range l'objet s'il y a de la place, et dit si c'est le cas.
func recevoir(tire: int, duree_roulette: float = DUREE_ROULETTE) -> bool:
	if not est_vide() or tire == ItemKind.NONE:
		return false
	objet = tire
	charges = 3 if tire == ItemKind.TRIPLE_MUSHROOM else 1
	roulette = maxf(duree_roulette, 0.0)
	return true


func avancer(delta: float) -> void:
	roulette = maxf(roulette - delta, 0.0)


## Consomme une charge et rend l'objet réellement lancé : le triple champignon
## lance un champignon, trois fois. Rend NONE si rien n'est prêt.
func utiliser() -> int:
	if not pret():
		return ItemKind.NONE
	var lance := ItemKind.MUSHROOM if objet == ItemKind.TRIPLE_MUSHROOM else objet
	charges -= 1
	if charges <= 0:
		vider()
	return lance


func vider() -> void:
	objet = ItemKind.NONE
	charges = 0
	roulette = 0.0
