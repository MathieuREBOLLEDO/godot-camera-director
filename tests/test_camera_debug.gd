extends TestCase

## CameraDebug : menu Camera ajouté une fois à un debug menu (ici un faux,
## avec les mêmes méthodes), case des zones, arrêt, réarmement, console.


class FakeMenu:
	extends Node
	var toggles: Dictionary = {} # entrée -> [getter, setter]
	var actions: Dictionary = {} # entrée -> Callable
	var commands: Dictionary = {} # nom -> Callable

	func add_toggle(_menu: String, entry: String, getter: Callable, setter: Callable) -> void:
		toggles[entry] = [getter, setter]

	func add_action(_menu: String, entry: String, action: Callable) -> void:
		actions[entry] = action

	func add_command(command_name: String, callable: Callable, _description: String = "", _usage: String = "") -> void:
		commands[command_name] = callable


var _menu: FakeMenu
var _director: CameraDirector
var _trigger: CameraTrigger


func before_each() -> void:
	_menu = add_test_node(FakeMenu.new()) as FakeMenu
	var camera: Camera2D = add_test_node(Camera2D.new()) as Camera2D
	_director = CameraDirector.new()
	camera.add_child(_director)
	_trigger = CameraTrigger.new()
	_trigger.sequence = CameraSequence.new()
	_trigger.sequence.shots.append(CameraShot.make(Rect2(0.0, 0.0, 10.0, 10.0), 0.0, 0.0))
	add_test_node(_trigger)


func after_each() -> void:
	CameraDebug.enabled = true
	CameraDebug.zones_on = true


func test_toggle_switches_without_director() -> void:
	# Bug : sans director, la case restait cochée (test_smoke du debug menu).
	CameraDebug.register_on(_menu, _menu.get_tree())
	_director.get_parent().queue_free()
	await frames(1)
	var getter: Callable = _menu.toggles["Camera zones active"][0]
	var setter: Callable = _menu.toggles["Camera zones active"][1]
	setter.call(false)
	assert_false(getter.call(), "switched with no director")
	var camera: Camera2D = add_test_node(Camera2D.new()) as Camera2D
	var later: CameraDirector = CameraDirector.new()
	camera.add_child(later)
	assert_false(later.enabled, "a director created afterwards follows the box")


func test_registers_once() -> void:
	assert_true(CameraDebug.register_on(_menu, _menu.get_tree()))
	assert_false(CameraDebug.register_on(_menu, _menu.get_tree()), "already there")
	assert_has(_menu.toggles, "Camera zones active")
	assert_has(_menu.actions, "Stop all and go back")
	assert_has(_menu.actions, "Rearm one-shot triggers")
	assert_has(_menu.commands, "camera")


func test_nothing_without_a_debug_menu() -> void:
	assert_false(CameraDebug.register_on(null, _menu.get_tree()))
	assert_false(CameraDebug.register_on(add_test_node(Node.new()), _menu.get_tree()), "a node without add_action")
	CameraDebug.enabled = false
	assert_false(CameraDebug.register(_director), "turned off by the game")


func test_toggle_turns_zones_off() -> void:
	CameraDebug.register_on(_menu, _menu.get_tree())
	var getter: Callable = _menu.toggles["Camera zones active"][0]
	var setter: Callable = _menu.toggles["Camera zones active"][1]
	assert_true(getter.call())
	setter.call(false)
	assert_false(_director.enabled)
	assert_false(getter.call())
	setter.call(true)
	assert_true(_director.enabled)


func test_stop_and_rearm_actions() -> void:
	CameraDebug.register_on(_menu, _menu.get_tree())
	var sequence: CameraSequence = CameraSequence.new()
	sequence.shots.append(CameraShot.make(Rect2(0.0, 0.0, 50.0, 50.0), 0.0, 0.0))
	_director.play(sequence)
	(_menu.actions["Stop all and go back"] as Callable).call()
	assert_false(_director.is_playing(sequence))
	_trigger.spent = true
	(_menu.actions["Rearm one-shot triggers"] as Callable).call()
	assert_false(_trigger.spent)


func test_console_command() -> void:
	CameraDebug.register_on(_menu, _menu.get_tree())
	var command: Callable = _menu.commands["camera"]
	var state: String = command.call(PackedStringArray())
	assert_true(state.contains("2D"), "lists the director: " + state)
	assert_true(state.contains("base"))
	_trigger.spent = true
	var rearmed: String = command.call(PackedStringArray(["rearm"]))
	assert_true(rearmed.contains("rearmed"))
	assert_false(_trigger.spent)
