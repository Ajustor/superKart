@tool
class_name TrackCourant
extends TrackFeature

## Une zone qui pousse les karts : une rafale de vent dans un canyon, le
## courant d'une rivière, un tapis roulant d'usine. La poussée s'ajoute au
## mouvement du kart sans toucher à son moteur — en travers, elle le fait
## dériver et il faut contre-braquer ; dans le sens de la course, elle
## l'emporte plus vite ; à contre-sens, elle le freine.
##
## Le vent souffle aussi sur un kart en l'air : un saut dans une rafale finit
## à côté de là où il visait.
##
## `periode` non nulle : des rafales. La poussée monte et retombe sur ce
## rythme, réglé sur l'horloge du circuit — elle bat au même moment pour
## tous les joueurs d'une partie en réseau.

enum Style {
	## Des traînées blanches qui filent en travers.
	VENT,
	## De l'eau qui coule, bleue.
	EAU,
	## Un tapis roulant, rayé de jaune et de noir.
	TAPIS,
}

@export var style: Style = Style.VENT:
	set(valeur):
		style = valeur
		_modifie()

## Poussée en travers, en m/s : positive vers la droite de la course.
@export_range(-20.0, 20.0, 0.5) var poussee_laterale: float = 5.0:
	set(valeur):
		poussee_laterale = valeur
		_modifie()

## Poussée le long du tracé, en m/s : positive dans le sens de la course.
@export_range(-20.0, 20.0, 0.5) var poussee_avant: float = 0.0:
	set(valeur):
		poussee_avant = valeur
		_modifie()

## Durée d'un cycle de rafale, en secondes. Zéro : une poussée constante.
@export_range(0.0, 20.0, 0.5) var periode: float = 0.0

## Décale le cycle de cette fraction : deux zones voisines qui soufflent
## l'une après l'autre.
@export_range(0.0, 1.0, 0.05) var phase: float = 0.0

const DEFILEMENT := 1.0

var _materiau_zone: StandardMaterial3D


func _init() -> void:
	longueur = 40.0
	largeur = 18.0


## De 0 à 1 : la force de la rafale à cet instant. Toujours 1 sans rafales.
## Le vent souffle un peu plus de la moitié du temps, monte vite et retombe.
func intensite(horloge: float) -> float:
	if periode <= 0.0:
		return 1.0
	var t := fposmod(horloge / periode + phase, 1.0)
	return clampf(sin(t * TAU) * 1.4 + 0.2, 0.0, 1.0)


## La poussée en ce point du tracé, dans le repère du monde, à plat.
func poussee(c: TrackCurve, distance: float, horloge: float) -> Vector3:
	var avant := c.tangent_at(distance)
	var droite := Vector3(-avant.z, 0.0, avant.x)
	return (droite * poussee_laterale + avant * poussee_avant) * intensite(horloge)


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var g := decalage - largeur * 0.5
	var r := decalage + largeur * 0.5
	_materiau_zone = _materiau()
	var hauteur := 0.03 if style != Style.VENT else 0.4
	TrackFeature._poser(racine, _nappe(c, g, r, hauteur, true), _materiau_zone, false)
	for enfant in racine.get_children():
		if enfant is GeometryInstance3D:
			(enfant as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if style == Style.TAPIS:
		# Deux rebords métalliques : un tapis se voit comme une machine.
		var acier := StandardMaterial3D.new()
		acier.albedo_color = Color(0.45, 0.47, 0.5)
		acier.metallic = 0.7
		acier.roughness = 0.4
		for bord in [g, r]:
			TrackFeature._poser(racine, TrackFeature.nappe(c, debut, longueur, bord - 0.3, bord + 0.3, 0.08), acier, false)


func _process(delta: float) -> void:
	if _materiau_zone == null or Engine.is_editor_hint():
		return
	var p := piste()
	var force := intensite(p.horloge if p != null else 0.0)
	# Le motif file dans le sens de la poussée : en u le long du tracé, en v
	# en travers.
	var decale := _materiau_zone.uv1_offset
	decale.x = fposmod(decale.x - poussee_avant * DEFILEMENT * delta * _materiau_zone.uv1_scale.x * force, 1.0)
	decale.y = fposmod(decale.y - poussee_laterale * DEFILEMENT * delta * _materiau_zone.uv1_scale.y * force, 1.0)
	_materiau_zone.uv1_offset = decale
	if style == Style.VENT:
		_materiau_zone.albedo_color.a = 0.15 + 0.6 * force


func _materiau() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	match style:
		Style.VENT:
			# Des traînées claires, éparses, dans le sens du vent.
			image.fill(Color(1, 1, 1, 0))
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			var en_travers := absf(poussee_laterale) >= absf(poussee_avant)
			for i in 9:
				var a := rng.randi_range(0, 31)
				var b := rng.randi_range(0, 31)
				for k in 10:
					var x := a if en_travers else posmod(a + k, 32)
					var y := posmod(b + k, 32) if en_travers else b
					image.set_pixel(x, y, Color(1, 1, 1, 0.8))
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.uv1_scale = Vector3(1.0 / 8.0, 1.0 / 8.0, 1.0)
		Style.EAU:
			for y in 32:
				for x in 32:
					var v := 0.5 + 0.5 * sin(float(x + y * 2) * 0.4)
					image.set_pixel(x, y, Color(0.15, 0.45 + 0.15 * v, 0.8 + 0.15 * v, 0.85))
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.1
			m.emission_enabled = true
			m.emission = Color(0.05, 0.15, 0.3)
			m.uv1_scale = Vector3(1.0 / 6.0, 1.0 / 6.0, 1.0)
		Style.TAPIS:
			for y in 32:
				for x in 32:
					# Des barres en travers : elles défilent dans le sens du tapis.
					var barre := (x / 8) % 2 == 0
					image.set_pixel(x, y, Color(0.95, 0.75, 0.1) if barre else Color(0.12, 0.12, 0.13))
			m.roughness = 0.6
			m.uv1_scale = Vector3(1.0 / 2.0, 1.0 / largeur, 1.0)
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m
