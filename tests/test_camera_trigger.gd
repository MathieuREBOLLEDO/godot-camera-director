extends TestCase

## CameraTrigger : entrée et sortie d'un corps, groupe, une seule fois,
## cinématique jouée jusqu'au bout.

var _director: CameraDirector
var _body: CharacterBody2D


func before_each() -> void:
	var camera: Camera2D = add_test_node(Camera2D.new()) as Camera2D
	_director = CameraDirector.new()
	camera.add_child(_director)
	_body = CharacterBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(10.0, 10.0)
	shape.shape = rect
	_body.add_child(shape)
	_body.add_to_group(&"hero")
	_body.position = Vector2(-500.0, -500.0)
	add_test_node(_body)


func _trigger(cutscene: bool = false, once: bool = false) -> CameraTrigger:
	var trigger: CameraTrigger = CameraTrigger.new()
	trigger.sequence = CameraSequence.new()
	trigger.sequence.shots.append(CameraShot.make(Rect2(0.0, 0.0, 100.0, 100.0), 0.0, 0.0 if not cutscene else 0.5))
	trigger.sequence.takes_control = cutscene
	trigger.sequence.release_time = 0.0
	trigger.once = once
	trigger.body_group = &"hero"
	trigger.director = _director
	trigger.set_rect(Rect2(0.0, 0.0, 100.0, 100.0))
	add_test_node(trigger)
	return trigger


func _enter() -> void:
	_body.position = Vector2(50.0, 50.0)
	await physics_frames(3)


func _leave() -> void:
	_body.position = Vector2(-500.0, -500.0)
	await physics_frames(3)


func test_sequence_plays_inside_only() -> void:
	var trigger: CameraTrigger = _trigger()
	await physics_frames(2)
	assert_false(_director.is_playing(trigger.sequence))
	await _enter()
	assert_true(_director.is_playing(trigger.sequence), "entered")
	await _leave()
	assert_false(_director.is_playing(trigger.sequence), "left: stopped")


func test_other_bodies_ignored() -> void:
	var trigger: CameraTrigger = _trigger()
	_body.remove_from_group(&"hero")
	await _enter()
	assert_false(_director.is_playing(trigger.sequence))


func test_once_plays_a_single_time() -> void:
	var trigger: CameraTrigger = _trigger(false, true)
	await _enter()
	assert_true(trigger.spent)
	await _leave()
	await _enter()
	assert_false(_director.is_playing(trigger.sequence), "spent")
	await _leave()
	trigger.rearm()
	await _enter()
	assert_true(_director.is_playing(trigger.sequence), "rearmed")


func test_cutscene_survives_leaving() -> void:
	var trigger: CameraTrigger = _trigger(true)
	await _enter()
	await _leave()
	assert_true(_director.is_playing(trigger.sequence), "cutscene goes on")
	assert_true(await until(func() -> bool: return not _director.is_playing(trigger.sequence), 2.0), "then ends alone")


func test_uses_current_camera_without_director_set() -> void:
	var trigger: CameraTrigger = _trigger()
	trigger.director = null
	_director.camera.make_current()
	await _enter()
	assert_true(_director.is_playing(trigger.sequence))
