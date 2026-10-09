class_name NuageMagique
extends Node3D

## Le nuage magique (ModeleKart.NUAGE), posé en `Body/Nuage` à la place du
## kart Kenney : une douzaine de boules dorées fusionnées en un seul maillage,
## plus claires sur le dessus, et une traîne de trois bouffées qui
## rapetissent vers l'arrière. Il flotte à quelques centimètres du sol en se
## berçant, et sème de petites bouffées dorées quand il roule.
##
## Purement cosmétique : la physique, les chocs et la suspension restent ceux
## du kart.

## Les boules du nuage, dans le repère de la caisse (l'avant vers -z) : centre
## et rayon. Aplaties (APLATI) : le dessous reste au-dessus du sol.
const BOULES := [
	[Vector3(0.0, 0.34, 0.0), 0.48],
	[Vector3(-0.36, 0.3, -0.24), 0.36],
	[Vector3(0.36, 0.3, -0.24), 0.36],
	[Vector3(-0.38, 0.3, 0.26), 0.34],
	[Vector3(0.38, 0.3, 0.26), 0.34],
	[Vector3(0.0, 0.32, -0.52), 0.36],
	[Vector3(0.0, 0.3, 0.5), 0.34],
	[Vector3(0.0, 0.46, 0.04), 0.32],
	[Vector3(-0.22, 0.42, -0.3), 0.24],
	[Vector3(0.22, 0.42, 0.28), 0.24],
	# La traîne : trois bouffées, de plus en plus petites vers l'arrière.
	[Vector3(0.0, 0.33, 0.86), 0.24],
	[Vector3(0.07, 0.36, 1.1), 0.16],
	[Vector3(-0.04, 0.39, 1.27), 0.1],
]
const APLATI := 0.6
## Le doré : plus clair sur le dessus, plus chaud dessous.
const DORE_DESSOUS := Color(0.93, 0.62, 0.12)
const DORE_DESSUS := Color(1.0, 0.92, 0.55)
## Le bercement : quelques centimètres, sur un peu plus d'une seconde.
const BERCEMENT := 0.035
const PERIODE := 1.7
## La traînée de bouffées, au-delà de cette vitesse (m/s).
const VITESSE_TRAINEE := 3.0

static var _maillage: ArrayMesh
static var _matiere: StandardMaterial3D

var _forme: MeshInstance3D
var _trainee: CPUParticles3D
var _kart: Kart
var _temps := 0.0


func _init() -> void:
	_forme = MeshInstance3D.new()
	_forme.name = "Forme"
	_forme.mesh = maillage()
	add_child(_forme)
	_trainee = _creer_trainee()
	add_child(_trainee)


func _ready() -> void:
	# Body/Nuage : le kart est deux crans au-dessus. La vitrine du garage n'en
	# a pas ; le nuage s'y berce sans semer de bouffées.
	var parent := get_parent()
	_kart = parent.get_parent() as Kart if parent != null else null
	# Chaque nuage à son rythme : huit nuages qui se bercent ensemble, ça se
	# voit.
	_temps = randf() * PERIODE


func _process(delta: float) -> void:
	if not visible:
		_trainee.emitting = false
		return
	_temps += delta
	var bercement := sin(_temps * TAU / PERIODE) * BERCEMENT
	_forme.position.y = bercement
	# Le pilote se berce avec lui : il a les pieds dedans.
	var pilote := get_parent().get_node_or_null("Pilote") as Node3D
	if pilote != null:
		pilote.position.y = ModeleKart.PIEDS_SUR_LE_NUAGE + bercement
	_trainee.emitting = _kart != null and _kart.motor != null \
		and absf(_kart.motor.speed) > VITESSE_TRAINEE


## Le maillage du nuage : construit une fois, partagé par tous les nuages. Un
## seul maillage, un seul matériau : un seul appel de dessin.
static func maillage() -> ArrayMesh:
	if _maillage != null:
		return _maillage
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var indices := PackedInt32Array()
	var boule := SphereMesh.new()
	boule.radius = 1.0
	boule.height = 2.0
	boule.radial_segments = 14
	boule.rings = 7
	var gabarit := boule.get_mesh_arrays()
	var points: PackedVector3Array = gabarit[Mesh.ARRAY_VERTEX]
	var ses_normales: PackedVector3Array = gabarit[Mesh.ARRAY_NORMAL]
	var ses_indices: PackedInt32Array = gabarit[Mesh.ARRAY_INDEX]
	var haut := -INF
	var bas := INF
	for b in BOULES:
		var centre: Vector3 = b[0]
		var r: float = b[1]
		haut = maxf(haut, centre.y + r * APLATI)
		bas = minf(bas, centre.y - r * APLATI)
	for b in BOULES:
		var centre: Vector3 = b[0]
		var r: float = b[1]
		var depart := sommets.size()
		var echelle := Vector3(r, r * APLATI, r)
		for i in points.size():
			var p := centre + points[i] * echelle
			sommets.append(p)
			# La normale d'un ellipsoïde : celle de la sphère, divisée par
			# l'échelle.
			normales.append((ses_normales[i] / echelle).normalized())
			couleurs.append(DORE_DESSOUS.lerp(DORE_DESSUS, clampf((p.y - bas) / (haut - bas), 0.0, 1.0)))
		for i in ses_indices:
			indices.append(depart + i)
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_COLOR] = couleurs
	tableaux[Mesh.ARRAY_INDEX] = indices
	_maillage = ArrayMesh.new()
	_maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	_maillage.surface_set_material(0, matiere())
	return _maillage


## La matière du nuage et de ses bouffées : la couleur des sommets, un peu
## brillante.
static func matiere() -> StandardMaterial3D:
	if _matiere == null:
		_matiere = StandardMaterial3D.new()
		_matiere.vertex_color_use_as_albedo = true
		_matiere.roughness = 0.85
		_matiere.emission_enabled = true
		_matiere.emission = Color(0.35, 0.22, 0.02)
	return _matiere


## De petites bouffées dorées laissées derrière, qui fondent jusqu'à rien :
## calculées par le processeur, comme toutes les particules du jeu.
func _creer_trainee() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Trainee"
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.7
	p.position = Vector3(0.0, 0.32, 1.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0.0, 0.3, 1.0)
	p.spread = 25.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0.0, 0.3, 0.0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	var courbe := Curve.new()
	courbe.add_point(Vector2(0.0, 1.0))
	courbe.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = courbe
	p.color = DORE_DESSOUS.lerp(DORE_DESSUS, 0.5)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bouffee := SphereMesh.new()
	bouffee.radius = 0.14
	bouffee.height = 0.2
	bouffee.radial_segments = 8
	bouffee.rings = 4
	bouffee.material = matiere()
	p.mesh = bouffee
	return p
