extends SceneTree

## Rend une courbe de circuit roulable, et l'incline dans ses virages.
##
##   godot --headless --script tools/shape_track_curve.gd -- [courbe] [rayon_min] [devers_max]
##
## Par défaut : la courbe du circuit 1, un objectif de rayon de 24 m et un
## dévers plafonné à 15 degrés. Au-delà de 18, mesuré, l'IA ne boucle plus —
## le ruban dresse ses bords en obstacles quand la chaussée penche trop.
##
## Passer un dévers de 0 laisse la piste à plat. Les positions ne sont
## déplacées que là où un virage est impraticable, et jamais au-delà du plafond.
##
## Tout le calcul vit dans TrackSmoother, qui est testé ; ce fichier n'est
## qu'une enveloppe qui lit des arguments et écrit un fichier.

const DEFAUT := "res://resources/tracks/track_01_curve.tres"
const ECART_MAX := 8.0

## Rayon de braquage du kart en adhérence : max_speed / turn_rate, soit
## 22 / 1,8. En deçà, il ne négocie pas le virage, il s'encastre dedans.
const ROULABLE := 12.2


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var chemin: String = args[0] if args.size() > 0 else DEFAUT
	var rayon_min: float = float(args[1]) if args.size() > 1 else 24.0
	var devers_max: float = float(args[2]) if args.size() > 2 else 15.0

	var courbe: Curve3D = load(chemin)
	if courbe == null:
		printerr("courbe introuvable : %s" % chemin)
		quit(1)
		return

	var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(chemin))

	print("courbe : %s (%d points, %s)" \
		% [chemin, courbe.point_count,
		   "fermée" if TrackSmoother.est_fermee(courbe) else "ouverte"])

	var poses := TrackSmoother.poser_les_poignees(courbe)
	print("poignées posées sur %d points qui n'en avaient aucune" % poses)

	var bilan := TrackSmoother.elargir(courbe, rayon_min, ECART_MAX)
	print("")
	print("--- élargissement ---")
	print("  rayon le plus serré : %.1f m  ->  %.1f m   (objectif %.1f m)" \
		% [bilan["rayon_avant"], bilan["rayon_apres"], bilan["objectif"]])
	print("  passes              : %d" % bilan["passes"])
	print("  point le plus bougé : %.2f m (plafond %.1f m)" \
		% [bilan["deplacement_max"], ECART_MAX])
	# Deux critères distincts, et c'est le second qui compte vraiment. L'objectif
	# demandé sert de force de lissage : plus on vise large, plus la courbe est
	# détendue partout. Le seuil de roulabilité, lui, est une grandeur physique —
	# le rayon de braquage du kart en adhérence, max_speed / turn_rate.
	if bilan["atteint"]:
		print("  >>> objectif atteint")
	else:
		print("  >>> objectif non atteint (le plafond de déplacement a limité)")
	if float(bilan["rayon_apres"]) >= ROULABLE:
		print("  >>> ROULABLE : %.1f m, au-dessus des %.1f m de braquage du kart" 			% [bilan["rayon_apres"], ROULABLE])
	else:
		print("  >>> PAS ROULABLE : %.1f m, en deçà des %.1f m de braquage du kart." 			% [bilan["rayon_apres"], ROULABLE])
		print("      Écarte ses points de contrôle à la main, ou vise plus large.")

	print("")
	print("--- dévers ---")
	if devers_max <= 0.0:
		for i in courbe.point_count:
			courbe.set_point_tilt(i, 0.0)
		print("  demandé à plat : tous les tilts remis à zéro")
	else:
		var d := TrackSmoother.incliner(courbe, devers_max)
		print("  %d points inclinés, jusqu'à %.1f degrés (plafond %.1f)" \
			% [d["points_inclines"], d["devers_max_deg"], d["plafond_deg"]])

	var err := ResourceSaver.save(courbe, chemin)
	if err != OK:
		printerr("échec de l'écriture : %d" % err)
		quit(1)
		return
	_reposer_uid(chemin, uid)
	print("")
	print("écrite")
	quit()


## ResourceSaver oublie l'UID d'une ressource chargée par chemin, et le .tscn
## qui la référence par UID se met alors à rouspéter au chargement.
func _reposer_uid(chemin: String, uid: String) -> void:
	if uid.is_empty() or uid == "uid://<invalid>":
		return
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return
	var texte := f.get_as_text()
	f.close()
	if texte.contains("uid=") or not texte.begins_with("[gd_resource"):
		return
	var fin := texte.find("]")
	texte = texte.substr(0, fin) + " uid=\"%s\"" % uid + texte.substr(fin)
	f = FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)
	f.close()
