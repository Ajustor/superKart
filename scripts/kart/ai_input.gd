class_name AIInput
extends KartInput

## Pilote automatique. Elle vise un point de la route situé à une
## demi-seconde de trajet devant elle, mesure l'écart entre son cap et la
## direction de ce point, et en tire un braquage.
##
## Ce point n'est pas sur un rail : l'IA court comme un joueur. Sa ligne
## s'écarte lentement de la ligne idéale, à sa façon ; elle double par le côté
## libre, ferme la porte à qui la talonne, va chercher les boîtes, garde un
## champignon pour la ligne droite et lâche sa banane sous le nez de son
## poursuivant. Et elle se trompe parfois — d'autant moins qu'elle est forte.
##
## Elle passe par le même KartCommand que le joueur, donc elle est enfermée
## dans la même physique : elle ne peut pas prendre un virage que le joueur ne
## pourrait pas prendre, et elle dérape pour de vrai, avec les mêmes étincelles.
##
## Tous les angles sont des caps boussole — positif vers la droite — comme dans
## KartMotor et TrackCurve. Aucune rotation Godot n'apparaît ici.

## Durée de trajet qui sépare le kart de son point de mire. Plus elle est
## grande, plus l'IA anticipe et plus ses trajectoires sont propres.
@export var aim_time: float = 0.45

## Distance de mire minimale, en mètres. Sans elle, un kart à l'arrêt viserait
## ses propres roues et ne démarrerait jamais.
@export var aim_minimum: float = 6.0

## Écart de cap, en degrés, au-delà duquel l'IA braque à fond.
@export var full_steer_angle_deg: float = 20.0

## Rayon du virage visé, en mètres, en deçà duquel l'IA engage le dérapage.
##
## Sur la sévérité du virage, et non sur son propre écart de cap. Mesuré :
## avec l'ancienne règle, l'écart de cap de l'IA culminait à 16,2° dans
## l'épingle contre un seuil de 32°, donc elle ne dérapait jamais — et plus
## elle suivait bien sa ligne, moins elle dérapait, ce qui est exactement
## l'inverse de ce qu'on veut. Un joueur dérape parce qu'il voit arriver le
## virage, pas parce qu'il a déjà raté sa trajectoire.
@export var drift_entry_radius: float = 30.0

## Rayon au-delà duquel elle lâche une glisse en cours. Plus large que
## l'entrée, pour ne pas battre de l'aile à la frontière du virage.
##
## Balayé sur track_01, trois tours à chaque fois : 34 m donne 0,42 s de charge
## et 6,77 m d'écart, 42 m donne 0,50 s et 7,40 m, 50 m donne 0,55 s et 8,00 m,
## 60 m atteint enfin le palier 1 mais à 9,21 m — hors d'une piste qui en fait
## 9,00. On garde la glisse la plus longue qui reste sur le bitume.
@export var drift_exit_radius: float = 55.0

## Palier de mini-turbo visé avant de lâcher, de 1 à 3. Une IA gourmande tient
## la glisse plus longtemps et sort plus vite — c'est un des quatre leviers de
## difficulté, et le seul qui se voie à l'œil nu.
@export var drift_release_tier: int = 2

## Décalage moyen par rapport à la ligne idéale, en mètres vers la droite :
## la ligne préférée de ce pilote. Il s'en écarte en roulant (voir FLANERIE).
@export var lateral_bias: float = 0.0

## Le tempérament, de 0 à 1. Audace : doubler plus tôt, fermer la porte à
## qui la talonne. Régularité : 1 ne se trompe jamais ; plus bas, une erreur
## de temps en temps (trajectoire trop large, hésitation, glisse ratée).
@export var audace: float = 0.5
@export var regularite: float = 0.85

## Ses habitudes, comme celles d'un joueur : la chance qu'elle glisse dans un
## virage, qu'elle fasse une figure dans un saut, et qu'elle s'écarte de sa
## ligne pour passer sur une plaque d'accélération. Tirée une fois par
## virage, par saut, par plaque : elle ne joue pas deux fois le même tour.
## À 1 (par défaut), elle le fait toujours, comme l'IA d'avant.
@export_range(0.0, 1.0) var envie_de_glisser: float = 1.0
@export_range(0.0, 1.0) var envie_de_figures: float = 1.0
@export_range(0.0, 1.0) var envie_de_plaques: float = 1.0

