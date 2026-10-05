class_name Aspiration
extends RefCounted

## L'aspiration : rouler dans le sillage d'un autre kart, juste derrière lui,
## remplit une jauge ; pleine, elle lance un turbo qui sert à le doubler.
## Comme dans les jeux de kart : coller un adversaire paie, à condition de
## rester dans son axe le temps qu'il faut.
##
## Purement géométrique : ni arbre de scènes, ni temps réel. RaceSession lui
## donne les positions et les caps, et tient la jauge de chaque concurrent.

## Le sillage commence à un mètre et demi derrière le meneur et s'étend
## jusqu'à seize mètres.
const PORTEE_MIN := 1.5
const PORTEE := 16.0
## Demi-largeur du sillage : un peu plus qu'un kart, il faut viser.
const LARGEUR := 2.0
## Au-delà de cet écart de hauteur, l'autre roule sur un autre étage.
const ECART_DE_HAUTEUR := 3.0
## Le meneur doit aller dans le même sens (cosinus de l'écart de cap).
const MEME_CAP := 0.85
## On n'aspire qu'à bonne allure, en fraction de la vitesse de pointe ; et
## un meneur arrêté n'a pas de sillage.
const VITESSE_MIN := 0.6
const VITESSE_DU_MENEUR := 8.0
## Secondes dans le sillage pour remplir la jauge.
const CHARGE := 1.2
## Hors du sillage, la jauge se vide deux fois plus vite qu'elle ne se
## remplit : on ne la garde pas d'un adversaire à l'autre.
const DECHARGE := 2.0
## Le turbo d'aspiration : plus doux qu'un champignon, assez pour passer.
const DUREE_TURBO := 5.0
const FORCE_TURBO := 1.25


## Le cap horizontal d'un kart, d'après le lacet de sa trajectoire
## (KartMotor.velocity_dir).
static func cap(lacet: float) -> Vector3:
	return Vector3(sin(lacet), 0.0, -cos(lacet))


## Vrai si le suiveur, en `suiveur` et allant selon `cap_suiveur`, roule dans
## le sillage du meneur, en `meneur` et allant selon `cap_meneur`.
static func dans_le_sillage(suiveur: Vector3, cap_suiveur: Vector3, meneur: Vector3, cap_meneur: Vector3) -> bool:
	var ecart := meneur - suiveur
	if absf(ecart.y) > ECART_DE_HAUTEUR:
		return false
	if cap_suiveur.dot(cap_meneur) < MEME_CAP:
		return false
	var devant := ecart.x * cap_suiveur.x + ecart.z * cap_suiveur.z
	if devant < PORTEE_MIN or devant > PORTEE:
		return false
	var cote := absf(ecart.x * -cap_suiveur.z + ecart.z * cap_suiveur.x)
	return cote <= LARGEUR


## La jauge après `delta` secondes, dans le sillage ou non. Renvoie aussi si
## elle vient de se remplir : [jauge, plein].
static func charger(jauge: float, aspire: bool, delta: float) -> Array:
	if not aspire:
		return [maxf(jauge - delta * DECHARGE, 0.0), false]
	jauge += delta
	if jauge >= CHARGE:
		return [0.0, true]
	return [jauge, false]
