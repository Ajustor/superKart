class_name Musique
extends RefCounted

## La musique des circuits, composée par le jeu lui-même : comme les bruitages
## (Synth), elle est calculée plutôt qu'enregistrée, et le dépôt ne porte
## aucun fichier audio.
##
## Une boucle de huit mesures par style : une basse, une mélodie, un arpège
## et une batterie, sur une grille d'accords. La mélodie est tirée d'une
## graine propre au style, toujours la même : chaque circuit a son air, qu'on
## retrouve d'une course à l'autre.
##
## Composer prend du temps (quelques secondes sur téléphone) : c'est fait
## dans un fil à part, et chaque boucle n'est composée qu'une fois par
## partie (cache).

enum Style { COLLINES, PLAGE, FORTERESSE, CIEL, JARDIN, MINE, VILLE, NEIGE, CANYON, USINE, ESPACE, HANTE, GLACE, JUNGLE, PIRATE, ORAGE, ABYSSES, ASCENSION, MANEGE, MONTAGNE, MENU,
	TEMPS, RECIF, LUNE, CUBES, SAISONS, LABO, ESCHER, ETOILES }

const FREQUENCE := 16000
const MESURES := 8

## Tempo, tonique (note MIDI), gamme (demi-tons), grille (degrés de la gamme,
## un accord par mesure, répétée), rythme de la basse, et l'octave de l'arpège.
const STYLES := {
	Style.COLLINES: {
		tempo = 132.0, tonique = 60, gamme = [0, 2, 4, 5, 7, 9, 11],
		grille = [0, 4, 5, 3], basse = [1, 0, 1, 1, 0, 1, 1, 0], arpege = 12, graine = 11,
	},
	Style.PLAGE: {
		tempo = 118.0, tonique = 62, gamme = [0, 2, 4, 5, 7, 9, 11],
		grille = [0, 3, 4, 3], basse = [1, 0, 0, 1, 0, 0, 1, 0], arpege = 12, graine = 27,
	},
	Style.FORTERESSE: {
		tempo = 148.0, tonique = 57, gamme = [0, 2, 3, 5, 7, 8, 11],
		grille = [0, 5, 6, 4], basse = [1, 1, 1, 1, 1, 1, 1, 1], arpege = 0, graine = 5,
	},
	Style.CIEL: {
		tempo = 116.0, tonique = 65, gamme = [0, 2, 4, 6, 7, 9, 11],
		grille = [0, 2, 3, 4], basse = [1, 0, 0, 0, 1, 0, 0, 0], arpege = 24, graine = 42,
	},
	# Sautillant, en majeur, une basse qui rebondit comme les champignons.
	Style.JARDIN: {
		tempo = 140.0, tonique = 67, gamme = [0, 2, 4, 5, 7, 9, 11],
		grille = [0, 3, 0, 4], basse = [1, 0, 1, 0, 1, 0, 1, 1], arpege = 12, graine = 73,
	},
	# Mystérieux : mineur naturel, lent, arpège grave qui résonne dans la galerie.
	Style.MINE: {
		tempo = 104.0, tonique = 55, gamme = [0, 2, 3, 5, 7, 8, 10],
		grille = [0, 5, 3, 4], basse = [1, 0, 0, 1, 0, 0, 1, 0], arpege = 0, graine = 19,
	},
	# La nuit en ville : dorien, rapide, basse en croches continues.
	Style.VILLE: {
		tempo = 156.0, tonique = 58, gamme = [0, 2, 3, 5, 7, 9, 10],
		grille = [0, 3, 6, 4], basse = [1, 1, 0, 1, 1, 0, 1, 1], arpege = 12, graine = 88,
	},
	# Clochettes de neige : majeur, aigu, arpège très haut.
	Style.NEIGE: {
		tempo = 124.0, tonique = 64, gamme = [0, 2, 4, 5, 7, 9, 11],
		grille = [0, 5, 3, 4], basse = [1, 0, 0, 1, 1, 0, 0, 0], arpege = 24, graine = 57,
	},
	# Western : phrygien dominant, galop de basse, sous le soleil du canyon.
	Style.CANYON: {
		tempo = 136.0, tonique = 57, gamme = [0, 1, 4, 5, 7, 8, 10],
		grille = [0, 1, 0, 6], basse = [1, 0, 1, 1, 0, 1, 1, 0], arpege = 12, graine = 31,
	},
	# Mécanique : mineur, rapide, basse martelée comme une presse.
	Style.USINE: {
		tempo = 152.0, tonique = 52, gamme = [0, 2, 3, 5, 7, 8, 10],
		grille = [0, 0, 5, 6], basse = [1, 1, 1, 1, 1, 1, 1, 1], arpege = 0, graine = 64,
	},
	# L'espace : par tons entiers, lent et flottant, arpège très haut.
	Style.ESPACE: {
		tempo = 108.0, tonique = 62, gamme = [0, 2, 4, 6, 8, 10],
		grille = [0, 2, 4, 1], basse = [1, 0, 0, 0, 0, 0, 1, 0], arpege = 24, graine = 99,
	},
	# Hanté : mineur harmonique, valse grinçante.
	Style.HANTE: {
		tempo = 128.0, tonique = 50, gamme = [0, 2, 3, 5, 7, 8, 11],
		grille = [0, 3, 4, 0], basse = [1, 0, 0, 1, 0, 0, 1, 0], arpege = 12, graine = 13,
	},
	# La glace : lydien, cristallin, arpège très haut qui tinte sous la voûte.
	Style.GLACE: {
		tempo = 112.0, tonique = 66, gamme = [0, 2, 4, 6, 7, 9, 11],
		grille = [0, 4, 1, 5], basse = [1, 0, 0, 0, 1, 0, 1, 0], arpege = 24, graine = 23,
	},
	# Les tambours de la jungle : pentatonique, basse syncopée.
	Style.JUNGLE: {
		tempo = 138.0, tonique = 55, gamme = [0, 2, 4, 7, 9],
		grille = [0, 3, 4, 1], basse = [1, 0, 1, 1, 0, 1, 0, 1], arpege = 12, graine = 47,
	},
	# Une gigue de pirates : dorien, entraînante.
	Style.PIRATE: {
		tempo = 150.0, tonique = 62, gamme = [0, 2, 3, 5, 7, 9, 10],
		grille = [0, 6, 3, 4], basse = [1, 0, 1, 1, 0, 1, 1, 0], arpege = 12, graine = 61,
	},
	# L'orage : mineur harmonique, très rapide, basse martelée.
	Style.ORAGE: {
		tempo = 164.0, tonique = 53, gamme = [0, 2, 3, 5, 7, 8, 11],
		grille = [0, 5, 4, 0], basse = [1, 1, 0, 1, 1, 1, 0, 1], arpege = 24, graine = 77,
	},
	# Les profondeurs : locrien, grave et lourd, basse qui gronde.
	Style.ABYSSES: {
		tempo = 120.0, tonique = 45, gamme = [0, 1, 3, 5, 6, 8, 10],
		grille = [0, 1, 4, 0], basse = [1, 0, 0, 1, 1, 0, 0, 1], arpege = 0, graine = 101,
	},
	# L'ascension : majeur, lumineux, arpège qui grimpe très haut.
	Style.ASCENSION: {
		tempo = 132.0, tonique = 67, gamme = [0, 2, 4, 5, 7, 9, 11],
		grille = [0, 4, 5, 3], basse = [1, 0, 0, 1, 0, 1, 0, 0], arpege = 24, graine = 7,
	},
	# La fête foraine : majeur, très rapide, une basse d'orgue de manège.
	Style.MANEGE: {
		tempo = 168.0, tonique = 60, gamme = [0, 2, 4, 5, 7, 9, 11],
		grille = [0, 4, 0, 5], basse = [1, 0, 1, 0, 1, 0, 1, 0], arpege = 12, graine = 83,
	},
	# La montagne : mixolydien, ample, arpège qui monte comme un col.
	Style.MONTAGNE: {
		tempo = 126.0, tonique = 59, gamme = [0, 2, 4, 5, 7, 9, 10],
		grille = [0, 6, 3, 0], basse = [1, 0, 0, 1, 0, 0, 1, 1], arpege = 24, graine = 37,
	},
	# Le menu : un air d'attente, posé et chantant. La grille des chansons
	# (I, vi, IV, V), un arpège qui ondule, et une batterie à demi-voix : on
	# l'écoute en choisissant sa course, pas en la courant.
	Style.MENU: {
		tempo = 104.0, tonique = 62, gamme = [0, 2, 4, 5, 7, 9, 11],
		grille = [0, 5, 3, 4], basse = [1, 0, 0, 1, 0, 0, 1, 0], arpege = 12, graine = 64,
		batterie = 0.45, charleston = false,
	},
	# Le voyage dans le temps : du rock des années cinquante, majeur, rapide,
	# une basse qui marche sur les douze mesures du blues (I, IV, V).
	Style.TEMPS: {
		tempo = 166.0, tonique = 57, gamme = [0, 2, 4, 5, 7, 9, 10],
		grille = [0, 3, 4, 0], basse = [1, 1, 1, 1, 1, 1, 1, 1], arpege = 12, graine = 85,
	},
	# Sous la mer : une ritournelle hawaïenne, pentatonique majeure, qui
	# se balance comme une vague.
	Style.RECIF: {
		tempo = 112.0, tonique = 64, gamme = [0, 2, 4, 7, 9],
		grille = [0, 3, 4, 3], basse = [1, 0, 0, 1, 0, 1, 0, 0], arpege = 24, graine = 58,
	},
	# La lune qui tombe : mineur harmonique, lent et inquiet, sans charleston.
	Style.LUNE: {
		tempo = 96.0, tonique = 50, gamme = [0, 2, 3, 5, 7, 8, 11],
		grille = [0, 5, 1, 4], basse = [1, 0, 0, 0, 1, 0, 0, 0], arpege = 12, graine = 3,
		batterie = 0.6, charleston = false,
	},
	# Le monde en cubes : un piano calme et rêveur, lydien, qui laisse de la
	# place au silence.
	Style.CUBES: {
		tempo = 100.0, tonique = 60, gamme = [0, 2, 4, 6, 7, 9, 11],
		grille = [0, 4, 5, 3], basse = [1, 0, 0, 0, 0, 0, 1, 0], arpege = 24, graine = 16,
		batterie = 0.5,
	},
	# Les saisons : une valse des quatre temps de l'année, majeure, qui change
	# d'accord à chaque mesure comme le jardin de couleur à chaque portail.
	Style.SAISONS: {
		tempo = 138.0, tonique = 62, gamme = [0, 2, 4, 5, 7, 9, 11],
		grille = [0, 3, 5, 4], basse = [1, 0, 1, 0, 0, 1, 1, 0], arpege = 24, graine = 44,
	},
	# Le labo : froid, mécanique, dorien, une basse en ostinato de machine.
	Style.LABO: {
		tempo = 124.0, tonique = 57, gamme = [0, 2, 3, 5, 7, 9, 10],
		grille = [0, 0, 3, 4], basse = [1, 1, 0, 1, 1, 0, 1, 1], arpege = 12, graine = 91,
		batterie = 0.7,
	},
	# L'escalier sans fin : par tons entiers, une marche qui monte sans jamais
	# arriver.
	Style.ESCHER: {
		tempo = 112.0, tonique = 60, gamme = [0, 2, 4, 6, 8, 10],
		grille = [0, 1, 2, 3], basse = [1, 0, 0, 1, 0, 0, 1, 0], arpege = 24, graine = 27,
		batterie = 0.55, charleston = false,
	},
	# La route des étoiles : épique, éolien, rapide, un arpège très haut.
	Style.ETOILES: {
		tempo = 150.0, tonique = 55, gamme = [0, 2, 3, 5, 7, 8, 10],
		grille = [0, 5, 6, 4], basse = [1, 0, 1, 1, 0, 1, 0, 1], arpege = 24, graine = 63,
	},
}

