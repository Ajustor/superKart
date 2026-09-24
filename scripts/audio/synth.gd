class_name Synth
extends RefCounted

## Fabrique de petits sons, calculés plutôt qu'enregistrés : le dépôt ne porte
## aucun fichier audio, et un bip de décompte n'a pas besoin d'un studio.

const FREQUENCE := 22050


## Une suite de notes jouées l'une après l'autre. Chaque note est un couple
## [fréquence en Hz, durée en secondes] ; une fréquence nulle fait un silence.
## Onde carrée adoucie, attaque et chute courtes pour ne pas claquer.
static func notes(suite: Array, volume: float = 0.5) -> AudioStreamWAV:
	var echantillons := PackedFloat32Array()
	for note in suite:
		var freq: float = note[0]
		var duree: float = note[1]
		var n := int(duree * FREQUENCE)
		var phase := 0.0
		for i in n:
			var t := float(i) / float(FREQUENCE)
			var enveloppe := minf(t / 0.005, 1.0) * minf((duree - t) / 0.03, 1.0)
			var echantillon := 0.0
			if freq > 0.0:
				phase = fmod(phase + freq / FREQUENCE, 1.0)
				# Carré + un peu de sinus : le carré porte, le sinus arrondit.
				echantillon = (0.6 * signf(0.5 - phase) + 0.4 * sin(phase * TAU)) * enveloppe
			echantillons.append(echantillon * volume)
	return en_wav(echantillons)


## Un choc : un coup sourd — un sinus qui descend de `grave` Hz à la moitié —
## mêlé à un bruit filtré, les deux vite éteints. `clair`, de 0 à 1 : la part
## du bruit et son éclat. Sourd pour une retombée, clair pour de la tôle.
## Le bruit vient d'une graine fixe : le même choc sonne pareil à chaque fois.
static func choc(duree: float, grave: float, clair: float, volume: float = 0.5) -> AudioStreamWAV:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	var n := int(duree * FREQUENCE)
	var echantillons := PackedFloat32Array()
	echantillons.resize(n)
	var phase := 0.0
	var filtre := 0.0
	var coef := lerpf(0.04, 0.7, clair)
	for i in n:
		var t := float(i) / float(FREQUENCE)
		var enveloppe := minf(t / 0.002, 1.0) * exp(-6.0 * t / duree)
		phase = fmod(phase + grave * lerpf(1.0, 0.5, t / duree) / FREQUENCE, 1.0)
		filtre += (hasard.randf_range(-1.0, 1.0) - filtre) * coef
		# Un bruit filtré bas est bien plus faible qu'un bruit franc : on le
		# remonte d'autant, sans quoi un choc sourd ne serait qu'un sinus.
		var bruit := filtre * lerpf(3.0, 1.0, clair)
		var e := lerpf(1.0, 0.35, clair) * sin(phase * TAU) + lerpf(0.4, 0.9, clair) * bruit
		echantillons[i] = clampf(e * enveloppe * volume, -1.0, 1.0)
	return en_wav(echantillons)


## Des échantillons de -1 à 1 en un son 16 bits mono.
static func en_wav(echantillons: PackedFloat32Array) -> AudioStreamWAV:
	var donnees := PackedByteArray()
	donnees.resize(echantillons.size() * 2)
	for i in echantillons.size():
		var entier := clampi(int(echantillons[i] * 32767.0), -32768, 32767)
		donnees[i * 2] = entier & 0xFF
		donnees[i * 2 + 1] = (entier >> 8) & 0xFF
	var flux := AudioStreamWAV.new()
	flux.format = AudioStreamWAV.FORMAT_16_BITS
	flux.mix_rate = FREQUENCE
	flux.stereo = false
	flux.data = donnees
	return flux
