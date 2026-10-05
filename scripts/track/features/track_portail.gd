@tool
class_name TrackPortail
extends TrackFeature

## Un portail : un anneau d'étincelles d'or en travers de la route, qui
## s'ouvre quand le premier approche et se referme une fois le dernier passé.
## Il naît tout petit, l'autre monde déjà dedans, et grandit jusqu'à sa
## taille ; l'anneau crache une pluie d'étincelles
## (portail_etincelles.gdshader). On le traverse sans rien sentir sous les
## roues — ce n'est pas un obstacle —, mais pas sans rien voir : la caméra
## change de perspective pendant `longueur` mètres (ChaseCamera.vortex : le
## champ s'ouvre pendant qu'elle se rapproche du kart).
##
## De l'autre côté, le monde a changé : `ambiance`, le ciel et la lumière de
## la portion qui suit, jusqu'au prochain portail (Track.ambiance_en).
##
## Il s'ouvre et se ferme d'après la course (Track.tete_total et
## queue_total) : en réseau, chaque machine voit le même portail ouvert.
##
## Ça, c'est l'anneau (`VORTEX`). Trois autres formes :
## - `CADRE` : un voile violet qui ondule dans un grand cadre de blocs
##   d'obsidienne, en travers de la route, toujours ouvert ;
## - `SOL` : un puits d'étoiles posé à plat sur la route, dans un cadre de
##   pierres, toujours ouvert. La route s'arrête au bord (un TrackGap à
##   `chute_voulue`) et le tracé plonge : on tombe dedans, et on arrive en
##   dessous, dans l'autre monde ;
## - `SEUIL` : rien à voir. On change de contrée — le ciel, les décors —
##   sans passer de porte.

enum Mode { VORTEX, CADRE, SOL, SEUIL }

@export var mode: Mode = Mode.VORTEX:
	set(valeur):
		mode = valeur
		_modifie()

@export_range(3.0, 20.0, 0.5) var rayon: float = 8.0:
	set(valeur):
		rayon = valeur
		_modifie()

@export var couleur_a: Color = Color(0.3, 0.65, 1.0)
@export var couleur_b: Color = Color(1.0, 0.45, 1.0)

## Le puits d'un portail à plat (SOL) : son fond, la lueur qui y tourne, et
## les pierres de son cadre. Par défaut, celui du bout du monde.
@export var fond_du_puits: Color = Color(0.02, 0.05, 0.06):
	set(valeur):
		fond_du_puits = valeur
		_modifie()
@export var lueur_du_puits: Color = Color(0.25, 0.85, 0.75):
	set(valeur):
		lueur_du_puits = valeur
		_modifie()
@export var pierre_du_puits: Color = Color(0.78, 0.8, 0.62):
	set(valeur):
		pierre_du_puits = valeur
		_modifie()

## Le ciel et la lumière de l'autre côté. Rien : on garde ceux du circuit.
@export var ambiance: Environment

## Faux : on change de contrée, pas de monde. Le ciel change (`ambiance`),
## mais les décors restent ceux du monde où l'on est : du marais, on voit
## toujours la tour de l'horloge au loin.
@export var nouveau_monde: bool = true

## Ce qui n'existe que de ce côté-ci du portail, jusqu'au suivant : les
## décors de cette époque (des nœuds frères, en général). Seule une caméra
## dans ce monde les voit (Track.montrer_le_monde_de) — ou, à travers le
## portail, la caméra qui filme l'autre côté.
@export var decors: Array[NodePath] = []

## Il s'ouvre quand le premier en est à cette distance, en mètres.
const AVANCE := 90.0
## Il reste ouvert jusqu'à ce que le dernier l'ait dépassé de ça.
const APRES := 8.0
## Les anneaux du couloir, tous les tant de mètres.
const PAS_DES_ANNEAUX := 6.0
## Le couloir s'évase jusqu'à ce multiple du rayon d'entrée.
const EVASEMENT := 2.0

var _ouverture: float = 0.0

