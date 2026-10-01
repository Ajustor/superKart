@tool
class_name TrackApesanteur
extends TrackFeature

## Une zone où la gravité faiblit : sur la Lune, dans une bulle d'antigravité.
## Au sol, rien ne change ; mais chaque saut y dure deux ou trois fois plus
## longtemps. Une rampe y lance le kart par-dessus un cratère qu'on ne
## franchirait pas ailleurs, et une figure a tout le temps de se faire.
##
## Une arche violette marque l'entrée et la sortie, et la route y scintille.

## Multiplie la gravité du kart. 0,35 : un saut de 0,7 s en dure deux.
@export_range(0.1, 1.0, 0.05) var gravite: float = 0.35

@export var couleur: Color = Color(0.6, 0.35, 1.0):
	set(valeur):
		couleur = valeur
		_modifie()


func _init() -> void:
	longueur = 80.0
	# Toute la largeur, et un peu au-delà : un kart en l'air peut s'écarter.
	largeur = 40.0


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var demi := c.half_width
	var voile := StandardMaterial3D.new()
	voile.albedo_color = Color(couleur, 0.22)
	voile.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	voile.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	TrackFeature._poser(racine, _nappe(c, -demi, demi, 0.03, true), voile, false)
	for enfant in racine.get_children():
		if enfant is GeometryInstance3D:
			(enfant as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Les deux arches, lumineuses et sans collision : on passe dessous.
	var lueur := StandardMaterial3D.new()
	lueur.albedo_color = couleur.lightened(0.3)
	lueur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for d in [debut, debut + longueur]:
		var arche := MeshInstance3D.new()
		var tore := TorusMesh.new()
		tore.inner_radius = demi + 1.2
		tore.outer_radius = demi + 1.9
		tore.rings = 48
		tore.ring_segments = 8
		arche.mesh = tore
		arche.material_override = lueur
		var repere := c.basis_at(d)
		# Le tore est couché dans le plan XZ : on le dresse en travers de la
		# route, son centre sur l'axe.
		arche.transform = Transform3D(Basis(repere.x, -repere.z, repere.y),
			c.position_at(d))
		racine.add_child(arche)
