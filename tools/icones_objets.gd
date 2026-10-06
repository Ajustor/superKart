extends Node

## Les icônes des objets (resources/icones_objets/<nom>.png), photographiées
## sur les modèles 3D du jeu, fond transparent, pour la case d'objet du HUD
## (ItemIcons) :
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##       -s tools/lance_outil.gd -- icones_objets
##
## L'éclair n'a pas de modèle : il reste dessiné au trait.

const DOSSIER := "res://resources/icones_objets/"
const TAILLE := 128
const CHAMPIGNON := "res://assets/kenney/objets/mushroom-red.glb"
const PIECE := "res://assets/kenney/objets/coin-gold.glb"
const ETOILE := "res://assets/kenney/decor/star.glb"

var _vue: SubViewport
var _scene: Node3D


func _ready() -> void:
	_vue = SubViewport.new()
	_vue.size = Vector2i(TAILLE, TAILLE)
	_vue.transparent_bg = true
	_vue.msaa_3d = Viewport.MSAA_4X
	_vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vue)
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	lumiere.light_energy = 1.1
	_vue.add_child(lumiere)
	var monde := WorldEnvironment.new()
	monde.environment = Environment.new()
	monde.environment.background_mode = Environment.BG_CLEAR_COLOR
	monde.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	monde.environment.ambient_light_color = Color(1, 1, 1)
	monde.environment.ambient_light_energy = 0.75
	_vue.add_child(monde)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	camera.position = Vector3(0.0, 1.1, 3.0)
	_vue.add_child(camera)
	camera.look_at(Vector3.ZERO)

	var objets := ItemManager.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	# La fausse caisse de face, sans son point d'interrogation : ItemIcons le
	# dessine par-dessus, net à toutes les tailles.
	var fausse := objets._visuel_fausse_boite().get_child(0) as MeshInstance3D
	fausse.get_parent().remove_child(fausse)
	fausse.rotation = Vector3.ZERO
	await _photographier("fausse_boite", fausse, 1.15, Vector3(0.0, 30.0, 0.0))
	await _photographier("banane", objets._visuel_banane(), 2.6, Vector3(0.0, 20.0, -15.0))
	for genre in 3:
		var nom: String = ["carapace_verte", "carapace_rouge", "carapace_bleue"][genre]
		await _photographier(nom, objets._visuel_carapace(genre), 1.25 if genre == 2 else 1.6, Vector3(-10.0, 0.0, 0.0),
			Vector3(0.0, -0.08, 0.0))
	await _photographier("champignon", _champignon(), 1.0, Vector3(0.0, 20.0, 0.0))
	await _photographier("etoile", _modele(ETOILE, 1.6), 1.0, Vector3(0.0, 0.0, 0.0))
	await _photographier("piece", _modele(PIECE, 1.5), 1.0, Vector3(0.0, -25.0, 0.0))
	objets.free()
	get_tree().quit()


func _modele(chemin: String, taille: float) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = KenneyDecor.modele(chemin, taille)
	return mi


## Le champignon rouge du Nature Kit, repeint : ses couleurs d'origine,
## sans texture, sortaient ternes et le pied noir.
func _champignon() -> Node3D:
	var mi := _modele(CHAMPIGNON, 1.5) as MeshInstance3D
	for s in mi.mesh.get_surface_count():
		var nom := mi.mesh.surface_get_material(s).resource_name
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.16, 0.13) if nom == "colorRed" else Color(0.98, 0.93, 0.82)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.6
		mi.set_surface_override_material(s, m)
	return mi


func _photographier(nom: String, objet: Node3D, echelle: float, rotation: Vector3,
		decalage := Vector3.ZERO) -> void:
	if _scene != null:
		_scene.queue_free()
	_scene = Node3D.new()
	_scene.scale = Vector3.ONE * echelle
	_scene.rotation_degrees = rotation
	_scene.position = decalage
	_scene.add_child(objet)
	_vue.add_child(_scene)
	# Quelques images : le temps que les shaders se compilent.
	for i in 4:
		await RenderingServer.frame_post_draw
	var image := _vue.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(DOSSIER + nom + ".png"))
	print("icône ", nom)