# La fenêtre sur l'autre monde : une seconde caméra, placée comme celle du
# joueur, qui ne voit que l'autre côté, et la surface du portail qui montre
# son image (shaders/fenetre_portail.gdshader).
var _fenetre: ShaderMaterial
var _vue: SubViewport
var _oeil: Camera3D
var _plan_origine := Vector3.ZERO
var _plan_avant := Vector3.FORWARD
var _materiaux: Array[ShaderMaterial] = []
var _anneaux: Array[Node3D] = []
var _gerbes: Array[CPUParticles3D] = []
var _lumiere: OmniLight3D
## Pendant le tour de chauffe (TourDeChauffe) : grand ouvert, la fenêtre
## rendue une fois, et rien ne bouge.
var _en_chauffe := false

const SHADER := preload("res://shaders/vortex.gdshader")
const SHADER_FENETRE := preload("res://shaders/fenetre_portail.gdshader")

## On voit à travers un portail (VORTEX ou CADRE) jusqu'à cette distance ;
## au-delà, son voile est opaque et sa caméra se repose.
const PORTEE_FENETRE := 260.0
## L'effet sur la caméra commence tant de mètres avant le portail et finit
## tant de mètres après le couloir.
const EFFET_AUTOUR := 5.0
const SHADER_SOL := preload("res://shaders/portail_end.gdshader")
const SHADER_ETINCELLES := preload("res://shaders/portail_etincelles.gdshader")
## Le rayon de l'anneau d'étincelles dans son carré : le reste est pour le
## halo et la gerbe (portail_etincelles.gdshader, `anneau`).
const ANNEAU := 0.77

## Le cadre d'obsidienne : sa marge de chaque côté de la route, sa hauteur.
const CADRE_MARGE := 1.5
const CADRE_HAUTEUR := 11.0
const BLOC := 1.5


func _init() -> void:
	# Un couloir court : on le traverse en moins d'une seconde. Deux fois
	# plus long, sa perspective déformée durait trois secondes, et quatre
	# courses d'une coupe en enchaînent une dizaine.
	longueur = 18.0
	largeur = 18.0


