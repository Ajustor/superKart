class_name KartVisuals
extends Node3D

## Inclinaison de la caisse et étincelles dont la couleur annonce le palier
## de mini-turbo chargé. Purement cosmétique : ne modifie jamais le moteur.

## Les trois couleurs se lisent en vision périphérique, sans quitter la route
## des yeux : il leur faut donc à la fois de l'écart de teinte et de l'écart de
## luminosité. Le palier 3 tire vers le magenta plutôt que vers le violet, qui
## était trop proche du bleu du palier 1 et plus sombre que lui.
const TIER_COLORS := [
	Color(0.35, 0.60, 1.00),   # palier 1 — bleu      (teinte 217°, luma 0.58)
	Color(1.00, 0.65, 0.14),   # palier 2 — orange    (teinte  33°, luma 0.69)
	Color(1.00, 0.45, 0.88),   # palier 3 — magenta   (teinte 313°, luma 0.60)
]

@export var kart_path: NodePath
@export var body_path: NodePath
@export var sparks_path: NodePath
@export var max_lean_deg: float = 14.0
@export var lean_stiffness: float = 10.0

var _kart: Kart
var _body: Node3D
var _sparks: CPUParticles3D
var _spark_material: StandardMaterial3D
var _inclinaison: float = 0.0
## Le tonneau d'une figure, de 0 à 1 ; négatif hors figure.
var _figure: float = -1.0
## Le train de roues : il fait le tonneau avec la caisse. La suspension place
## chaque roue dans ce repère, le tonneau tourne le repère entier.
var _roues: Node3D
const DUREE_FIGURE := 0.45
var _poussiere: CPUParticles3D
var _flammes: CPUParticles3D
## Le sillage d'un autre kart : des filets de vent qui filent autour de la
## caisse tant que la jauge d'aspiration monte.
var _sillage: CPUParticles3D
var _fumee_de_glisse: CPUParticles3D
var _ombre: MeshInstance3D
var _matiere_sillage: StandardMaterial3D
var _matiere_flammes: StandardMaterial3D
## Rétréci par un éclair : la caisse et les roues à cette échelle, lissée.
const ECHELLE_RETRECI := 0.6
var _echelle: float = 1.0
var _position_caisse := Vector3.ZERO
## L'allure du modèle (ModeleKart), que le rétrécissement respecte.
var _echelle_caisse := Vector3.ONE
## Le pilote (Personnage) : son animation suit ce qui arrive au kart.
## Un geste bref (objet lancé, choc) passe avant la conduite (ou le repos,
## debout sur le nuage magique) ; une figure et
## un tête-à-queue passent avant tout ; l'arrivée dure jusqu'au bout.
const ANIM_FIGURE := "jump"
const ANIM_TETE_A_QUEUE := "fall"
const GESTES := {
	&"lancer": ["attack-melee-right", 0.4],
	&"choc": ["emote-no", 0.65],
}
const FETES := {&"victoire": "emote-yes", &"defaite": "emote-no"}
## Un choc contre un autre kart en deçà de cette force, en m/s, ne se voit pas.
const CHOC_VISIBLE := 4.0
const FONDU_PILOTE := 0.15
var _pilote: Node
var _anim_pilote: AnimationPlayer
var _geste := ""
var _geste_reste := 0.0
var _fete := ""
## Sous étoile, une bulle aux couleurs qui tournent.
var _aura: MeshInstance3D
var _matiere_aura: StandardMaterial3D


func _ready() -> void:
	_kart = get_node(kart_path) as Kart
	_body = get_node(body_path) as Node3D
	_roues = _kart.get_node_or_null("Wheels") as Node3D if _kart != null else null
	_sparks = get_node(sparks_path) as CPUParticles3D
	assert(_kart != null and _body != null and _sparks != null,
		"KartVisuals a besoin du kart, de la caisse et des particules")

	# Matériau propre à cette instance, sinon tous les karts changeraient
	# de couleur ensemble.
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_sparks.material_override = _spark_material
	_sparks.emitting = false
	_kart.figure.connect(func() -> void: _figure = 0.0)
	_kart.geste.connect(_sur_geste)
	_kart.bouscule.connect(func(force: float) -> void:
		if force >= CHOC_VISIBLE:
			_sur_geste(&"choc"))
	_poussiere = _creer_poussiere()
	add_child(_poussiere)
	_flammes = _creer_flammes()
	add_child(_flammes)
	_sillage = _creer_sillage()
	add_child(_sillage)
	_fumee_de_glisse = _creer_fumee_de_glisse()
	add_child(_fumee_de_glisse)
	_ombre = _creer_ombre_de_contact()
	add_child(_ombre)
	_position_caisse = _body.position
	_echelle_caisse = _body.scale