## Intervalle entre deux décisions, en secondes. Zéro veut dire une décision
## par image. Au-delà, l'IA tient sa commande précédente : elle braque en
## retard plutôt que mollement, ce qui est la façon dont un humain rate un
## virage.
@export var reaction_delay: float = 0.0

## Contre-braquage maximal que l'IA s'autorise pendant une glisse, en part
## d'inversion. Le moteur casse la glisse au-delà de -0,8 : mesuré sur
## track_01, l'épingle fait 18 m de rayon quand le dérapage en décrit 8,5 à
## 11, donc l'IA sur-tournait, contre-braquait à fond et cassait sa propre
## glisse en six images — jamais un seul mini-turbo encaissé. Un pilote
## contre-braque dans la glisse, pas assez fort pour la perdre.
##
## Ramené de -0,7 à -0,4 quand le contre-braquage a ouvert la glisse presque en
## ligne droite (KartStats.drift_rapport_exterieur) : -0,4 donne aujourd'hui
## la courbe que -0,7 donnait avant, et l'IA, réglée sur celle-là, ne se
## mettait plus à zigzaguer dans ses glisses.
const CONTRE_BRAQUAGE_MAX := -0.4
## Dans une grande courbe, elle ouvre sa glisse jusque-là (le moteur la casse
## à -0,8).
const CONTRE_BRAQUAGE_LARGE := -0.72
const ECART_GLISSE_MAX := 3.0

## Renseignés par la session avant chaque image. Les lire soi-même coûterait
## une projection de plus par kart, et global_position interdirait de tester
## cette classe hors de l'arbre.
var track: TrackCurve
var distance: float = 0.0
var position := Vector3.ZERO

## Renseignés par ItemManager : l'objet prêt dans l'emplacement (NONE sinon),
## si l'IA mène la course, et l'avance qu'elle a sur son poursuivant, en mètres.
var objet_pret: int = ItemKind.NONE
var en_tete: bool = false
var ecart_poursuivant: float = INF
## L'objet est tenu derrière le kart (voir ItemManager).
var objet_tenu: bool = false
var _tenu_depuis: float = 0.0

## Écart, en mètres, sous lequel une IA en tête lâche la banane qu'elle garde
## en protection : le poursuivant est assez près pour rouler dessus.
const ALERTE_POURSUIVANT := 12.0

## Ce que la session dit des autres : un Vector3 par concurrent (distance le
## long de l'axe, écart latéral, vitesse), dans l'ordre de la session, et la
## place de cette IA dans ce tableau. Vide hors course (et dans les tests qui
## ne la renseignent pas) : l'IA roule alors seule, comme avant.
var voisins := PackedVector3Array()
var mon_index: int = -1
## Écart latéral de la boîte la plus proche devant, quand l'emplacement est
## vide ; NAN sinon (renseigné par ItemManager).
var boite_laterale: float = NAN
## Les portions (début, fin) où l'on ne joue pas : avant une rampe ou un trou,
## on reprend sa ligne et on ne se trompe pas. Donné par la session.
var zones_prudentes := PackedVector2Array()
## Les plaques d'accélération du circuit : (début, longueur, décalage,
## largeur). Données par la session.
var plaques := PackedVector4Array()

## La ligne qu'elle se donne s'écarte de sa ligne préférée d'au plus ça, en
## mètres, et lentement : deux ondes de quelques secondes, propres à chacune.
const FLANERIE := 1.4
## Une IA s'écarte de la ligne au plus à cette vitesse, en m/s : elle change
## de trajectoire, elle ne zigzague pas.
const CHANGEMENT_DE_LIGNE := 3.0
## La route qu'elle s'autorise : jamais plus près du bord que ça.
const MARGE_BORD := 1.8
## Une plaque d'accélération se repère à cette distance (m) : de quoi
## changer de ligne avant d'arriver dessus.
const PORTEE_PLAQUE := 40.0
## Pas d'objet lâché ni lancé à moins de ça (m) en amont d'une portion
## prudente, en plus de la portion elle-même.
const MARGE_OBJETS := 40.0
## On double un kart qui est devant, à moins de ça, et dans notre file.
const PORTEE_DEPASSEMENT := 16.0
const LARGEUR_FILE := 2.2
const ECART_DEPASSEMENT := 2.6
## On ferme la porte à un kart qui nous talonne à moins de ça.
const PORTEE_DEFENSE := 9.0
## Une carapace part sur un kart devant, à moins de ça, dans notre file.
const PORTEE_TIR := 32.0
## Un champignon attend un virage moins serré que ça… pas plus que ça.
const RAYON_CHAMPIGNON := 45.0
const ATTENTE_CHAMPIGNON := 4.0
const ATTENTE_TENU_MAX := 9.0

