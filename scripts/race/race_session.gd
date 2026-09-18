class_name RaceSession
extends Node

## Met le kart et le circuit en rapport. Le kart ignore le circuit, le circuit
## ignore le kart : c'est ici et nulle part ailleurs que les deux se parlent.

const FLOOR_LIMIT := -10.0
const OFF_TRACK_RESPAWN_MARGIN := 3.0

@export var track_path: NodePath
@export var kart_path: NodePath
@export var lap_count: int = 3

var progress: RaceProgress
var timer := RaceTimer.new()
var finished: bool = false

var _track: Track
var _kart: Kart


func _ready() -> void:
	_track = get_node(track_path) as Track
	_kart = get_node(kart_path) as Kart
	assert(_track != null, "track_path doit pointer vers un Track")
	assert(_kart != null, "kart_path doit pointer vers un Kart")

	progress = RaceProgress.new(_track.track_curve)
	_kart.respawn_at(_track.spawn_at(0.0))
	progress.update(_kart.global_position)


func _physics_process(delta: float) -> void:
	if finished:
		return

	var tours_avant := progress.lap
	progress.update(_kart.global_position)
	timer.advance(delta)

	if progress.lap > tours_avant:
		timer.complete_lap()
		if progress.lap >= lap_count:
			finished = true
			return

	# Une seule projection par image : is_off_track la referait entièrement,
	# et la remise en piste une troisième fois.
	var ecart := absf(_track.track_curve.lateral_offset(_kart.global_position))
	_kart.set_offroad(ecart > _track.half_width)

	if _kart.global_position.y < FLOOR_LIMIT or ecart > _track.half_width + OFF_TRACK_RESPAWN_MARGIN:
		_kart.respawn_at(_track.spawn_at(progress.distance))