func _validate_property(property: Dictionary) -> void:
	if property.name in ["decalage", "largeur"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Ouvert pour ce peloton ? `tete` et `queue` : la distance parcourue depuis
## le départ par le premier et par le dernier, `tour` la longueur d'un tour.
## Il s'ouvre quand le premier arrive à AVANCE mètres, et reste ouvert tant
## que le dernier ne l'a pas dépassé — au même tour.
func ouvert(tete: float, queue: float, tour: float) -> bool:
	if mode != Mode.VORTEX:
		# Les portails taillés dans la pierre ne se referment jamais.
		return true
	if tour <= 0.0:
		return false
	var passage := floorf((tete - debut + AVANCE) / tour) * tour + debut
	if tete < passage - AVANCE:
		return false
	return queue < passage + longueur + APRES


## Le centre de l'anneau, au-dessus de la route, en fraction de son rayon :
## le bas du cercle passe sous le bitume, et c'est à hauteur de route qu'il
## doit être assez large.
const CENTRE_DE_L_ANNEAU := 0.3
## La marge de l'anneau au-delà de chaque bord de la route, à hauteur de
## roue : les bordures passent dedans.
const MARGE_DE_L_ANNEAU := 1.5


## Le rayon de l'anneau sur ce tracé : au moins `rayon`, et assez pour que
## le cercle, coupé par la route, en couvre toute la largeur.
func rayon_de_l_anneau(c: TrackCurve) -> float:
	var demi := c.half_width + MARGE_DE_L_ANNEAU
	return maxf(rayon, demi / sqrt(1.0 - CENTRE_DE_L_ANNEAU * CENTRE_DE_L_ANNEAU))


## Le rayon du couloir à cette fraction de sa longueur : plus grand dedans.
func rayon_du_couloir(t: float) -> float:
	return rayon * lerpf(1.0, EVASEMENT, sin(clampf(t, 0.0, 1.0) * PI))


## La force de l'effet sur la caméra d'un kart à cette distance le long du
## tracé : 0 loin du portail, 1 en plein couloir.
func effet_a(distance: float, tour: float) -> float:
	if mode == Mode.SEUIL:
		return 0.0
	var etendue := longueur + EFFET_AUTOUR * 2.0
	var t := wrapf(distance - debut + EFFET_AUTOUR, 0.0, tour)
	if t > etendue:
		return 0.0
	return sin(t / etendue * PI) * _ouverture


func ouverture() -> float:
	return _ouverture


## Les nœuds de `decors` qui existent bel et bien.
func decors_du_monde() -> Array[Node3D]:
	var liste: Array[Node3D] = []
	for chemin in decors:
		var noeud := get_node_or_null(chemin) as Node3D
		if noeud != null:
			liste.append(noeud)
	return liste


## Fait de `surface` une fenêtre sur l'autre monde. En jeu seulement : dans
## l'éditeur, le portail garde son tourbillon.
func _ouvrir_une_fenetre(c: TrackCurve, racine: Node3D, surface: MeshInstance3D, rond: bool) -> void:
	_fenetre = null
	_vue = null
	_oeil = null
	if Engine.is_editor_hint() or not fenetre_possible():
		return
	if rond:
		# L'anneau d'étincelles sait déjà montrer l'autre monde.
		_fenetre = surface.material_override as ShaderMaterial
	else:
		_fenetre = ShaderMaterial.new()
		_fenetre.shader = SHADER_FENETRE
		_fenetre.set_shader_parameter("couleur_a", couleur_a)
		_fenetre.set_shader_parameter("couleur_b", couleur_b)
		_fenetre.set_shader_parameter("disque", false)
		_materiaux.append(_fenetre)
		surface.material_override = _fenetre
	_fenetre.set_shader_parameter("actif", 0.0)
	surface.layers = Track.CALQUE_FENETRES
	_vue = SubViewport.new()
	_vue.name = "VueSurLAutreMonde"
	# Le même monde que la course : la seconde caméra filme la même scène,
	# seulement d'autres calques.
	_vue.own_world_3d = false
	_vue.render_target_update_mode = SubViewport.UPDATE_DISABLED
	racine.add_child(_vue)
	_oeil = Camera3D.new()
	_vue.add_child(_oeil)
	_plan_origine = c.position_at(debut)
	_plan_avant = c.forward_at(debut)


## La qualité graphique permet-elle de voir à travers les portails ? Une
## seconde image de toute la scène, c'est trop pour un petit téléphone.
static func fenetre_possible() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return QualiteGraphique.effectif(GameSettings.qualite) != QualiteGraphique.Niveau.BASSE


## La fraction de l'écran de la seconde image : la même résolution que la
## scène elle-même. Plus basse, l'autre monde paraissait flou à côté de
## celui-ci.
static func echelle_de_la_fenetre() -> float:
	return QualiteGraphique.echelle_3d(GameSettings.qualite)


## Ce que filme la seconde caméra : le monde de l'autre côté du portail par
## rapport à `camera`, et son ciel. Devant le portail, celui qu'il ouvre ;
## derrière (on l'a traversé et l'on regarde en arrière), celui qu'on quitte.
func autre_cote(camera_position: Vector3, p: Track) -> Array:
	var devant := (camera_position - _plan_origine).dot(_plan_avant) < 0.0
	if devant:
		return [self, ambiance]
	return [p.monde_en(debut - 1.0), p.portail_en(debut - 1.0).ambiance]


func _mettre_a_jour_la_fenetre() -> void:
	if _vue == null:
		return
	var p := piste()
	var camera := get_viewport().get_camera_3d()
	var vers := _plan_origine - camera.global_position if camera != null else Vector3.ZERO
	var utile := p != null and camera != null and camera != _oeil and _ouverture > 0.01 \
		and vers.length() < PORTEE_FENETRE and vers.dot(-camera.global_basis.z) > -20.0
	if not utile:
		_vue.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_fenetre.set_shader_parameter("actif", 0.0)
		return
	var cote := autre_cote(camera.global_position, p)
	_oeil.cull_mask = p.masque_pour(cote[0]) & ~Track.CALQUE_FENETRES
	_oeil.environment = cote[1]
	_oeil.global_transform = camera.global_transform
	_oeil.fov = camera.fov
	_oeil.near = camera.near
	_oeil.far = camera.far
	_oeil.current = true
	var ecran := get_viewport()
	var taille := Vector2i(ecran.get_visible_rect().size * echelle_de_la_fenetre())
	if _vue.size != taille:
		_vue.size = taille
	# Le même lissage des bords que l'écran : sans lui, l'autre monde
	# crénelait à côté de celui-ci.
	_vue.msaa_3d = ecran.msaa_3d
	_vue.screen_space_aa = ecran.screen_space_aa
	if _fenetre.get_shader_parameter("vue") == null:
		_fenetre.set_shader_parameter("vue", _vue.get_texture())
	_vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fenetre.set_shader_parameter("actif", 1.0)


func _materiau(couloir: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("couleur_a", couleur_a)
	m.set_shader_parameter("couleur_b", couleur_b)
	m.set_shader_parameter("couloir", couloir)
	m.set_shader_parameter("ouverture", 0.0)
	_materiaux.append(m)
	return m


func _construire(c: TrackCurve, racine: Node3D) -> void:
	_materiaux.clear()
	_anneaux.clear()
	_gerbes.clear()
	_lumiere = null
	match mode:
		Mode.SEUIL:
			return
		Mode.CADRE:
			_construire_le_cadre(c, racine)
			return
		Mode.SOL:
			_construire_le_puits(c, racine)
			return
	# L'entrée : un anneau d'étincelles, et dedans l'autre monde. Pas de
	# couloir à voir : on passe un cercle de feu, et l'on est ailleurs.
	var entree := Node3D.new()
	var r := rayon_de_l_anneau(c)
	entree.transform = Transform3D(c.basis_at(debut), TrackFeature.point(c, debut, 0.0, r * CENTRE_DE_L_ANNEAU))
	racine.add_child(entree)
	var disque := MeshInstance3D.new()
	var plan := QuadMesh.new()
	plan.size = Vector2.ONE * r * 2.0 / ANNEAU
	disque.mesh = plan
	var feu := ShaderMaterial.new()
	feu.shader = SHADER_ETINCELLES
	feu.set_shader_parameter("anneau", ANNEAU)
	feu.set_shader_parameter("ouverture", 0.0)
	_materiaux.append(feu)
	disque.material_override = feu
	disque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	entree.add_child(disque)
	_ouvrir_une_fenetre(c, racine, disque, true)
	entree.add_child(_gerbe(r))
	_anneaux.append(entree)
	if not Engine.is_editor_hint():
		_lumiere = OmniLight3D.new()
		_lumiere.light_color = Color(1.0, 0.55, 0.15)
		_lumiere.omni_range = r * 4.0
		_lumiere.light_energy = 0.0
		_lumiere.position = Vector3(0, 0, -2.0)
		entree.add_child(_lumiere)
	_appliquer()


## Les étincelles qui jaillissent de l'anneau et retombent en pluie d'or.
func _gerbe(r: float) -> CPUParticles3D:
	var gerbe := CPUParticles3D.new()
	gerbe.name = "Etincelles"
	gerbe.amount = 70 if QualiteGraphique.effectif(GameSettings.qualite) != QualiteGraphique.Niveau.BASSE else 30
	gerbe.lifetime = 0.9
	gerbe.local_coords = true
	gerbe.emitting = false
	gerbe.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	gerbe.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	gerbe.emission_ring_radius = r
	gerbe.emission_ring_inner_radius = r - 0.25
	gerbe.emission_ring_height = 0.1
	gerbe.spread = 180.0
	gerbe.initial_velocity_min = 1.5
	gerbe.initial_velocity_max = 4.5
	gerbe.gravity = Vector3(0.0, -6.0, 0.0)
	gerbe.scale_amount_min = 0.5
	gerbe.scale_amount_max = 1.2
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	degrade.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	degrade.add_point(0.4, Color(1.0, 0.6, 0.15, 1.0))
	gerbe.color_ramp = degrade
	var grain := QuadMesh.new()
	grain.size = Vector2(0.24, 0.24)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	grain.material = m
	gerbe.mesh = grain
	_gerbes.append(gerbe)
	return gerbe


## Le portail du monde d'en dessous : un cadre de blocs d'obsidienne autour
## de toute la largeur de la route, et le voile qui ondule dedans.
func _construire_le_cadre(c: TrackCurve, racine: Node3D) -> void:
	var repere := Node3D.new()
	repere.transform = Transform3D(c.basis_at(debut), c.position_at(debut))
	racine.add_child(repere)
	var obsidienne := StandardMaterial3D.new()
	obsidienne.albedo_color = Color(0.09, 0.05, 0.14)
	obsidienne.roughness = 0.35
	var largeur := c.half_width + CADRE_MARGE
	var x := -largeur - BLOC * 0.5
	# Deux montants et un linteau, bloc par bloc.
	while x <= largeur + BLOC * 0.5 + 0.01:
		_bloc(repere, Vector3(x, CADRE_HAUTEUR + BLOC * 0.5, 0.0), obsidienne)
		x += BLOC
	var y := BLOC * 0.5
	while y < CADRE_HAUTEUR:
		for cote in [-1.0, 1.0]:
			_bloc(repere, Vector3(cote * (largeur + BLOC * 0.5), y, 0.0), obsidienne)
		y += BLOC
	var voile := MeshInstance3D.new()
	var plan := QuadMesh.new()
	plan.size = Vector2(largeur * 2.0, CADRE_HAUTEUR)
	voile.mesh = plan
	var m := _materiau(false)
	m.set_shader_parameter("plat", true)
	voile.material_override = m
	voile.position = Vector3(0.0, CADRE_HAUTEUR * 0.5, 0.0)
	voile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	repere.add_child(voile)
	_ouvrir_une_fenetre(c, racine, voile, false)
	if not Engine.is_editor_hint():
		_lumiere = OmniLight3D.new()
		_lumiere.light_color = couleur_b
		_lumiere.omni_range = largeur * 2.5
		_lumiere.position = Vector3(0.0, CADRE_HAUTEUR * 0.5, 1.0)
		repere.add_child(_lumiere)
	_ouverture = 1.0
	_appliquer()


## Le portail du bout du monde : un puits d'étoiles à plat, au ras de la
## route, sur toute la longueur du trou, et son cadre de pierres claires
## serties d'un œil vert.
func _construire_le_puits(c: TrackCurve, racine: Node3D) -> void:
	# À plat, au niveau de la rive d'entrée : le tracé plonge dessous.
	var avant := c.tangent_at(debut)
	var droite := Vector3(-avant.z, 0.0, avant.x)
	var repere := Node3D.new()
	repere.transform = Transform3D(Basis(droite, Vector3.UP, -avant), c.position_at(debut))
	racine.add_child(repere)
	var largeur := c.half_width * 2.0
	var puits := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(largeur, longueur)
	puits.mesh = plan
	var m := ShaderMaterial.new()
	m.shader = SHADER_SOL
	m.set_shader_parameter("fond", fond_du_puits)
	m.set_shader_parameter("lueur", lueur_du_puits)
	puits.material_override = m
	puits.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puits.position = Vector3(0.0, 0.02, -longueur * 0.5)
	repere.add_child(puits)
	var pierre := StandardMaterial3D.new()
	pierre.albedo_color = pierre_du_puits
	var oeil := StandardMaterial3D.new()
	oeil.albedo_color = lueur_du_puits.darkened(0.15)
	oeil.emission_enabled = true
	oeil.emission = lueur_du_puits.darkened(0.3)
	# Une rangée de pierres le long de chaque rive, et au fond : le kart
	# entre par le côté ouvert.
	var z := 0.0
	while z <= longueur:
		for cote in [-1.0, 1.0]:
			_pierre_du_cadre(repere, Vector3(cote * (c.half_width + BLOC * 0.5), 0.0, -z), pierre, oeil)
		z += BLOC
	var x := -c.half_width - BLOC * 0.5
	while x <= c.half_width + BLOC * 0.5 + 0.01:
		_pierre_du_cadre(repere, Vector3(x, 0.0, -longueur - BLOC * 0.5), pierre, oeil)
		x += BLOC
	if not Engine.is_editor_hint():
		_lumiere = OmniLight3D.new()
		_lumiere.light_color = Color(0.3, 0.9, 0.75)
		_lumiere.omni_range = largeur * 1.5
		_lumiere.light_energy = 2.0
		_lumiere.position = Vector3(0.0, 2.0, -longueur * 0.5)
		repere.add_child(_lumiere)
	_ouverture = 1.0


func _bloc(parent: Node3D, ou: Vector3, materiau: Material) -> void:
	var bloc := MeshInstance3D.new()
	var boite := BoxMesh.new()
	boite.size = Vector3.ONE * BLOC
	bloc.mesh = boite
	bloc.material_override = materiau
	bloc.position = ou
	parent.add_child(bloc)


func _pierre_du_cadre(repere: Node3D, ou: Vector3, pierre: Material, oeil: Material) -> void:
	_bloc(repere, ou + Vector3(0.0, -BLOC * 0.25, 0.0), pierre)
	var pupille := MeshInstance3D.new()
	var boule := SphereMesh.new()
	boule.radius = 0.35
	boule.height = 0.5
	pupille.mesh = boule
	pupille.material_override = oeil
	pupille.position = ou + Vector3(0.0, BLOC * 0.5 + 0.05, 0.0)
	repere.add_child(pupille)


## Le tour de chauffe, derrière l'écran de chargement : le portail se montre
## grand ouvert, et sa fenêtre filme une fois l'autre monde sous son ciel,
## depuis `camera`. En GL Compatibility, un matériau, un ciel, un brouillard
## ne se compilent que la première fois qu'on les dessine : sans ça, chaque
## portail figeait l'image en s'ouvrant, en pleine course, sur un petit
## téléphone. La fenêtre prend aussi d'avance sa taille définitive.
func chauffer(camera: Camera3D) -> void:
	_en_chauffe = true
	_ouverture = 1.0
	_appliquer()
	for gerbe in _gerbes:
		gerbe.emitting = true
	var p := piste()
	if _vue == null or p == null or camera == null:
		return
	_vue.size = Vector2i(get_viewport().get_visible_rect().size * echelle_de_la_fenetre())
	_vue.msaa_3d = get_viewport().msaa_3d
	_vue.screen_space_aa = get_viewport().screen_space_aa
	_oeil.global_transform = camera.global_transform
	_oeil.fov = camera.fov
	_oeil.far = camera.far
	_oeil.cull_mask = p.masque_pour(self) & ~Track.CALQUE_FENETRES
	_oeil.environment = ambiance
	_oeil.current = true
	_fenetre.set_shader_parameter("vue", _vue.get_texture())
	_fenetre.set_shader_parameter("actif", 1.0)
	_vue.render_target_update_mode = SubViewport.UPDATE_ONCE


## Fin du tour de chauffe : le portail reprend son cours, fermé s'il l'était.
func fin_de_chauffe() -> void:
	if not _en_chauffe:
		return
	_en_chauffe = false
	if mode == Mode.VORTEX:
		_ouverture = 0.0
		_appliquer()
	if _vue != null:
		_vue.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_fenetre.set_shader_parameter("actif", 0.0)


func _process(delta: float) -> void:
	if _en_chauffe:
		return
	if not Engine.is_editor_hint():
		_mettre_a_jour_la_fenetre()
	if mode != Mode.VORTEX:
		return
	if Engine.is_editor_hint():
		_ouverture = 1.0
		_appliquer()
		return
	var p := piste()
	if p == null:
		return
	var cible := 1.0 if ouvert(p.tete_total, p.queue_total, p.track_curve.length) else 0.0
	_ouverture = move_toward(_ouverture, cible, delta * (0.75 if cible > _ouverture else 0.8))
	_appliquer()


func _appliquer() -> void:
	for m in _materiaux:
		m.set_shader_parameter("ouverture", _ouverture)
	# Un tout petit cercle, l'autre monde déjà dedans, qui grandit jusqu'à sa
	# taille — et rapetisse jusqu'à disparaître à la fermeture.
	var echelle := lerpf(0.03, 1.0, 1.0 - pow(1.0 - _ouverture, 2.0))
	for anneau in _anneaux:
		anneau.scale = Vector3.ONE * echelle
		anneau.visible = _ouverture > 0.01
	for gerbe in _gerbes:
		gerbe.emitting = _ouverture > 0.15
	if _lumiere != null:
		_lumiere.light_energy = 3.0 * _ouverture
