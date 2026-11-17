extends TestCase

## CameraSequence.to_dict() / from_dict() : suites 2D et 3D en données
## simples (pour les éditeurs de niveaux), aller-retour par JSON, données
## fausses.


func test_2d_round_trip() -> void:
	var sequence: CameraSequence = CameraSequence.new()
	sequence.takes_control = true
	sequence.priority = 2
	sequence.release_time = 0.25
	var shot: CameraShot = CameraShot.make(Rect2(10.0, 20.0, 300.0, 150.0), 0.4, 1.2)
	shot.transition = Tween.TRANS_CUBIC
	shot.easing = Tween.EASE_OUT
	sequence.shots.append(shot)
	var copy: CameraSequence = CameraSequence.from_dict(sequence.to_dict())
	assert_true(copy.takes_control)
	assert_eq(copy.priority, 2)
	assert_almost(copy.release_time, 0.25, 0.001)
	assert_eq(copy.shots.size(), 1)
	var read: CameraShot = copy.shots[0] as CameraShot
	assert_not_null(read, "a 2D shot comes back as CameraShot")
	assert_eq(read.frame, Rect2(10.0, 20.0, 300.0, 150.0))
	assert_almost(read.blend_time, 0.4, 0.001)
	assert_almost(read.hold_time, 1.2, 0.001)
	assert_eq(read.transition, Tween.TRANS_CUBIC)
	assert_eq(read.easing, Tween.EASE_OUT)


func test_3d_round_trip_through_json() -> void:
	var sequence: CameraSequence = CameraSequence.new()
	sequence.shots.append(CameraShot3D.looking(Vector3(4.0, 3.0, 2.0), Vector3.ZERO, 45.0, 0.5, 2.0))
	var text: String = JSON.stringify(sequence.to_dict())
	var copy: CameraSequence = CameraSequence.from_dict(JSON.parse_string(text))
	var read: CameraShot3D = copy.shots[0] as CameraShot3D
	var original: CameraShot3D = sequence.shots[0] as CameraShot3D
	assert_not_null(read, "a 3D shot comes back as CameraShot3D")
	assert_true(read.transform.origin.distance_to(original.transform.origin) < 0.001)
	assert_true(read.transform.basis.get_rotation_quaternion().is_equal_approx(original.transform.basis.get_rotation_quaternion()), "same orientation")
	assert_almost(read.fov, 45.0, 0.001)
	assert_almost(read.hold_time, 2.0, 0.001)


func test_bad_shots_are_skipped() -> void:
	var copy: CameraSequence = CameraSequence.from_dict({
		"shots": [{"kind": "2d"}, {"kind": "3d", "origin": [1, 2]}, "nope", {"kind": "4d"}, {"frame": [0, 0, 10, 10]}],
	})
	assert_eq(copy.shots.size(), 1, "only the valid one, kind 2d by default")
	assert_true(copy.shots[0] is CameraShot)


func test_empty_data_gives_defaults() -> void:
	var copy: CameraSequence = CameraSequence.from_dict({})
	assert_false(copy.takes_control)
	assert_eq(copy.priority, 0)
	assert_almost(copy.release_time, 0.6, 0.001)
	assert_true(copy.shots.is_empty())
