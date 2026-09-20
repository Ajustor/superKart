extends SceneTree

## Calcule les poignées manquantes d'une courbe de circuit.
##   godot --headless --script tools/smooth_track_curve.gd -- res://chemin/courbe.tres
##
## Un point de Curve3D pose sans poignée fait un angle vif. C'est invisible dans
## l'éditeur, où la courbe reste une jolie ligne brisée, mais le ruban extrudé y
## se replie : mesuré sur le circuit 1, trois points sans poignée donnaient une
## cassure de 41,8 degrés sur 2 m — un rayon de 2,7 m quand le kart tourne au
## mieux à 8,5. Le kart s'y encastrait et s'arrêtait net.
##
## Les positions ne sont jamais touchées : le tracé reste exactement celui qu'on
## a dessiné, on ne fait que lui donner des tangentes.

const DEFAUT := "res://resources/tracks/track_01_curve.tres"

## Part de la distance au voisin reportée sur la poignée. Un tiers redonne la
## tangente de Catmull-Rom, qui passe par les points sans les dépasser.
const TENSION := 1.0 / 3.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var chemin: String = args[0] if not args.is_empty() else DEFAUT

	var courbe: Curve3D = load(chemin)
	if courbe == null:
		printerr("courbe introuvable : %s" % chemin)
		quit(1)
		return

	var avant := _pire_cassure(courbe)
	var n := courbe.point_count
	# Une courbe fermée répète son premier point à la fin : on la traite comme
	# un anneau, sinon les deux extrémités restent anguleuses là où elles se
	# rejoignent — c'est-à-dire sur la ligne de départ.
	var fermee := n > 2 and courbe.get_point_position(0).distance_to(
		courbe.get_point_position(n - 1)) < 0.01

	var lissés := 0
	for i in n:
		if courbe.get_point_in(i).length() > 0.01 or courbe.get_point_out(i).length() > 0.01:
			continue
		var avant_i := _voisin(courbe, i - 1, fermee)
		var apres_i := _voisin(courbe, i + 1, fermee)
		if avant_i < 0 or apres_i < 0:
			continue
		var tangente := (courbe.get_point_position(apres_i)
			- courbe.get_point_position(avant_i)) * TENSION * 0.5
		courbe.set_point_in(i, -tangente)
		courbe.set_point_out(i, tangente)
		lissés += 1

	if fermee:
		# Le point de fermeture doit porter les mêmes poignées que le premier,
		# sans quoi la jointure fait un angle que personne ne voit venir.
		courbe.set_point_in(n - 1, courbe.get_point_in(0))
		courbe.set_point_out(n - 1, courbe.get_point_out(0))

	var apres := _pire_cassure(courbe)
	print("courbe   : %s (%d points, %s)" % [chemin, n, "fermée" if fermee else "ouverte"])
	print("lissés   : %d points qui n'avaient aucune poignée" % lissés)
	print("cassure  : %.1f deg sur 2 m  ->  %.1f deg" % [avant, apres])
	print("rayon    : %.1f m  ->  %.1f m  (le kart tourne au mieux a 8,5 m)" \
		% [_rayon(avant), _rayon(apres)])

	if lissés == 0:
		print("rien à faire, aucune poignée ne manquait")
		quit()
		return

	# ResourceSaver oublie l'UID d'une ressource chargée par chemin, et le .tscn
	# qui la référence par UID se met alors à rouspeter au chargement. On le
	# relit avant d'écrire, et on le remet.
	var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(chemin))
	var err := ResourceSaver.save(courbe, chemin)
	if err != OK:
		printerr("échec de l'écriture : %d" % err)
		quit(1)
		return
	_reposer_uid(chemin, uid)
	print("écrite")
	quit()


## Remet l'en-tête UID que ResourceSaver laisse tomber.
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


func _voisin(courbe: Curve3D, i: int, fermee: bool) -> int:
	var n := courbe.point_count
	# Sur une courbe fermée, le dernier point EST le premier : on saute par
	# dessus pour ne pas prendre une tangente nulle.
	if fermee:
		if i < 0:
			return n - 2
		if i >= n - 1:
			return 1
		return i
	return i if i >= 0 and i < n else -1


## Angle maximal entre deux sections distantes du pas du TrackBuilder.
func _pire_cassure(courbe: Curve3D) -> float:
	var c := TrackCurve.new(courbe, 9.0)
	var pire := 0.0
	var d := 0.0
	while d < c.length:
		pire = maxf(pire, rad_to_deg(c.forward_at(d).angle_to(c.forward_at(d + 2.0))))
		d += 2.0
	return pire


func _rayon(angle_deg: float) -> float:
	if angle_deg < 0.01:
		return 999.0
	return 2.0 / deg_to_rad(angle_deg)