enum Erreur { AUCUNE, LARGE, HESITATION, GLISSE_RATEE }

var _rng := RandomNumberGenerator.new()
var _temps: float = 0.0
var _phases := Vector3.ZERO
## L'écart à l'axe qu'elle vise maintenant, en mètres, et celui qu'elle
## voudrait (vers lequel le premier glisse doucement).
var _lateral: float = NAN
var _cote_depassement: float = 0.0
var _depassement_reste: float = 0.0
var _erreur: int = Erreur.AUCUNE
var _erreur_reste: float = 0.0
var _champignon_depuis: float = 0.0
## Le virage en cours : glisse-t-elle dans celui-ci, et jusqu'à quel palier ?
var _dans_un_virage := false
var _glisse_ce_virage := true
var _palier_ce_virage: int = 0
## Le saut en cours : figure prévue, et à quel moment du vol.
var _en_vol := false
var _vol: float = 0.0
var _figure_prevue := false
var _moment_figure: float = 0.0
## Plaque (son indice) -> y va-t-elle ? Tiré quand elle la voit venir.
var _plaques_choisies: Dictionary = {}

var _depuis_decision: float = 0.0
var _steer_decide: float = 0.0
var _drift_decide: bool = false
var _jamais_decide: bool = true


func _ready() -> void:
	_rng.randomize()
	_phases = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf_range(0.18, 0.32))


## Distance de mire le long de l'axe : là où l'IA regarde.
func distance_visee() -> float:
	return distance + maxf(kart.motor.speed * aim_time, aim_minimum)


## Le point de mire, sur la ligne de course, devant le kart. Le biais latéral
## s'applique à ce point et non à la distance : viser à côté ne veut pas dire
## viser plus loin.
func point_vise() -> Vector3:
	var ou := distance_visee()
	if is_nan(_lateral):
		return track.racing_line_at(ou) + track.right_at(ou) * lateral_bias
	return track.position_at(ou) + track.right_at(ou) * _lateral


## L'écart à l'axe que l'IA s'est choisi, NAN tant qu'elle ne l'a pas fait.
func ligne_visee() -> float:
	return _lateral


## L'écart à l'axe de la ligne idéale, à cette distance.
func lateral_de_la_ligne(ou: float) -> float:
	return (track.racing_line_at(ou) - track.position_at(ou)).dot(track.right_at(ou))


func _fill(delta: float) -> void:
	_temps += delta
	if track != null:
		_choisir_sa_ligne(delta)
	_vivre_ses_erreurs(delta)
	_depuis_decision += delta
	if _jamais_decide or _depuis_decision >= reaction_delay:
		_jamais_decide = false
		_depuis_decision = 0.0
		_steer_decide = _braquage()
		_drift_decide = _veut_deraper() and _erreur != Erreur.GLISSE_RATEE

	command.throttle = 0.72 if _erreur == Erreur.HESITATION else 1.0
	_objet(delta)
	command.drift = _drift_decide
	command.steer = _brider_pour_tenir_la_glisse(_steer_decide)
	_figure_en_vol(delta)


## En l'air après un tremplin ou une rampe : un appui sur la glisse fait la
## figure (voir Kart._figures). Pas à tous les sauts, ni au même moment.
func _figure_en_vol(delta: float) -> void:
	if kart == null or not kart.en_saut or kart.au_sol:
		_en_vol = false
		return
	if not _en_vol:
		_en_vol = true
		_vol = 0.0
		_figure_prevue = _tirer(envie_de_figures)
		_moment_figure = 0.1 if envie_de_figures >= 1.0 else _rng.randf_range(0.06, 0.3)
	_vol += delta
	# Relâchée jusqu'au moment choisi : l'appui qui suit est un vrai appui,
	# même si elle tenait la glisse en décollant.
	command.drift = _figure_prevue and _vol >= _moment_figure


## Vrai avec cette probabilité ; toujours à 1, jamais à 0.
func _tirer(chance: float) -> bool:
	return chance >= 1.0 or (chance > 0.0 and _rng.randf() < chance)


# --- La course des autres -----------------------------------------------------

