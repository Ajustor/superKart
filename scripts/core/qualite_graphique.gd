class_name QualiteGraphique
extends RefCounted

## Ce que coûte l'image à la carte graphique, en trois crans. Sur téléphone,
## c'est souvent là que les images se perdent : l'écran a plus de pixels
## qu'un écran de PC, et la puce graphique dix fois moins de puissance.
##
## - HAUTE : tout, à pleine résolution ;
## - MOYENNE : sans ombres portées (elles redessinent toute la scène une
##   seconde fois, vue du soleil), à 80 % de la résolution ;
## - BASSE : sans ombres, sans lueur ni brouillard, à 60 %.
##
## AUTO choisit MOYENNE sur téléphone et tablette, HAUTE ailleurs.

enum Niveau { AUTO, HAUTE, MOYENNE, BASSE }

const ECHELLE := {Niveau.HAUTE: 1.0, Niveau.MOYENNE: 0.8, Niveau.BASSE: 0.6}


static func effectif(niveau: int) -> int:
	if niveau == Niveau.AUTO:
		return Niveau.MOYENNE if OS.has_feature("mobile") else Niveau.HAUTE
	return clampi(niveau, Niveau.HAUTE, Niveau.BASSE)


static func echelle_3d(niveau: int) -> float:
	return ECHELLE[effectif(niveau)]


## Le lissage des bords (MSAA) : net sur un ordinateur, 4× en haute et 2× en
## moyenne. Jamais sur téléphone : certaines puces mobiles plantaient avec
## (voir GaragePanel), et leur écran très dense crénelle moins.
static func anticrenelage(niveau: int) -> Viewport.MSAA:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return Viewport.MSAA_DISABLED
	match effectif(niveau):
		Niveau.HAUTE:
			return Viewport.MSAA_4X
		Niveau.MOYENNE:
			return Viewport.MSAA_2X
	return Viewport.MSAA_DISABLED


## Les ombres portées sont-elles dessinées ? Sinon, chaque kart pose au sol
## une ombre de contact (KartVisuals).
static func ombres_portees(niveau: int) -> bool:
	return effectif(niveau) == Niveau.HAUTE


## Règle les ombres, la lueur et le brouillard de tout ce qui est sous
## `racine`. Ce que le circuit a prévu est retenu la première fois : repasser
## en HAUTE rend au Prisme de Minuit sa lueur, sans en donner à qui n'en avait pas.
static func appliquer_a(racine: Node, niveau: int) -> void:
	var n := effectif(niveau)
	for lumiere in racine.find_children("*", "DirectionalLight3D", true, false):
		if not lumiere.has_meta("ombres_prevues"):
			lumiere.set_meta("ombres_prevues", lumiere.shadow_enabled)
		lumiere.shadow_enabled = lumiere.get_meta("ombres_prevues") and n == Niveau.HAUTE
		# Des ombres douces, qui portent loin : le flou adoucit les bords
		# crénelés de la carte d'ombre, et deux découpes gardent la netteté
		# près du kart.
		var soleil := lumiere as DirectionalLight3D
		soleil.shadow_blur = 1.5
		soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		soleil.directional_shadow_max_distance = 140.0
		soleil.directional_shadow_blend_splits = true
	for monde in racine.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = monde.environment
		if env == null:
			continue
		if not env.has_meta("lueur_prevue"):
			env.set_meta("lueur_prevue", env.glow_enabled)
			env.set_meta("brouillard_prevu", env.fog_enabled)
		env.glow_enabled = env.get_meta("lueur_prevue") and n != Niveau.BASSE
		env.fog_enabled = env.get_meta("brouillard_prevu") and n != Niveau.BASSE
		etalonner(env, n)
	# find_children ne connaît que les classes du moteur, pas celles des
	# scripts : on trie à la main.
	for noeud in racine.find_children("*", "Node", true, false):
		if noeud is EffetsEcran:
			# Un rectangle transparent sur tout l'écran : sur un petit
			# téléphone, autant de pixels à mélanger une fois de plus.
			(noeud as CanvasItem).visible = n != Niveau.BASSE


## L'étalonnage de l'image, comme au cinéma : un tone mapping qui garde du
## détail dans les ciels clairs et les braises, un peu plus de contraste et de
## couleur, et un halo léger autour de ce qui brille (lampes, lave, anneaux)
## sur les circuits qui n'en prévoyaient pas. En BASSE, l'image reste brute :
## chaque passe coûte sur un petit téléphone.
static func etalonner(env: Environment, niveau: int) -> void:
	var soigne := niveau != Niveau.BASSE
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if soigne else Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.05 if soigne else 1.0
	env.tonemap_white = 6.0
	# Une passe de plus sur toute l'image : en haute seulement.
	env.adjustment_enabled = niveau == Niveau.HAUTE
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	env.adjustment_brightness = 1.02
	if soigne and not env.get_meta("lueur_prevue", false) and niveau == Niveau.HAUTE:
		env.glow_enabled = true
		env.glow_intensity = 0.35
		env.glow_bloom = 0.02
		env.glow_hdr_threshold = 1.0
