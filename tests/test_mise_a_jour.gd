extends GutTest

## La mise à jour intégrée : comparer les versions, lire le manifeste de la
## page de téléchargement, vérifier le fichier reçu. Le réseau et
## l'installation elle-même (Windows, Android) ne se testent pas ici.

const MiseAJourScript := preload("res://scripts/core/mise_a_jour.gd")

var maj: Node


func before_each() -> void:
	# Hors de l'arbre : _ready ne part pas chercher le réseau.
	maj = MiseAJourScript.new()


func after_each() -> void:
	maj.free()


func test_les_versions_se_comparent_en_nombres() -> void:
	assert_eq(MiseAJourScript.comparer_versions("1.10", "1.9"), 1, "1.10 vient après 1.9")
	assert_eq(MiseAJourScript.comparer_versions("1.2", "1.2.0"), 0)
	assert_eq(MiseAJourScript.comparer_versions("v1.3", "1.2.57"), 1, "le v du tag ne compte pas")
	assert_eq(MiseAJourScript.comparer_versions("1.1.57", "1.2"), -1)
	assert_eq(MiseAJourScript.comparer_versions("2-beta", "1.9"), 1)


func test_une_version_de_developpement_ne_se_compare_pas() -> void:
	assert_false(MiseAJourScript.version_comparable("dev"))
	assert_false(MiseAJourScript.version_comparable(""))
	assert_true(MiseAJourScript.version_comparable("1.2"))
	assert_true(MiseAJourScript.version_comparable("v1.2"))


func test_un_manifeste_plus_recent_propose_la_mise_a_jour() -> void:
	ProjectSettings.set_setting("application/config/version", "1.2")
	maj.lire_manifeste({version = "1.3", notes = "- nouveaux circuits"})
	assert_eq(maj.etat, MiseAJourScript.Etat.DISPONIBLE)
	assert_eq(maj.version_disponible, "1.3")
	assert_true(maj.mise_a_jour_connue())
	ProjectSettings.set_setting("application/config/version", "dev")


func test_un_manifeste_egal_ou_plus_ancien_dit_a_jour() -> void:
	ProjectSettings.set_setting("application/config/version", "1.3")
	maj.lire_manifeste({version = "1.3"})
	assert_eq(maj.etat, MiseAJourScript.Etat.A_JOUR)
	maj.lire_manifeste({version = "1.2.80"})
	assert_eq(maj.etat, MiseAJourScript.Etat.A_JOUR)
	assert_false(maj.mise_a_jour_connue())
	ProjectSettings.set_setting("application/config/version", "dev")


func test_un_manifeste_sans_version_ne_propose_rien() -> void:
	ProjectSettings.set_setting("application/config/version", "1.2")
	maj.lire_manifeste({})
	assert_eq(maj.etat, MiseAJourScript.Etat.A_JOUR)
	ProjectSettings.set_setting("application/config/version", "dev")


func test_la_version_de_dev_ne_verifie_rien() -> void:
	add_child(maj)
	maj.verifier()
	assert_eq(maj.etat, MiseAJourScript.Etat.INACTIF, "pas de requête depuis l'éditeur ou les tests")
	remove_child(maj)


func test_les_fichiers_sont_relatifs_au_manifeste() -> void:
	maj._url_manifeste = "https://exemple.org/jeu/telecharger/version.json"
	assert_eq(maj.url_de("SuperKart.apk"), "https://exemple.org/jeu/telecharger/SuperKart.apk")
	assert_eq(maj.url_de("https://ailleurs.org/a.zip"), "https://ailleurs.org/a.zip")
	assert_eq(maj.url_page(), "https://exemple.org/jeu/")


func test_l_empreinte_du_fichier_est_verifiee() -> void:
	var chemin := "user://test_mise_a_jour.bin"
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string("SuperKart")
	f.close()
	var bonne := FileAccess.get_sha256(chemin)
	assert_true(MiseAJourScript.fichier_valide(chemin, bonne))
	assert_true(MiseAJourScript.fichier_valide(chemin, bonne.to_upper()))
	assert_false(MiseAJourScript.fichier_valide(chemin, "00" + bonne.substr(2)))
	assert_true(MiseAJourScript.fichier_valide(chemin, ""), "sans empreinte, un fichier non vide suffit")
	assert_false(MiseAJourScript.fichier_valide("user://absent.bin", ""))
	DirAccess.remove_absolute(chemin)


func test_le_script_windows_attend_le_jeu_puis_remplace_et_relance() -> void:
	var script: String = MiseAJourScript.script_windows(4242, "SuperKart.exe", "SuperKart.pck")
	assert_string_contains(script, "PID eq 4242")
	assert_string_contains(script, "move /Y \"SuperKart.pck.maj\" \"SuperKart.pck\"")
	assert_string_contains(script, "move /Y \"SuperKart.exe.maj\" \"SuperKart.exe\"")
	assert_string_contains(script, "start \"\" \"SuperKart.exe\"")
	assert_true(script.find("PID eq") < script.find("move /Y"), "attendre avant de remplacer")
	assert_true(script.find("move /Y") < script.find("start"), "remplacer avant de relancer")
	assert_string_contains(script, "\r\n", "fins de ligne Windows")
