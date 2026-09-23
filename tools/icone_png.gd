extends SceneTree

## Tire les PNG de l'icône des SVG dessinés par tools/icone.py. L'export
## Android n'accepte que des PNG, aux tailles ci-dessous.
##
##   godot --headless --path . -s tools/icone_png.gd

const DOSSIER := "res://resources/icone/"
const SORTIES := [
	["icone.svg", "icone_192.png", 192],
	["icone.svg", "icone_512.png", 512],
	["icone_premier_plan.svg", "icone_premier_plan_432.png", 432],
	["icone_fond.svg", "icone_fond_432.png", 432],
]

## Les tailles rangées dans l'icône Windows (.ico), qui contient des PNG.
const TAILLES_ICO := [16, 32, 48, 64, 128, 256]


func _initialize() -> void:
	for sortie in SORTIES:
		var source := FileAccess.get_file_as_string(DOSSIER + sortie[0])
		var image := Image.new()
		var err := image.load_svg_from_string(source, float(sortie[2]) / 512.0)
		if err != OK:
			printerr("%s : erreur %d" % [sortie[0], err])
			quit(1)
			return
		image.save_png(DOSSIER + sortie[1])
		print("%s (%d px)" % [sortie[1], image.get_width()])
	_ico(FileAccess.get_file_as_string(DOSSIER + "icone.svg"))
	quit()


## Un .ico : un en-tête, un répertoire, puis chaque taille en PNG. Windows
## l'accepte depuis Vista, et Godot en fait l'icône de la fenêtre.
func _ico(source: String) -> void:
	var images: Array[PackedByteArray] = []
	for taille: int in TAILLES_ICO:
		var image := Image.new()
		image.load_svg_from_string(source, float(taille) / 512.0)
		images.append(image.save_png_to_buffer())
	var fichier := FileAccess.open(DOSSIER + "icone.ico", FileAccess.WRITE)
	fichier.store_16(0)
	fichier.store_16(1)
	fichier.store_16(images.size())
	var decalage := 6 + 16 * images.size()
	for i in images.size():
		var taille: int = TAILLES_ICO[i]
		fichier.store_8(taille % 256)  # 256 s'écrit 0
		fichier.store_8(taille % 256)
		fichier.store_8(0)
		fichier.store_8(0)
		fichier.store_16(1)
		fichier.store_16(32)
		fichier.store_32(images[i].size())
		fichier.store_32(decalage)
		decalage += images[i].size()
	for donnees in images:
		fichier.store_buffer(donnees)
	fichier.close()
	print("icone.ico (%s px)" % ", ".join(TAILLES_ICO.map(str)))