func _process(delta: float) -> void:
	var motor := _kart.motor
	_update_lean(motor, delta)
	_update_sparks(motor)
	# De la poussière sous les roues hors piste : on sent qu'on y perd. Le
	# nuage magique ne touche pas le sol : ni poussière, ni fumée de pneus.
	var touche_le_sol := _kart.au_sol and not ModeleKart.sur_un_nuage(_kart)
	_poussiere.emitting = motor.on_offroad and touche_le_sol and absf(motor.speed) > 5.0
	_fumee_de_glisse.emitting = motor.state == KartMotor.State.DRIFT and touche_le_sol and absf(motor.speed) > 6.0
	_ombre.visible = _kart.au_sol and not QualiteGraphique.ombres_portees(GameSettings.qualite)
	_update_flammes(motor)
	_update_sillage()
	_update_pilote(motor, delta)
	_update_taille(motor, delta)
	_update_aura(motor)


## Pour le tour de chauffe : l'aura d'étoile et des copies qui émettent des
## étincelles, de la poussière et des flammes, jamais vues avant le départ.
func echantillons() -> Array[Node3D]:
	var liste: Array[Node3D] = []
	var aura := MeshInstance3D.new()
	aura.mesh = SphereMesh.new()
	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	matiere.cull_mode = BaseMaterial3D.CULL_DISABLED
	matiere.albedo_color = Color(1, 0.8, 0.3, 0.35)
	aura.material_override = matiere
	liste.append(aura)
	for source in [_sparks, _poussiere, _flammes, _sillage, _fumee_de_glisse]:
		# Sans émettre : une particule qui démarre hors de l'arbre lit sa
		# position globale, qui n'existe pas encore. TourDeChauffe l'allume
		# une fois posée.
		liste.append((source as Node3D).duplicate() as Node3D)
	return liste


func _update_taille(motor: KartMotor, delta: float) -> void:
	var cible := ECHELLE_RETRECI if motor.retreci > 0.0 else 1.0
	if _echelle == cible:
		return
	_echelle = move_toward(_echelle, cible, 2.5 * delta)
	_body.scale = _echelle_caisse * _echelle
	_body.position = _position_caisse * _echelle


func _update_aura(motor: KartMotor) -> void:
	if motor.etoile <= 0.0:
		if _aura != null:
			_aura.visible = false
		return
	if _aura == null:
		_aura = MeshInstance3D.new()
		var forme := SphereMesh.new()
		forme.radius = 1.3
		forme.height = 1.9
		_aura.mesh = forme
		_matiere_aura = StandardMaterial3D.new()
		_matiere_aura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_matiere_aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_matiere_aura.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_matiere_aura.cull_mode = BaseMaterial3D.CULL_DISABLED
		_aura.material_override = _matiere_aura
		_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aura.position = _position_caisse
		add_child(_aura)
	var t := Time.get_ticks_msec() / 1000.0
	# Elle clignote quand elle va s'éteindre.
	_aura.visible = motor.etoile > 1.5 or fmod(t * 8.0, 1.0) < 0.5
	_matiere_aura.albedo_color = Color.from_hsv(fmod(t * 1.5, 1.0), 0.8, 1.0, 0.35)


func _update_lean(motor: KartMotor, delta: float) -> void:
	var lean := 0.0
	if motor.state == KartMotor.State.DRIFT:
		lean = -deg_to_rad(max_lean_deg) * float(motor.drift_dir)
	_inclinaison = lerpf(_inclinaison, lean, 1.0 - exp(-lean_stiffness * delta))
	# Un tonneau complet, vif au début et qui ralentit en fin de tour.
	var tonneau := 0.0
	if _figure >= 0.0:
		_figure += delta / DUREE_FIGURE
		if _figure >= 1.0:
			_figure = -1.0
		else:
			tonneau = TAU * (1.0 - pow(1.0 - _figure, 2.0))
	_body.rotation.z = _inclinaison + tonneau
	_tourner_les_roues(tonneau)


