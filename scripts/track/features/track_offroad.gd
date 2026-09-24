@tool
class_name TrackOffroad
extends TrackFeature

## Une zone hors-piste : de l'herbe, du sable, de la boue. Le kart y roule,
## mais lentement, et comme hors du bitume.
##
## Posée sur la route, elle la rétrécit ou la coupe d'une bande à éviter.
## Posée à côté, elle crée du terrain là où il n'y avait que du vide : c'est
## ainsi qu'on dessine un raccourci — plus court que la route, plus lent à
## parcourir, et d'autant plus payant qu'on y entre avec un champignon.

enum Sol { HERBE, SABLE, BOUE, NEIGE }

@export var sol: Sol = Sol.HERBE:
	set(valeur):
		sol = valeur
		_modifie()


func _init() -> void:
	longueur = 30.0
	largeur = 12.0


func _construire(c: TrackCurve, racine: Node3D) -> void:
	var g := decalage - largeur * 0.5
	var r := decalage + largeur * 0.5
	# Deux centimètres au-dessus du bitume : là où la zone recouvre la route,
	# c'est elle qu'on voit, et la marche est trop petite pour qu'un kart la
	# sente.
	TrackFeature._poser(racine, _nappe(c, g, r, 0.02, true), _materiau(), true)
	# Un sol plat n'a rien à ombrer : au creux d'un virage en pente, sa bande
	# tordue projetait des traits d'ombre sur elle-même.
	for enfant in racine.get_children():
		if enfant is GeometryInstance3D:
			(enfant as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _materiau() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	match sol:
		Sol.HERBE:
			m.albedo_color = Color(0.3, 0.6, 0.22)
		Sol.SABLE:
			m.albedo_color = Color(0.86, 0.76, 0.5)
		Sol.BOUE:
			m.albedo_color = Color(0.4, 0.28, 0.16)
		Sol.NEIGE:
			m.albedo_color = Color(0.92, 0.95, 1.0)
	m.roughness = 1.0
	return m
