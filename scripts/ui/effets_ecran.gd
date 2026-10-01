class_name EffetsEcran
extends ColorRect

## Les effets posés sur toute l'image pendant la course (voir
## shaders/effets_ecran.gdshader) : la vignette, toujours, et les traits de
## vitesse, le temps d'un turbo du kart suivi par la caméra.

const SHADER := preload("res://shaders/effets_ecran.gdshader")

var session: RaceSession
var _turbo: float = 0.0
var _materiau: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_materiau = ShaderMaterial.new()
	_materiau.shader = SHADER
	material = _materiau
	resized.connect(_rapport)
	_rapport()


func _rapport() -> void:
	if size.y > 0.0:
		_materiau.set_shader_parameter("rapport", size.x / size.y)


func _process(delta: float) -> void:
	var cible := 0.0
	if session != null and not session.entries.is_empty():
		var moteur := session.entries[0].kart.motor
		if moteur != null and moteur.boost_timer > 0.0:
			cible = 1.0
	# Les traits apparaissent d'un coup et s'effacent en douceur.
	_turbo = cible if cible > _turbo else lerpf(_turbo, cible, 1.0 - exp(-4.0 * delta))
	_materiau.set_shader_parameter("turbo", _turbo)
