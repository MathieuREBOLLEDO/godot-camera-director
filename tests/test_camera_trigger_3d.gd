extends TestCase

## CameraTrigger3D : entrée et sortie d'un corps, groupe, une seule fois,
## cinématique jouée jusqu'au bout, plans pris des CameraShotPoint3D enfants.

var _director: CameraDirector3D
var _body: CharacterBody3D


func before_each() -> void:
	var camera: Camera3D = add_test_node(Camera3D.new()) as Camera3D
	camera.make_current()
	_director = CameraDirector3D.new()
	camera.add_child(_director)
	_body = CharacterBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	shape.shape = box
	_body.add_child(shape)
	_body.add_to_group(&"hero")
	_body.position = Vector3(-50.0, -50.0, -50.0)
	add_test_node(_body)


func _trigger(cutscene: bool = false, once: bool = false, points: int = 0) -> CameraTrigger3D:
	var trigger: CameraTrigger3D = CameraTrigger3D.new()
	trigger.sequence = CameraSequence.new()
	trigger.sequence.shots.append(CameraShot3D.make(Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, 5.0)), 60.0, 0.0, 0.0 if not cutscene else 0.5))
	trigger.sequence.takes_control = cutscene
	trigger.sequence.release_time = 0.0
	trigger.once = once
	trigger.body_group = &"hero"
	trigger.director = _director
	trigger.set_box(AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0)))
	for index: int in points:
		var point: CameraShotPoint3D = CameraShotPoint3D.new()
		point.position = Vector3(float(index + 1), 0.0, 0.0)
		point.hold_time = 0.0
		trigger.add_child(point)
	add_test_node(trigger)
	return trigger


func _enter() -> void:
	_body.position = Vector3.ZERO
	await physics_frames(3)


func _leave() -> void:
	_body.position = Vector3(-50.0, -50.0, -50.0)
	await physics_frames(3)


func test_sequence_plays_inside_only() -> void:
	var trigger: CameraTrigger3D = _trigger()
	await physics_frames(2)
	assert_false(_director.is_playing(trigger.sequence))
	await _enter()
	assert_true(_director.is_playing(trigger.sequence), "entered")
	assert_true(_director.is_driving())
	await _leave()
	assert_false(_director.is_playing(trigger.sequence), "left: stopped")


func test_other_bodies_ignored() -> void:
	var trigger: CameraTrigger3D = _trigger()
	_body.remove_from_group(&"hero")
	await _enter()
	assert_false(_director.is_playing(trigger.sequence))


func test_once_plays_a_single_time() -> void:
	var trigger: CameraTrigger3D = _trigger(false, true)
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
	var trigger: CameraTrigger3D = _trigger(true)
	await _enter()
	await _leave()
	assert_true(_director.is_playing(trigger.sequence), "cutscene goes on")
	assert_true(await until(func() -> bool: return not _director.is_playing(trigger.sequence), 2.0), "then ends alone")


func test_child_shot_points_become_the_shots() -> void:
	var trigger: CameraTrigger3D = _trigger(false, false, 2)
	assert_eq(trigger.sequence.shots.size(), 2, "the points replace the shots")
	assert_almost((trigger.sequence.shots[0] as CameraShot3D).transform.origin.x, 1.0, 0.001, "in child order")
	assert_almost((trigger.sequence.shots[1] as CameraShot3D).transform.origin.x, 2.0, 0.001)
	assert_almost(trigger.sequence.release_time, 0.0, 0.001, "the sequence settings are kept")


func test_uses_current_camera_without_director_set() -> void:
	var trigger: CameraTrigger3D = _trigger()
	trigger.director = null
	await _enter()
	assert_true(_director.is_playing(trigger.sequence))
