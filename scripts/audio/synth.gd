class_name Synth
extends RefCounted

## Fabrique de petits sons, calculés plutôt qu'enregistrés : le dépôt ne porte
## aucun fichier audio, et un bip de décompte n'a pas besoin d'un studio.

const FREQUENCE := 22050


## Une suite de notes jouées l'une après l'autre. Chaque note est un couple
## [fréquence en Hz, durée en secondes] ; une fréquence nulle fait un silence.
## Onde carrée adoucie, attaque et chute courtes pour ne pas claquer.
static func notes(suite: Array, volume: float = 0.5) -> AudioStreamWAV:
	var donnees := PackedByteArray()
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
			var entier := clampi(int(echantillon * volume * 32767.0), -32768, 32767)
			donnees.append(entier & 0xFF)
			donnees.append((entier >> 8) & 0xFF)
	var flux := AudioStreamWAV.new()
	flux.format = AudioStreamWAV.FORMAT_16_BITS
	flux.mix_rate = FREQUENCE
	flux.stereo = false
	flux.data = donnees
	return flux