## Le kart `i` vu d'ici : [avance le long de la route (positive devant),
## écart latéral, vitesse].
func _relatif(i: int) -> Vector3:
	var autre := voisins[i]
	var moi := voisins[mon_index]
	var avance := wrapf(autre.x - moi.x, -track.length * 0.5, track.length * 0.5)
	return Vector3(avance, autre.y, autre.z)


func _connait_la_course() -> bool:
	return track != null and mon_index >= 0 and mon_index < voisins.size()


## Le kart le plus proche devant, dans notre file, à moins de `portee` : son
## indice, ou -1.
func kart_devant(portee: float, file: float) -> int:
	if not _connait_la_course():
		return -1
	var mon_lateral := voisins[mon_index].y
	var meilleur := -1
	var plus_pres := portee
	for i in voisins.size():
		if i == mon_index:
			continue
		var r := _relatif(i)
		if r.x > 1.0 and r.x < plus_pres and absf(r.y - mon_lateral) < file:
			plus_pres = r.x
			meilleur = i
	return meilleur


## Le kart le plus proche derrière, à moins de `portee` : son indice, ou -1.
func kart_derriere(portee: float) -> int:
	if not _connait_la_course():
		return -1
	var meilleur := -1
	var plus_pres := portee
	for i in voisins.size():
		if i == mon_index:
			continue
		var r := _relatif(i)
		if r.x < -1.0 and -r.x < plus_pres:
			plus_pres = -r.x
			meilleur = i
	return meilleur


## La ligne que l'IA se donne, en écart à l'axe, et qu'elle rejoint doucement.
## Par ordre de priorité : doubler, fermer la porte, aller chercher une boîte,
## et sinon sa ligne à elle, qui flâne autour de la ligne idéale.
func _choisir_sa_ligne(delta: float) -> void:
	var ou := distance_visee()
	var ligne := lateral_de_la_ligne(ou)
	var rayon := track.radius_at(ou)
	# Dans un virage serré, on colle à la ligne : c'est là que la route se
	# paie, et qu'un écart finit au mur.
	var liberte := clampf((rayon - 15.0) / 45.0, 0.15, 1.0) if rayon < INF else 1.0
	var flanerie := (sin(_temps * _phases.z + _phases.x) * 0.7 + sin(_temps * _phases.z * 2.3 + _phases.y) * 0.3) \
		* FLANERIE * liberte
	var voulu := ligne + (lateral_bias + flanerie) * liberte
	if prudente():
		# Une rampe, un trou : on ne joue plus, on prend son élan droit.
		_depassement_reste = 0.0
		_aller_vers(ligne + lateral_bias, delta)
		return

	_depassement_reste = maxf(_depassement_reste - delta, 0.0)
	var devant := kart_devant(PORTEE_DEPASSEMENT, LARGEUR_FILE)
	# Dans une ligne droite, on se cale d'abord dans son sillage : la jauge
	# d'aspiration se remplit, et c'est avec son turbo qu'on double.
	var sillage := kart_devant(Aspiration.PORTEE, LARGEUR_FILE)
	if veut_aspirer(sillage, liberte):
		_depassement_reste = 0.0
		_aller_vers(voisins[sillage].y, delta)
		return
	if devant >= 0 and (voisins[mon_index].z > voisins[devant].z - 0.5 or audace > 0.6):
		if _depassement_reste <= 0.0:
			_cote_depassement = cote_pour_doubler(voisins[devant].y)
		_depassement_reste = 1.5
	if _depassement_reste > 0.0 and devant >= 0:
		voulu = voisins[devant].y + _cote_depassement * ECART_DEPASSEMENT
	elif audace >= 0.5 and liberte > 0.8:
		var derriere := kart_derriere(PORTEE_DEFENSE)
		if derriere >= 0 and voisins[derriere].z > voisins[mon_index].z - 1.0:
			# Fermer la porte : se décaler vers le côté du poursuivant, sans
			# aller jusqu'à lui — un pilote couvre l'intérieur, il ne freine
			# pas devant le capot de l'autre.
			voulu = lerpf(voulu, voisins[derriere].y, 0.4 + 0.3 * audace)
	if devant < 0 and not is_nan(boite_laterale):
		voulu = lerpf(voulu, boite_laterale, 0.8)
	var plaque := plaque_visee()
	if devant < 0 and not is_nan(plaque):
		voulu = plaque

	if _erreur == Erreur.LARGE:
		# La trajectoire trop large : poussée vers l'extérieur du virage.
		voulu -= signf(track.turn_at(ou)) * 2.0

	_aller_vers(voulu, delta)


