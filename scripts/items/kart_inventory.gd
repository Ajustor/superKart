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
## Tenu derrière le kart, bouton maintenu : la banane ou la carapace traîne
## au cul du kart et le protège, jusqu'à ce qu'on la lâche.
var tenu: bool = false
## Depuis combien de temps il est tenu : un appui bref garde l'usage
## classique, un maintien laisse choisir le sens du lancer.
var tenu_depuis: float = 0.0


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


## Les objets qu'on peut garder derrière soi : ceux qui existent sur la piste.
## Les autres (champignon, étoile, éclair…) agissent tout de suite.
static func tenable(quoi: int) -> bool:
	return quoi in [ItemKind.BANANA, ItemKind.FAKE_BOX, ItemKind.GREEN_SHELL, ItemKind.RED_SHELL]


func vider() -> void:
	objet = ItemKind.NONE
	charges = 0
	roulette = 0.0
	tenu = false
	tenu_depuis = 0.0