## Les roues suivent le tonneau, autour du même pivot que la caisse : sans
## ça, la caisse faisait sa vrille au-dessus de quatre roues restées à plat.
## L'inclinaison du dérapage, elle, ne touche que la caisse.
func _tourner_les_roues(tonneau: float) -> void:
	if _roues == null:
		return
	if tonneau == 0.0 and _echelle == 1.0:
		if _roues.transform != Transform3D.IDENTITY:
			_roues.transform = Transform3D.IDENTITY
		return
	var pivot := _body.position
	var rotation_ := Basis(Vector3.BACK, tonneau)
	# Rétrécies avec la caisse, autour du pied du kart.
	_roues.transform = Transform3D(Basis.from_scale(Vector3.ONE * _echelle)) \
		* Transform3D(rotation_, pivot - rotation_ * pivot)


## La recoloration est globale et instantanée : toutes les particules vivantes
## changent de couleur d'un coup. C'est volontaire — un dégradé par particule
## ferait cohabiter deux couleurs pendant une fraction de seconde à chaque
## changement de palier, soit exactement l'ambiguïté que ce signal doit éviter.
func _update_sparks(motor: KartMotor) -> void:
	var tier := 0
	if motor.state == KartMotor.State.DRIFT:
		tier = motor.tier_for_charge(motor.drift_charge)

	var should_emit := tier > 0
	if _sparks.emitting != should_emit:
		_sparks.emitting = should_emit
	if not should_emit:
		return

	var color: Color = TIER_COLORS[mini(tier, TIER_COLORS.size()) - 1]
	if _spark_material.albedo_color != color:
		_spark_material.albedo_color = color
	# Plus le palier est haut, plus la gerbe est fournie : on la lit du coin
	# de l'œil, sans regarder la couleur. Des étincelles plus grosses plutôt
	# que plus nombreuses : changer leur nombre relancerait la gerbe.
	var taille: float = [0.6, 0.85, 1.2][mini(tier, 3) - 1]
	_sparks.scale_amount_min = 0.5 * taille
	_sparks.scale_amount_max = 1.2 * taille


## Peu de particules, calculées par le processeur : des bouffées de fumée
## (le sprite de fumée de Kenney) qui montent et s'étalent derrière le kart.
## Assez pour se voir, pas assez pour peser sur un téléphone.
func _creer_poussiere() -> CPUParticles3D:
	return _creer_fumee(Color(0.72, 0.62, 0.45), 18, 0.6, Vector3(0.0, 0.15, 0.8), 1.4)


## La fumée des pneus pendant une glisse : blanche, en bouffées qui
## s'étalent derrière les roues arrière.
func _creer_fumee_de_glisse() -> CPUParticles3D:
	var p := _creer_fumee(Color(0.92, 0.92, 0.95), 16, 0.7, Vector3(0.0, 0.12, 0.75), 1.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.55, 0.05, 0.1)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	return p


const FUMEE := "res://assets/kenney/effets/fumee.png"
static var _matiere_fumee: StandardMaterial3D


