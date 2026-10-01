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


## Règle les ombres, la lueur et le brouillard de tout ce qui est sous
## `racine`. Ce que le circuit a prévu est retenu la première fois : repasser
## en HAUTE rend au Prisme de Minuit sa lueur, sans en donner à qui n'en avait pas.
static func appliquer_a(racine: Node, niveau: int) -> void:
	var n := effectif(niveau)
	for lumiere in racine.find_children("*", "DirectionalLight3D", true, false):
		if not lumiere.has_meta("ombres_prevues"):
			lumiere.set_meta("ombres_prevues", lumiere.shadow_enabled)
		lumiere.shadow_enabled = lumiere.get_meta("ombres_prevues") and n == Niveau.HAUTE
	for monde in racine.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = monde.environment
		if env == null:
			continue
		if not env.has_meta("lueur_prevue"):
			env.set_meta("lueur_prevue", env.glow_enabled)
			env.set_meta("brouillard_prevu", env.fog_enabled)
		env.glow_enabled = env.get_meta("lueur_prevue") and n != Niveau.BASSE
		env.fog_enabled = env.get_meta("brouillard_prevu") and n != Niveau.BASSE