## Se caler derrière le kart `i` pour l'aspiration ? Seulement dans une
## ligne droite (`liberte` : la route est large devant), pas trop près, sans
## turbo en cours — c'est le turbo qui sert à doubler — et tant que la jauge
## n'est pas pleine.
func veut_aspirer(i: int, liberte: float) -> bool:
	if i < 0 or kart == null or liberte < 0.9:
		return false
	if kart.motor.boost_timer > 0.0 or kart.aspiration >= 0.95:
		return false
	var avance := _relatif(i).x
	return avance > Aspiration.PORTEE_MIN + 1.0 and voisins[i].z >= Aspiration.VITESSE_DU_MENEUR


func _aller_vers(voulu: float, delta: float) -> void:
	var bord := track.half_width - MARGE_BORD
	voulu = clampf(voulu, -bord, bord)
	if is_nan(_lateral):
		_lateral = voulu
	_lateral = move_toward(_lateral, voulu, CHANGEMENT_DE_LIGNE * delta)


## Le décalage de la plaque d'accélération qu'elle a décidé d'aller prendre,
## devant ou sous elle ; NAN sinon. Chaque plaque est tirée une fois, quand
## elle entre en vue, et oubliée une fois passée.
func plaque_visee() -> float:
	var visee := NAN
	for i in plaques.size():
		var p := plaques[i]
		var devant := wrapf(p.x - distance, 0.0, track.length)
		var dessus := wrapf(distance - p.x, 0.0, track.length) <= p.y
		if devant > PORTEE_PLAQUE and not dessus:
			_plaques_choisies.erase(i)
			continue
		if not _plaques_choisies.has(i):
			_plaques_choisies[i] = _tirer(envie_de_plaques)
		if _plaques_choisies[i] and is_nan(visee):
			visee = p.z
	return visee


## Le kart est-il dans une portion où l'on ne joue pas ?
## `avant` l'étend en amont : un objet lâché là traînerait encore sur l'élan.
func prudente(avant: float = 0.0) -> bool:
	if track == null:
		return false
	for zone in zones_prudentes:
		if wrapf(distance - zone.x + avant, 0.0, track.length) <= zone.y - zone.x + avant:
			return true
	return false


## Le côté par où doubler un kart placé à `son_lateral` : celui où la route
## laisse le plus de place. +1 à droite, -1 à gauche.
func cote_pour_doubler(son_lateral: float) -> float:
	var a_droite := track.half_width - son_lateral
	var a_gauche := son_lateral + track.half_width
	return 1.0 if a_droite >= a_gauche else -1.0


## Une erreur de temps en temps, d'autant plus rare que l'IA est régulière,
## et jamais deux à la fois.
func _vivre_ses_erreurs(delta: float) -> void:
	if prudente():
		_erreur = Erreur.AUCUNE
		return
	if _erreur != Erreur.AUCUNE:
		_erreur_reste -= delta
		if _erreur_reste <= 0.0:
			_erreur = Erreur.AUCUNE
		return
	var frequence := (1.0 - regularite) * 0.12
	if _rng.randf() < frequence * delta:
		_erreur = _rng.randi_range(Erreur.LARGE, Erreur.GLISSE_RATEE)
		_erreur_reste = _rng.randf_range(0.6, 1.2)


func erreur_en_cours() -> int:
	return _erreur


## En tête, une banane ou une carapace verte reste derrière le kart, en
## bouclier ; elle part vers l'arrière quand un poursuivant approche. Le reste
## part dès que c'est prêt.
func _objet(delta: float) -> void:
	if objet_tenu:
		_tenu_depuis += delta
		# Tenu au moins le temps d'un vrai maintien : relâché trop tôt, le
		# lâcher compterait pour un appui bref, et la verte partirait devant.
		var minimum := _tenu_depuis < ItemManager.SEUIL_TAPE + 0.05
		var cible := _cible_alignee_devant()
		command.item_held = minimum or (veut_garder_derriere() and not cible and _tenu_depuis < ATTENTE_TENU_MAX)
		# Une carapace part sur qui est aligné devant ; sinon, tout part
		# derrière, sur le poursuivant.
		var carapace := objet_pret in [ItemKind.GREEN_SHELL, ItemKind.RED_SHELL]
		command.throw_back = not (carapace and (cible or _tenu_depuis >= ATTENTE_TENU_MAX))
		if prudente(MARGE_OBJETS):
			# Rien ne tombe sur l'élan d'un saut : un kart qui y glisse
			# n'aurait plus de quoi passer le trou.
			command.item_held = true
		return
	_tenu_depuis = 0.0
	var champignon := objet_pret in [ItemKind.MUSHROOM, ItemKind.TRIPLE_MUSHROOM]
	if prudente(MARGE_OBJETS) and not champignon:
		return
	if veut_garder_derriere():
		command.use_item = true
		command.item_held = true
	elif veut_utiliser_objet():
		command.use_item = true
	if champignon:
		_champignon_depuis += delta
	else:
		_champignon_depuis = 0.0


