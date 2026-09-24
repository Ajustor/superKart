class_name RaceSetup
extends RefCounted

## Ce que le joueur a choisi au menu : le mode, la cylindrée, le circuit, le
## nombre de tours et sa case de départ. Rien ici ne touche à la scène — c'est
## RaceLauncher qui en tire une course.

enum Mode {
	## Une course seule, contre l'IA, sur le circuit de son choix.
	COURSE,
	## Une coupe de quatre courses, aux points (GrandPrix).
	GRAND_PRIX,
	## Seul en piste, trois champignons, contre son propre fantôme.
	CONTRE_LA_MONTRE,
}

## Case de départ tirée au sort au lancement de chaque course.
const CASE_ALEATOIRE := 0

## Nombre de karts sur la grille de race.tscn : le menu en tire la liste des
## cases proposées. RaceLauncher, lui, relit la scène.
const CONCURRENTS := 8

var mode: Mode = Mode.COURSE
var classe: int = Cylindree.Classe.CC150
## Le kart du joueur (ModeleKart) et sa couleur, choisis au garage.
var modele: int = ModeleKart.STANDARD
var couleur: int = 0
## Le circuit retourné gauche-droite (Miroir). Se débloque.
var miroir := false
var piste: TrackInfo
var tours: int = 3

## La coupe en cours, en mode GRAND_PRIX.
var grand_prix: GrandPrix

## 1 = pole position. CASE_ALEATOIRE pour laisser le sort décider.
var case_de_depart: int = CASE_ALEATOIRE


func _init() -> void:
	if not TrackCatalog.PISTES.is_empty():
		choisir_piste(TrackCatalog.PISTES[0])


func choisir_piste(info: TrackInfo) -> void:
	piste = info
	tours = info.tours


## La case réellement attribuée, de 1 à `concurrents`. Le tirage se fait ici
## et pas dans la session : la session reçoit une case, elle ne joue pas aux dés.
func case_effective(concurrents: int, rng: RandomNumberGenerator) -> int:
	if case_de_depart == CASE_ALEATOIRE:
		return rng.randi_range(1, concurrents)
	return clampi(case_de_depart, 1, concurrents)


## Commence une coupe : la première manche devient la course à lancer.
func commencer_grand_prix(coupe: int) -> void:
	mode = Mode.GRAND_PRIX
	grand_prix = GrandPrix.new(coupe, classe)
	grand_prix.miroir = miroir
	preparer_manche()


## Règle la course sur la manche courante de la coupe.
func preparer_manche() -> void:
	if grand_prix == null:
		return
	classe = grand_prix.classe
	miroir = grand_prix.miroir
	choisir_piste(grand_prix.piste())


## La cylindrée réellement courue : le contre-la-montre se court en 150cc,
## comme dans Mario Kart, pour que les records se comparent.
func classe_effective() -> int:
	return Cylindree.Classe.CC150 if mode == Mode.CONTRE_LA_MONTRE else classe


## Clé des records de ce réglage. En 150cc, c'est l'identifiant du circuit
## seul, comme avant l'arrivée des cylindrées : les records déjà enregistrés
## restent valables. Le contre-la-montre a ses propres records.
func cle_record() -> String:
	if piste == null:
		return ""
	var cle := piste.id
	if mode == Mode.CONTRE_LA_MONTRE:
		cle = "%s@clm" % piste.id
	elif classe != Cylindree.Classe.CC150:
		cle = "%s@%s" % [piste.id, Cylindree.nom(classe)]
	# Le miroir est un autre circuit : ses records sont à part.
	return cle + "@miroir" if miroir else cle
