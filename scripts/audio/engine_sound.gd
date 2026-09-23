class_name EngineSound
extends AudioStreamPlayer

## Le bruit du moteur du joueur, synthétisé à la volée. Seul le joueur en a
## un : huit moteurs non spatialisés feraient un bourdonnement où l'on
## n'entendrait plus le sien.
##
## La hauteur suit la vitesse, monte encore sous turbo, et le ralenti ne
## s'éteint jamais tout à fait : un kart à l'arrêt tourne toujours.

@export var kart_path: NodePath
@export var frequence_ralenti: float = 48.0
@export var frequence_max: float = 150.0
@export var volume_ralenti: float = 0.18
@export var volume_max: float = 0.32

var _kart: Kart
var _lecture: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _phase_basse: float = 0.0
var _frequence: float = 0.0
var _volume: float = 0.0


func _ready() -> void:
	_kart = get_node_or_null(kart_path) as Kart
	var flux := AudioStreamGenerator.new()
	flux.mix_rate = Synth.FREQUENCE
	flux.buffer_length = 0.1
	stream = flux
	bus = &"Effets"
	_frequence = frequence_ralenti
	play()
	_lecture = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	if _lecture == null or _kart == null or _kart.motor == null:
		return
	var moteur := _kart.motor
	var ratio := clampf(moteur.speed / maxf(_kart.stats.max_speed, 0.001), 0.0, 1.5)
	var cible := lerpf(frequence_ralenti, frequence_max, ratio)
	var cible_volume := lerpf(volume_ralenti, volume_max, minf(ratio, 1.0))
	if not _kart.controle_actif:
		cible_volume = volume_ralenti
	# Lissé : un régime ne saute pas d'une image à l'autre.
	var lissage := 1.0 - exp(-8.0 * delta)
	_frequence = lerpf(_frequence, cible, lissage)
	_volume = lerpf(_volume, cible_volume, lissage)
	_remplir()


func _remplir() -> void:
	var libres := _lecture.get_frames_available()
	for i in libres:
		_phase = fmod(_phase + _frequence / Synth.FREQUENCE, 1.0)
		_phase_basse = fmod(_phase_basse + _frequence * 0.5 / Synth.FREQUENCE, 1.0)
		# Dent de scie + sous-harmonique : le ronflement d'un deux-temps.
		var scie := 2.0 * _phase - 1.0
		var basse := sin(_phase_basse * TAU)
		var v := (0.55 * scie + 0.45 * basse) * _volume
		_lecture.push_frame(Vector2(v, v))