## Garder l'objet derrière soi : en tête, ou faute de mieux. Une banane ou une
## fausse boîte traîne en bouclier tant que personne n'est assez près pour
## rouler dessus ; une carapace aussi, tant que personne n'est à viser devant.
func veut_garder_derriere() -> bool:
	if not objet_pret in [ItemKind.BANANA, ItemKind.FAKE_BOX, ItemKind.GREEN_SHELL, ItemKind.RED_SHELL]:
		return false
	if objet_pret == ItemKind.RED_SHELL and not en_tete:
		return false
	var poursuivant := _poursuivant_proche()
	if not _connait_la_course():
		return en_tete and not poursuivant and objet_pret != ItemKind.RED_SHELL
	if objet_pret == ItemKind.GREEN_SHELL and _cible_alignee_devant():
		return false
	return not poursuivant


func _poursuivant_proche() -> bool:
	if _connait_la_course():
		return kart_derriere(ALERTE_POURSUIVANT) >= 0
	return ecart_poursuivant < ALERTE_POURSUIVANT


## Quelqu'un à viser devant, dans notre file. Faute d'en savoir plus (hors
## course), on suppose que oui : la carapace part, comme avant.
func _cible_alignee_devant() -> bool:
	if not _connait_la_course():
		return true
	return kart_devant(PORTEE_TIR, LARGEUR_FILE * 1.2) >= 0


## La politique d'objets de la spec, volontairement simple : utiliser dès que
## c'est prêt, sauf garder une banane en protection quand on est en tête, et la
## lâcher quand un poursuivant approche.
func veut_utiliser_objet() -> bool:
	if objet_pret == ItemKind.NONE:
		return false
	if (objet_pret == ItemKind.BANANA or objet_pret == ItemKind.FAKE_BOX) and en_tete:
		return ecart_poursuivant < ALERTE_POURSUIVANT
	if objet_pret in [ItemKind.MUSHROOM, ItemKind.TRIPLE_MUSHROOM] and track != null:
		# Le champignon attend la ligne droite (ou de quoi doubler) : en
		# plein virage serré, il envoie au mur.
		var droit := track.radius_at(distance_visee()) > RAYON_CHAMPIGNON
		return droit or kart_devant(12.0, LARGEUR_FILE) >= 0 or _champignon_depuis > ATTENTE_CHAMPIGNON
	if objet_pret == ItemKind.GREEN_SHELL:
		return _cible_alignee_devant()
	return true


## Écart de cap entre la direction du kart et celle du point de mire, en
## radians, ramené dans [-PI, PI]. Positif = la cible est à droite.
func ecart_de_cap() -> float:
	var vers := point_vise() - position
	vers.y = 0.0
	if vers.length_squared() < 0.0001:
		return 0.0
	var cap_voulu := atan2(vers.x, -vers.z)
	return wrapf(cap_voulu - kart.motor.heading, -PI, PI)


func _braquage() -> float:
	var plein := deg_to_rad(full_steer_angle_deg)
	return clampf(ecart_de_cap() / plein, -1.0, 1.0)


## Rabote le contre-braquage tant qu'on veut garder la glisse. Appliqué après
## la décision et non dedans : quand l'IA veut sortir, elle contre-braque
## librement, et c'est justement ce qui la fait sortir vite.
func _brider_pour_tenir_la_glisse(braquage: float) -> float:
	if not _drift_decide or kart.motor.state != KartMotor.State.DRIFT:
		return braquage
	var sens := float(kart.motor.drift_dir)
	if sens == 0.0:
		return braquage
	return maxf(braquage * sens, contre_braquage_permis()) * sens