func _creer_fumee(teinte: Color, nombre: int, duree: float, ou: Vector3, grandit: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = nombre
	p.lifetime = duree
	p.position = ou
	p.direction = Vector3(0.0, 1.0, 1.0)
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.0, 0.6, 0.0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	var courbe := Curve.new()
	courbe.add_point(Vector2(0.0, 0.5))
	courbe.add_point(Vector2(1.0, grandit))
	p.scale_amount_curve = courbe
	# Elle se dissipe : opaque à la naissance, transparente à la fin.
	var fondu := Gradient.new()
	fondu.set_color(0, Color(teinte, 0.7))
	fondu.set_color(1, Color(teinte, 0.0))
	p.color_ramp = fondu
	var forme := QuadMesh.new()
	forme.size = Vector2(0.9, 0.9)
	if _matiere_fumee == null:
		_matiere_fumee = StandardMaterial3D.new()
		_matiere_fumee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_matiere_fumee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_matiere_fumee.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_matiere_fumee.vertex_color_use_as_albedo = true
		_matiere_fumee.albedo_texture = load(FUMEE)
		_matiere_fumee.cull_mode = BaseMaterial3D.CULL_DISABLED
	forme.material = _matiere_fumee
	p.mesh = forme
	return p


## L'ombre de contact : une tache sombre et floue sous le kart, quand le
## soleil ne projette pas d'ombre (qualité moyenne ou basse, les téléphones) :
## sans elle, le kart flotte au-dessus de la route.
func _creer_ombre_de_contact() -> MeshInstance3D:
	var tache := MeshInstance3D.new()
	var forme := PlaneMesh.new()
	forme.size = Vector2(1.9, 2.8)
	tache.mesh = forme
	var degrade := Gradient.new()
	degrade.set_color(0, Color(0.0, 0.0, 0.0, 0.55))
	degrade.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = degrade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.albedo_texture = texture
	tache.material_override = matiere
	tache.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tache.position = Vector3(0.0, 0.04, 0.0)
	return tache


## Des flammes aux pots d'échappement pendant un turbo, de la couleur de sa
## force : bleu pour un petit mini-turbo, orange pour un moyen ou un
## champignon, magenta pour le plus fort.
func _update_flammes(motor: KartMotor) -> void:
	var turbo := motor.boost_timer > 0.0
	_flammes.emitting = turbo
	if not turbo:
		return
	var couleur: Color = TIER_COLORS[0]
	if motor.boost_multiplier >= 1.45:
		couleur = TIER_COLORS[2]
	elif motor.boost_multiplier >= 1.3:
		couleur = TIER_COLORS[1]
	_matiere_flammes.albedo_color = couleur


func _creer_flammes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.18
	p.position = Vector3(0.0, 0.45, 1.05)
	p.direction = Vector3(0.0, 0.1, 1.0)
	p.spread = 12.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	var courbe := Curve.new()
	courbe.add_point(Vector2(0.0, 1.0))
	courbe.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = courbe
	var forme := SphereMesh.new()
	forme.radius = 0.16
	forme.height = 0.32
	forme.radial_segments = 6
	forme.rings = 3
	_matiere_flammes = StandardMaterial3D.new()
	_matiere_flammes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_matiere_flammes.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_matiere_flammes.albedo_color = TIER_COLORS[0]
	forme.material = _matiere_flammes
	p.mesh = forme
	return p


## Les filets de vent, de plus en plus francs à mesure que la jauge monte.
func _update_sillage() -> void:
	var jauge := _kart.aspiration
	_sillage.emitting = jauge > 0.05
	if _sillage.emitting:
		_matiere_sillage.albedo_color.a = lerpf(0.15, 0.6, jauge)


## Des traits fins, blancs, qui partent de l'avant du kart et filent vers
## l'arrière, dans son repère : on les voit passer, comme le vent.
func _creer_sillage() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 16
	p.lifetime = 0.22
	p.local_coords = true
	p.position = Vector3(0.0, 0.6, -1.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.3, 0.5, 0.3)
	p.direction = Vector3(0.0, 0.0, 1.0)
	p.spread = 3.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector3.ZERO
	var forme := BoxMesh.new()
	forme.size = Vector3(0.03, 0.03, 0.9)
	_matiere_sillage = StandardMaterial3D.new()
	_matiere_sillage.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_matiere_sillage.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_matiere_sillage.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_matiere_sillage.albedo_color = Color(0.85, 0.95, 1.0, 0.3)
	forme.material = _matiere_sillage
	p.mesh = forme
	return p


func _sur_geste(quoi: StringName) -> void:
	if FETES.has(quoi):
		_fete = FETES[quoi]
	elif GESTES.has(quoi):
		_geste = GESTES[quoi][0]
		_geste_reste = GESTES[quoi][1]


## L'animation du pilote : retrouvée quand le pilote change (le garage, le
## salon), puis choisie à chaque image, en fondu.
func _update_pilote(motor: KartMotor, delta: float) -> void:
	var pilote := _kart.get_node_or_null("Body/Pilote")
	if pilote != _pilote:
		_pilote = pilote
		_anim_pilote = pilote.find_child("AnimationPlayer", true, false) as AnimationPlayer if pilote != null else null
	if _anim_pilote == null:
		return
	_geste_reste = maxf(_geste_reste - delta, 0.0)
	var voulue := Personnage.animation_de(_kart)
	if motor.state == KartMotor.State.STUNNED:
		voulue = ANIM_TETE_A_QUEUE
	elif _figure >= 0.0:
		voulue = ANIM_FIGURE
	elif _geste_reste > 0.0:
		voulue = _geste
	elif _fete != "":
		voulue = _fete
	if _anim_pilote.current_animation != voulue and _anim_pilote.has_animation(voulue):
		var anim := _anim_pilote.get_animation(voulue)
		# Ce qui dure se répète ; un geste se joue une fois.
		if voulue == ANIM_TETE_A_QUEUE or voulue == _fete:
			anim.loop_mode = Animation.LOOP_LINEAR
		_anim_pilote.play(voulue, FONDU_PILOTE)