static var _cache: Dictionary = {}
## Le cache se remplit depuis les fils qui composent, et se lit depuis le fil
## principal : un Dictionary écrit par deux fils à la fois se corrompt, et le
## jeu s'arrête net. Tout accès passe par ce verrou.
static var _verrou := Mutex.new()


## La boucle d'un style, si elle est déjà composée ; null sinon.
static func deja_composee(style: int) -> AudioStreamWAV:
	_verrou.lock()
	var flux: AudioStreamWAV = _cache.get(style)
	_verrou.unlock()
	return flux


## Compose la boucle et la garde. Peut tourner dans un autre fil.
static func composer(style: int) -> AudioStreamWAV:
	var deja := deja_composee(style)
	if deja != null:
		return deja
	var s: Dictionary = STYLES[style]
	var noire := 60.0 / float(s.tempo)
	var croche := noire * 0.5
	var double := noire * 0.25
	var total := int(noire * 4.0 * MESURES * FREQUENCE)
	var piste := PackedFloat32Array()
	piste.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = s.graine
	var gamme: Array = s.gamme
	var grille: Array = s.grille

	for mesure in MESURES:
		var debut_mesure := mesure * 4.0 * noire
		var degre: int = grille[mesure % grille.size()]
		var accord := [_note(s, degre), _note(s, degre + 2), _note(s, degre + 4)]
		# Basse : la fondamentale, une octave en dessous, sur le rythme du style.
		var rythme: Array = s.basse
		for c in 8:
			if rythme[c] == 1:
				var hauteur: int = accord[0] - 24 + (12 if c % 4 == 3 else 0)
				_poser(piste, debut_mesure + c * croche, croche * 0.9, hauteur, 0.30, _triangle)
		# Arpège : les notes de l'accord en doubles croches, courtes et discrètes.
		for d in 16:
			var hauteur: int = accord[d % 3] + int(s.arpege)
			_poser(piste, debut_mesure + d * double, double * 0.6, hauteur, 0.08, _carre)
		# Mélodie : des notes de l'accord sur les temps forts, des notes de la
		# gamme entre deux ; la seconde moitié reprend la première, un peu
		# changée à la fin — assez de répétition pour qu'on la retienne.
		var t := 0.0
		var graine_mesure: int = s.graine * 100 + (mesure % 4) * 7 + (1 if mesure >= 6 else 0)
		rng.seed = graine_mesure
		while t < 4.0 * noire - 0.001:
			var duree := noire if rng.randf() < 0.45 else croche
			if rng.randf() < 0.12:
				t += duree
				continue
			var fort := fmod(t, noire) < 0.001
			var hauteur: int
			if fort:
				hauteur = accord[rng.randi_range(0, 2)] + 12
			else:
				hauteur = _note(s, degre + rng.randi_range(0, gamme.size() - 1)) + 12
			_poser(piste, debut_mesure + t, duree * 0.85, hauteur, 0.16, _carre_doux)
			t += duree
		# Batterie : grosse caisse sur 1 et 3, caisse claire sur 2 et 4,
		# charleston à chaque croche.
		var batterie: float = s.get("batterie", 1.0)
		for c in 8:
			var quand := debut_mesure + c * croche
			if c % 4 == 0:
				_frapper(piste, quand, 0.12, 0.45 * batterie, true)
			elif c % 4 == 2:
				_frapper(piste, quand, 0.1, 0.22 * batterie, false)
			if s.get("charleston", true):
				_bruit(piste, quand, 0.03, 0.05)

	var flux := _en_wav(piste)
	_verrou.lock()
	# Composée entre-temps par un autre fil : on garde la première.
	if _cache.has(style):
		flux = _cache[style]
	else:
		_cache[style] = flux
	_verrou.unlock()
	return flux