## Le contre-braquage qu'elle s'autorise en glisse : modéré dans une épingle,
## presque jusqu'à la casse dans une grande courbe, où la glisse doit s'ouvrir
## pour suivre la route (KartStats.drift_rapport_exterieur).
func contre_braquage_permis() -> float:
	if track == null:
		return CONTRE_BRAQUAGE_MAX
	var rayon := track.radius_at(distance)
	var ouverture := clampf((rayon - 20.0) / 30.0, 0.0, 1.0) if rayon < INF else 1.0
	return lerpf(CONTRE_BRAQUAGE_MAX, CONTRE_BRAQUAGE_LARGE, ouverture)


## Elle a quitté sa ligne de plus de ça en glisse : elle lâche, comme un joueur
## qui sent qu'il part au mur.
func glisse_qui_derape() -> bool:
	if track == null or is_nan(_lateral):
		return false
	var ecart := (position - track.position_at(distance)).dot(track.right_at(distance)) - _lateral
	return absf(ecart) > ECART_GLISSE_MAX


## Distance à laquelle on juge la sévérité du virage. Bien plus courte que la
## mire du braquage, et pour une raison mesurée : à 0,45 s d'anticipation,
## l'IA visait déjà 10 m après l'apex quand ses roues entraient dans l'épingle.
## Elle engageait donc la glisse à 399 m sur un rayon vu de 17,8 m, et la
## relâchait à 411 m parce que sa mire lisait 35,9 m — six images de glisse,
## pile au moment où il aurait fallu la tenir.
##
## Le braquage doit regarder loin, la glisse doit regarder où l'on est. Seule
## l'entrée anticipe, d'une longueur de saut : le temps de décoller, et la
## glisse commence quand le virage commence.
func _distance_de_decision() -> float:
	if kart.motor.state == KartMotor.State.GRIP:
		return distance + kart.motor.speed * kart.stats.hop_duration
	return distance


## Le dérapage se décide comme le joueur appuie : un booléen, rien de plus.
## Le moteur reste seul juge de ce qu'il en fait — c'est lui qui exige un
## braquage suffisant à l'entrée et qui verrouille le sens de la glisse.
func _veut_deraper() -> bool:
	if kart.motor.speed < kart.stats.min_drift_speed:
		return false
	# Pas de glisse sur l'élan d'un saut, sur le verglas ni dans le vent :
	# le petit bond d'entrée, pris au bord d'une rampe, l'empêche de décoller.
	if prudente():
		return false

	var rayon := track.radius_at(_distance_de_decision())
	_suivre_le_virage(rayon)
	var palier_vise := _palier_ce_virage if _palier_ce_virage > 0 else drift_release_tier

	# Le saut fait partie de l'engagement : un joueur garde la gâchette
	# enfoncée pendant qu'il décolle. En repassant par le seuil d'entrée,
	# étroit, l'IA le ratait d'une image et retombait en adhérence — trois
	# sauts par tour, pas une seule glisse.
	if kart.motor.state == KartMotor.State.HOP:
		return rayon < drift_exit_radius

	if kart.motor.state == KartMotor.State.DRIFT and glisse_qui_derape():
		return false

	if kart.motor.state == KartMotor.State.DRIFT:
		# Une glisse tenue en ligne droite finit dans le décor, et une glisse
		# lâchée trop tôt ne rapporte rien : on sort au premier des deux.
		var palier := kart.motor.tier_for_charge(kart.motor.drift_charge)
		return palier < palier_vise and rayon < drift_exit_radius

	return rayon < drift_entry_radius and _glisse_ce_virage


## À l'entrée de chaque virage, elle décide si elle y glisse et jusqu'à quel
## palier : parfois elle le passe en adhérence, parfois elle lâche son
## mini-turbo un palier plus tôt, comme un joueur qui ne tente pas tout.
func _suivre_le_virage(rayon: float) -> void:
	if not _dans_un_virage and rayon < drift_entry_radius:
		_dans_un_virage = true
		_glisse_ce_virage = _tirer(envie_de_glisser)
		_palier_ce_virage = drift_release_tier
		if envie_de_glisser < 1.0 and _rng.randf() < 0.3:
			_palier_ce_virage = clampi(drift_release_tier + (1 if _rng.randf() < 0.4 else -1), 1, 3)
	elif _dans_un_virage and rayon > drift_exit_radius:
		_dans_un_virage = false
