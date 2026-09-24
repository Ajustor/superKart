class_name ItemKind
extends RefCounted

## Les objets du jeu. Un entier plutôt qu'une classe par objet : un objet n'a
## pas d'état tant qu'il est dans l'emplacement, et ce qu'il devient une fois
## lancé — une banane au sol, une carapace qui file — vit dans ItemManager.

enum { NONE, MUSHROOM, TRIPLE_MUSHROOM, BANANA, GREEN_SHELL, RED_SHELL,
	BLUE_SHELL, LIGHTNING, STAR, FAKE_BOX, COINS }

## Ceux qu'une boîte peut donner, dans l'ordre des colonnes de ItemTable.
const TIRABLES: Array[int] = [MUSHROOM, TRIPLE_MUSHROOM, BANANA, GREEN_SHELL, RED_SHELL,
	BLUE_SHELL, LIGHTNING, STAR, FAKE_BOX, COINS]


static func nom(objet: int) -> String:
	match objet:
		MUSHROOM: return "Champignon"
		TRIPLE_MUSHROOM: return "Triple champignon"
		BANANA: return "Banane"
		GREEN_SHELL: return "Carapace verte"
		RED_SHELL: return "Carapace rouge"
		BLUE_SHELL: return "Carapace bleue"
		LIGHTNING: return "Éclair"
		STAR: return "Étoile"
		FAKE_BOX: return "Fausse boîte"
		COINS: return "Pièces"
	return ""
