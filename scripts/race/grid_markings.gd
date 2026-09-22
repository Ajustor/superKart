class_name GridMarkings
extends Node3D

## Peint la ligne de départ, les cases de la grille et le portique sur la
## chaussée. Tout est lu sur la session : les cases peintes sont exactement
## celles où les karts sont posés, et déplacer la grille dans RaceSession
## déplace la peinture avec.
##
## Purement décoratif, sans collision : un kart roule sur la peinture comme
## sur la route.

@export var session_path: NodePath

## Hauteur de la peinture au-dessus du bitume. Assez pour ne pas scintiller
## avec la route, trop peu pour se voir de profil.
const EPAISSEUR_PEINTURE := 0.03
const PROFONDEUR_LIGNE := 1.6
const CASE_LARGEUR := 2.2
const CASE_LONGUEUR := 2.6
const TRAIT := 0.14
const PORTIQUE_HAUTEUR := 5.5


func _ready() -> void:
	var session := get_node_or_null(session_path) as RaceSession
	assert(session != null, "session_path doit pointer vers une RaceSession")
	# La session peut attendre son circuit avant de poser les karts : on
	# attend la grille plutôt que de peindre une grille vide.
	if session.entries.is_empty():
		await session.grille_prete
	var piste := session.entries[0].progress.track
	var blanc := _materiau(Color(0.95, 0.95, 0.95))

	_ligne_de_depart(piste)
	_portique(piste)
	for i in session.entries.size():
		_case(session.transformee_de_case(i), i + 1, blanc)


func _materiau(couleur: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 0.8
	return m


## Le damier : une texture de deux pixels de haut répétée sur toute la
## largeur. Le filtre au plus proche garde des cases nettes à toute distance.
func _ligne_de_depart(piste: TrackCurve) -> void:
	var largeur := piste.half_width * 2.0
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color.WHITE)
	image.set_pixel(1, 1, Color.WHITE)
	image.set_pixel(1, 0, Color(0.08, 0.08, 0.08))
	image.set_pixel(0, 1, Color(0.08, 0.08, 0.08))
	var materiau := StandardMaterial3D.new()
	materiau.albedo_texture = ImageTexture.create_from_image(image)
	materiau.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Des carreaux de 0,8 m : deux rangées sur la profondeur de la ligne.
	materiau.uv1_scale = Vector3(largeur / (PROFONDEUR_LIGNE), 1.0, 1.0)

	var plan := PlaneMesh.new()
	plan.size = Vector2(largeur, PROFONDEUR_LIGNE)
	var ligne := MeshInstance3D.new()
	ligne.name = "LigneDeDepart"
	ligne.mesh = plan
	ligne.material_override = materiau
	ligne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d := RaceSession.DEPART
	ligne.transform = Transform3D(piste.basis_at(d),
		piste.position_at(d) + piste.up_at(d) * EPAISSEUR_PEINTURE)
	add_child(ligne)


## Deux poteaux et une banderole au-dessus de la ligne : on voit l'arrivée
## venir de loin, ce que la peinture seule ne permet pas dans une descente.
func _portique(piste: TrackCurve) -> void:
	var d := RaceSession.DEPART
	var repere := Transform3D(piste.basis_at(d), piste.position_at(d))
	var ecart := piste.half_width + 0.8
	var poteau := _materiau(Color(0.85, 0.15, 0.15))
	var banderole := _materiau(Color(0.12, 0.12, 0.14))

	for cote in [-1.0, 1.0]:
		_boite(repere, Vector3(cote * ecart, PORTIQUE_HAUTEUR * 0.5, 0.0),
			Vector3(0.5, PORTIQUE_HAUTEUR, 0.5), poteau)
	_boite(repere, Vector3(0.0, PORTIQUE_HAUTEUR, 0.0),
		Vector3(ecart * 2.0 + 0.5, 1.1, 0.35), banderole)

	var texte := Label3D.new()
	texte.text = "DÉPART · ARRIVÉE"
	texte.font_size = 96
	texte.pixel_size = 0.01
	texte.outline_size = 0
	texte.modulate = Color(1, 0.9, 0.3)
	# Face aux karts qui arrivent : Godot regarde vers -Z, le texte vers +Z.
	texte.transform = repere * Transform3D(Basis(), Vector3(0.0, PORTIQUE_HAUTEUR, 0.2))
	add_child(texte)


func _boite(repere: Transform3D, local: Vector3, taille: Vector3, materiau: Material) -> void:
	var boite := BoxMesh.new()
	boite.size = taille
	var instance := MeshInstance3D.new()
	instance.mesh = boite
	instance.material_override = materiau
	instance.transform = repere * Transform3D(Basis(), local)
	add_child(instance)


## Un crochet ouvert vers l'arrière, comme sur les vraies grilles, et le
## numéro de la case peint juste derrière.
func _case(place: Transform3D, numero: int, materiau: Material) -> void:
	# spawn_at soulève déjà de 10 cm : on redescend au ras de la route.
	var sol := place.translated_local(Vector3(0.0, -0.1 + EPAISSEUR_PEINTURE, 0.0))
	var demi_l := CASE_LARGEUR * 0.5
	var demi_p := CASE_LONGUEUR * 0.5
	# Le trait avant, devant le nez du kart (-Z), et les deux côtés.
	_boite(sol, Vector3(0.0, 0.0, -demi_p), Vector3(CASE_LARGEUR, 0.01, TRAIT), materiau)
	_boite(sol, Vector3(-demi_l, 0.0, -demi_p * 0.35), Vector3(TRAIT, 0.01, CASE_LONGUEUR * 0.65), materiau)
	_boite(sol, Vector3(demi_l, 0.0, -demi_p * 0.35), Vector3(TRAIT, 0.01, CASE_LONGUEUR * 0.65), materiau)

	var chiffre := Label3D.new()
	chiffre.text = str(numero)
	chiffre.font_size = 128
	chiffre.pixel_size = 0.006
	chiffre.modulate = Color(1, 1, 1, 0.85)
	chiffre.outline_size = 0
	# Couché sur la route, lisible depuis la caméra qui arrive par l'arrière.
	chiffre.transform = sol * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.01, demi_p + 0.5))
	add_child(chiffre)
