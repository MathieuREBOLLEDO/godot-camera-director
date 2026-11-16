@tool
extends EditorPlugin

## Camera Director : rien à déclarer (pas d'autoload), les classes suffisent.
## Dans un jeu sans test runner (addons/test_runner), les tests de l'addon
## sont cachés à Godot (tests/.gdignore, ignoré par git) : sans lui, leur
## classe TestCase manque et l'éditeur affiche une erreur par fichier.

const TESTS_IGNORE: String = "res://addons/camera_director/tests/.gdignore"
const TEST_RUNNER: String = "res://addons/test_runner/test_case.gd"


func _enter_tree() -> void:
	if FileAccess.file_exists(TEST_RUNNER) or FileAccess.file_exists(TESTS_IGNORE):
		return
	var file: FileAccess = FileAccess.open(TESTS_IGNORE, FileAccess.WRITE)
	if file != null:
		file.close()
		get_editor_interface().get_resource_filesystem().scan()
