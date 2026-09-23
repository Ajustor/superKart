class_name Fantome
extends RefCounted

## Le parcours d'un kart, échantillonné pendant une course : ce que rejoue le
## fantôme du contre-la-montre. Vingt échantillons par seconde suffisent — on
## interpole entre deux — et trois tours tiennent en quelques dizaines de ko.

const PAS := 0.05
const VERSION := 1
const DOSSIER := "user://fantomes"
## En tête de fichier : un fichier qui ne commence pas par là n'est pas lu.
## get_var sur n'importe quoi fait râler le moteur, et peut coûter cher.
const SIGNATURE := 0x464B5453  # « STKF »

## Temps de course du parcours enregistré, en secondes.
var temps: float = 0.0
var positions := PackedVector3Array()
## Huit nombres par échantillon : l'orientation du kart, puis celle de sa
## caisse (qui penche et glisse dans les dérapages).
var rotations := PackedFloat32Array()


func ajouter(position: Vector3, kart: Quaternion, caisse: Quaternion) -> void:
	positions.append(position)
	for q in [kart, caisse]:
		rotations.append_array(PackedFloat32Array([q.x, q.y, q.z, q.w]))


func echantillons() -> int:
	return positions.size()


## Durée couverte par les échantillons.
func duree() -> float:
	return maxf(float(positions.size() - 1), 0.0) * PAS


## Position, orientation du kart et de sa caisse au temps t, interpolées
## entre les deux échantillons qui l'encadrent.
func a_l_instant(t: float) -> Dictionary:
	if positions.is_empty():
		return {}
	var x := clampf(t / PAS, 0.0, float(positions.size() - 1))
	var i := mini(int(x), positions.size() - 1)
	var j := mini(i + 1, positions.size() - 1)
	var f := x - float(i)
	return {
		position = positions[i].lerp(positions[j], f),
		kart = _quaternion(i, 0).slerp(_quaternion(j, 0), f),
		caisse = _quaternion(i, 1).slerp(_quaternion(j, 1), f),
	}


func _quaternion(echantillon: int, lequel: int) -> Quaternion:
	var k := echantillon * 8 + lequel * 4
	return Quaternion(rotations[k], rotations[k + 1], rotations[k + 2], rotations[k + 3]).normalized()


static func chemin(cle: String) -> String:
	return "%s/%s.fantome" % [DOSSIER, cle.validate_filename()]


func sauver(cle: String) -> bool:
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	var fichier := FileAccess.open(chemin(cle), FileAccess.WRITE)
	if fichier == null:
		return false
	fichier.store_32(SIGNATURE)
	fichier.store_var({version = VERSION, temps = temps, positions = positions, rotations = rotations})
	return true


## Le fantôme enregistré sous cette clé, ou null s'il n'y en a pas — ou s'il
## est illisible : un fichier abîmé ne doit pas empêcher de courir.
static func charger(cle: String) -> Fantome:
	if not FileAccess.file_exists(chemin(cle)):
		return null
	var fichier := FileAccess.open(chemin(cle), FileAccess.READ)
	if fichier == null or fichier.get_length() < 8 or fichier.get_32() != SIGNATURE:
		return null
	var d: Variant = fichier.get_var()
	if not d is Dictionary or int(d.get("version", 0)) != VERSION:
		return null
	var f := Fantome.new()
	f.temps = float(d.get("temps", 0.0))
	f.positions = d.get("positions", PackedVector3Array())
	f.rotations = d.get("rotations", PackedFloat32Array())
	if f.rotations.size() != f.positions.size() * 8 or f.positions.is_empty():
		return null
	return f
