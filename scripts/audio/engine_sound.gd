class_name EngineSound
extends AudioStreamPlayer

## Le bruit du moteur du joueur, synthétisé à la volée. Seul le joueur en a
## un : huit moteurs non spatialisés feraient un bourdonnement où l'on
## n'entendrait plus le sien.
##
## La hauteur suit la vitesse, monte encore sous turbo, et le ralenti ne
## s'éteint jamais tout à fait : un kart à l'arrêt tourne toujours.
##
## Par-dessus le moteur, dans le même flux (un seul calcul par échantillon) :
## le crissement des pneus en glisse, le grondement de l'herbe sous les
## roues, le souffle du turbo. Chaque couche monte et descend en douceur.

@export var kart_path: NodePath
@export var frequence_ralenti: float = 48.0
@export var frequence_max: float = 150.0
@export var volume_ralenti: float = 0.18
@export var volume_max: float = 0.32

var _kart: Kart
var _lecture: AudioStreamGeneratorPlayback

## Fréquence d'échantillonnage du moteur : la moitié de celle des autres sons.
## Un ronflement et un crissement à 1 150 Hz n'ont pas besoin de plus, et ce
## son se calcule échantillon par échantillon en GDScript — sur téléphone,
## le diviser par deux soulage chaque image.
const FREQUENCE := 11025
var _phase: float = 0.0
var _phase_basse: float = 0.0
var _frequence: float = 0.0
var _volume: float = 0.0
var _rapeux: float = 0.0
## Volume de chaque couche, lissé, et sa cible (voir couches()).
var _niveaux := Vector3.ZERO
var _crisse: float = 0.0
var _vibrato: float = 0.0
var _bosses: float = 0.0
var _frequence_bosses: float = 8.0
var _bas: float = 0.0
var _moyen: float = 0.0
var _haut: float = 0.0
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	_kart = get_node_or_null(kart_path) as Kart
	var flux := AudioStreamGenerator.new()
	flux.mix_rate = FREQUENCE
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
	_rapeux = lerpf(_rapeux, 0.12 if _kart.gaz_tenu and _kart.controle_actif else 0.03, lissage)
	var cibles := couches(moteur, _kart.au_sol, _kart.stats.max_speed)
	_niveaux = _niveaux.lerp(cibles, 1.0 - exp(-14.0 * delta))
	_frequence_bosses = 5.0 + 12.0 * minf(ratio, 1.0)
	_remplir()


## Le volume visé de chaque couche : x le crissement, y l'herbe, z le souffle
## du turbo. Tout se tait en l'air : on n'entend pas des roues qui ne
## touchent rien.
static func couches(moteur: KartMotor, au_sol: bool, vitesse_max: float) -> Vector3:
	var ratio := clampf(moteur.speed / maxf(vitesse_max, 0.001), 0.0, 1.0)
	var niveaux := Vector3.ZERO
	if au_sol:
		if moteur.state == KartMotor.State.DRIFT:
			niveaux.x = 0.1 + 0.08 * ratio
		elif moteur.state == KartMotor.State.STUNNED and moteur.speed > 3.0:
			niveaux.x = 0.12
		if moteur.on_offroad:
			niveaux.y = 0.3 * ratio
	if moteur.boost_timer > 0.0:
		niveaux.z = 0.14 + 0.08 * ratio
	return niveaux


func _remplir() -> void:
	var libres := _lecture.get_frames_available()
	var pas := 1.0 / FREQUENCE
	for i in libres:
		_phase = fmod(_phase + _frequence * pas, 1.0)
		_phase_basse = fmod(_phase_basse + _frequence * 0.5 * pas, 1.0)
		var bruit := _hasard.randf_range(-1.0, 1.0)
		# Trois filtres d'un pôle sur le même bruit : un grave pour l'herbe, un
		# médium pour le souffle, un aigu (ce que le médium laisse) pour les
		# pneus.
		_bas += (bruit - _bas) * 0.06
		_moyen += (bruit - _moyen) * 0.44
		_haut = bruit - _moyen
		# Dent de scie + sous-harmonique : le ronflement d'un deux-temps. Un
		# peu de bruit par-dessus quand on a le pied au plancher.
		var scie := 2.0 * _phase - 1.0
		var basse := sin(_phase_basse * TAU)
		var v := (0.55 * scie + 0.45 * basse + _rapeux * bruit) * _volume
		if _niveaux.x > 0.001:
			# Le crissement : une note aiguë qui chevrote, et du souffle.
			_vibrato = fmod(_vibrato + 11.0 * pas, 1.0)
			_crisse = fmod(_crisse + (1150.0 + 60.0 * sin(_vibrato * TAU)) * pas, 1.0)
			v += _niveaux.x * (0.55 * sin(_crisse * TAU) + 0.45 * _haut)
		if _niveaux.y > 0.001:
			# L'herbe : un grondement sourd, secoué au rythme des mottes.
			_bosses = fmod(_bosses + _frequence_bosses * pas, 1.0)
			v += _niveaux.y * _bas * 5.0 * (0.5 + 0.5 * absf(sin(_bosses * TAU)))
		if _niveaux.z > 0.001:
			v += _niveaux.z * (_moyen - _bas) * 1.6
		v = clampf(v, -1.0, 1.0)
		_lecture.push_frame(Vector2(v, v))