## Le degré `degre` de la gamme du style, en note MIDI (les degrés au-delà de
## la gamme montent d'une octave).
static func _note(s: Dictionary, degre: int) -> int:
	var gamme: Array = s.gamme
	var octave := floori(float(degre) / gamme.size())
	return int(s.tonique) + gamme[posmod(degre, gamme.size())] + 12 * octave


static func frequence(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


static func _carre(phase: float) -> float:
	return 1.0 if phase < 0.5 else -1.0


static func _carre_doux(phase: float) -> float:
	return 0.55 * (1.0 if phase < 0.25 else -1.0) + 0.45 * sin(phase * TAU)


static func _triangle(phase: float) -> float:
	return 4.0 * absf(phase - 0.5) - 1.0


## Ajoute une note à la piste : attaque courte, chute douce.
static func _poser(piste: PackedFloat32Array, debut: float, duree: float, midi: int,
		volume: float, onde: Callable) -> void:
	var f := frequence(midi) / FREQUENCE
	var i0 := int(debut * FREQUENCE)
	var n := int(duree * FREQUENCE)
	var phase := 0.0
	for i in n:
		var k := i0 + i
		if k >= piste.size():
			return
		var t := float(i) / FREQUENCE
		var enveloppe := minf(t / 0.004, 1.0) * clampf(1.0 - t / duree, 0.0, 1.0)
		phase = fmod(phase + f, 1.0)
		piste[k] += onde.call(phase) * enveloppe * volume


## Grosse caisse (sinus qui plonge) ou caisse claire (bruit).
static func _frapper(piste: PackedFloat32Array, debut: float, duree: float, volume: float,
		grosse: bool) -> void:
	if not grosse:
		_bruit(piste, debut, duree, volume)
		return
	var i0 := int(debut * FREQUENCE)
	var n := int(duree * FREQUENCE)
	var phase := 0.0
	for i in n:
		var k := i0 + i
		if k >= piste.size():
			return
		var t := float(i) / FREQUENCE
		phase += lerpf(140.0, 45.0, t / duree) / FREQUENCE
		piste[k] += sin(phase * TAU) * (1.0 - t / duree) * volume


static func _bruit(piste: PackedFloat32Array, debut: float, duree: float, volume: float) -> void:
	var i0 := int(debut * FREQUENCE)
	var n := int(duree * FREQUENCE)
	for i in n:
		var k := i0 + i
		if k >= piste.size():
			return
		piste[k] += randf_range(-1.0, 1.0) * (1.0 - float(i) / n) * volume


static func _en_wav(piste: PackedFloat32Array) -> AudioStreamWAV:
	var donnees := PackedByteArray()
	donnees.resize(piste.size() * 2)
	for i in piste.size():
		# Une légère saturation plutôt qu'un écrêtage sec, là où les voix
		# s'additionnent.
		var v := tanh(piste[i])
		donnees.encode_s16(i * 2, int(v * 30000.0))
	var flux := AudioStreamWAV.new()
	flux.format = AudioStreamWAV.FORMAT_16_BITS
	flux.mix_rate = FREQUENCE
	flux.stereo = false
	flux.data = donnees
	# Pas de boucle dans le flux : sur un FP5 (Android 15), le jeu se fermait
	# net au menu pile quand l'air de 18 s revenait au début. Les lecteurs
	# (MusiqueMenu, RaceMusic) relancent eux-mêmes l'air quand il finit.
	flux.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return flux
