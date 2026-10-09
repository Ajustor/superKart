class_name EffetsEcran
extends ColorRect

## Les effets posés sur toute l'image pendant la course (voir
## shaders/effets_ecran.gdshader) : la vignette, toujours, et les traits de
## vitesse, le temps d'un turbo du kart suivi par la caméra.

const SHADER := preload("res://shaders/effets_ecran.gdshader")
const SHADER_VORTEX := preload("res://shaders/vortex_ecran.gdshader")

var session: RaceSession
var _turbo: float = 0.0
var _materiau: ShaderMaterial
## La déformation d'un portail (TrackPortail), allumée le temps de le
## traverser.
var _vortex: ColorRect
var _materiau_vortex: ShaderMaterial
## L'éclair (ItemManager.kart_foudroye) : un éclat blanc sur toute l'image,
## qui s'efface en un instant.
const DUREE_FLASH := 0.4
var _flash: ColorRect
var _force_flash: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_materiau = ShaderMaterial.new()
	_materiau.shader = SHADER
	material = _materiau
	_vortex = ColorRect.new()
	_vortex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vortex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vortex.show_behind_parent = true
	_materiau_vortex = ShaderMaterial.new()
	_materiau_vortex.shader = SHADER_VORTEX
	_vortex.material = _materiau_vortex
	_vortex.visible = false
	add_child(_vortex)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.92, 0.95, 1.0, 0.0)
	_flash.visible = false
	add_child(_flash)
	resized.connect(_rapport)
	_rapport()


func _rapport() -> void:
	if size.y > 0.0:
		_materiau.set_shader_parameter("rapport", size.x / size.y)
		_materiau_vortex.set_shader_parameter("rapport", size.x / size.y)


## Un éclair vient de tomber.
func eclair() -> void:
	_force_flash = 1.0


func _process(delta: float) -> void:
	_force_flash = move_toward(_force_flash, 0.0, delta / DUREE_FLASH)
	_flash.visible = _force_flash > 0.0
	_flash.color.a = 0.6 * _force_flash * _force_flash
	var cible := 0.0
	if session != null and not session.entries.is_empty():
		var moteur := session.entries[0].kart.motor
		if moteur != null and moteur.boost_timer > 0.0:
			cible = 1.0
	# Les traits apparaissent d'un coup et s'effacent en douceur.
	_turbo = cible if cible > _turbo else lerpf(_turbo, cible, 1.0 - exp(-4.0 * delta))
	_materiau.set_shader_parameter("turbo", _turbo)
	var camera := get_viewport().get_camera_3d() as ChaseCamera
	var force := camera.vortex if camera != null else 0.0
	_vortex.visible = force > 0.02
	if _vortex.visible:
		_materiau_vortex.set_shader_parameter("force", force)
