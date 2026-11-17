extends TestCase

## CameraDirector3D : le rig prend la main, va aux plans, rend la caméra du
## jeu (même si elle a bougé), refuse les plans 2D ; CameraShotPoint3D.

var _camera: Camera3D
var _director: CameraDirector3D


func before_each() -> void:
	_camera = add_test_node(Camera3D.new()) as Camera3D
	_camera.position = Vector3(0.0, 1.0, 5.0)
	_camera.fov = 70.0
	_camera.make_current()
	_director = CameraDirector3D.new()
	_camera.add_child(_director)


func _sequence(shots: Array[CameraShot3D], cutscene: bool = false, release: float = 0.0) -> CameraSequence:
	var sequence: CameraSequence = CameraSequence.new()
	for shot: CameraShot3D in shots:
		sequence.shots.append(shot)
	sequence.takes_control = cutscene
	sequence.release_time = release
	return sequence


func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.01


func _current() -> Camera3D:
	return _camera.get_viewport().get_camera_3d()


func test_rig_takes_over_and_reaches_shot() -> void:
	var shot: CameraShot3D = CameraShot3D.looking(Vector3(10.0, 2.0, 0.0), Vector3.ZERO, 50.0, 0.0, 0.0)
	assert_true(_director.play(_sequence([shot])))
	assert_true(_director.is_driving())
	assert_eq(_current(), _director.rig, "the rig is the current camera")
	assert_true(_near(_director.rig.global_position, Vector3(10.0, 2.0, 0.0)))
	assert_almost(_director.rig.fov, 50.0, 0.01)
	assert_true(_near(_camera.global_position, Vector3(0.0, 1.0, 5.0)), "the game camera is never moved")


func test_rig_looks_at_target() -> void:
	var shot: CameraShot3D = CameraShot3D.looking(Vector3(0.0, 0.0, 10.0), Vector3.ZERO, 60.0, 0.0, 0.0)
	_director.play(_sequence([shot]))
	var forward: Vector3 = -_director.rig.global_basis.z
	assert_true(_near(forward, Vector3(0.0, 0.0, -1.0)), "faces the target")


func test_gives_back_to_game_camera() -> void:
	var sequence: CameraSequence = _sequence([CameraShot3D.make(Transform3D(Basis.IDENTITY, Vector3(4.0, 0.0, 0.0)), 60.0, 0.0, 0.0)])
	_director.play(sequence)
	_director.stop(sequence)
	assert_false(_director.is_driving())
	assert_eq(_current(), _camera, "game camera current again")
	assert_true(_near(_director.rig.global_position, _camera.global_position), "rig ended on the game camera")


func test_release_follows_moving_camera() -> void:
	var sequence: CameraSequence = _sequence([CameraShot3D.make(Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, 0.0)), 60.0, 0.0, 0.0)], false, 0.3)
	_director.play(sequence)
	_director.stop(sequence)
	assert_true(_director.is_driving(), "still driving while going back")
	_camera.position = Vector3(-3.0, 1.0, 5.0)
	assert_true(await until(func() -> bool: return not _director.is_driving(), 2.0), "gives back after the release")
	assert_eq(_current(), _camera)
	assert_true(_near(_director.rig.global_position, Vector3(-3.0, 1.0, 5.0)), "joined the camera where it moved")
	assert_almost(_director.rig.fov, 70.0, 0.01)


func test_blend_starts_from_current_camera() -> void:
	var target: Vector3 = Vector3(6.0, 1.0, 5.0)
	_director.play(_sequence([CameraShot3D.make(Transform3D(Basis.IDENTITY, target), 70.0, 0.3, 0.0)]))
	assert_true(_near(_director.rig.global_position, _camera.global_position), "starts on the game camera")
	assert_true(await until(func() -> bool: return _near(_director.rig.global_position, target), 1.0), "arrives after the blend")


func test_refuses_2d_shots() -> void:
	var sequence: CameraSequence = CameraSequence.new()
	sequence.shots.append(CameraShot.make(Rect2(0.0, 0.0, 10.0, 10.0), 0.0, 0.0))
	assert_false(_director.play(sequence))
	assert_false(_director.is_driving())


func test_finds_director_even_while_rig_is_current() -> void:
	assert_eq(CameraDirector3D.of(_camera), _director)
	assert_eq(CameraDirector3D.current(_camera.get_viewport()), _director)
	_director.play(_sequence([CameraShot3D.make(Transform3D.IDENTITY, 60.0, 0.0, 0.0)]))
	assert_eq(CameraDirector3D.current(_camera.get_viewport()), _director, "through the rig")
	assert_null(CameraDirector3D.of(null))


func test_cutscene_and_stop_all() -> void:
	var changes: Array[bool] = []
	_director.control_changed.connect(func(taken: bool) -> void: changes.append(taken))
	_director.play(_sequence([CameraShot3D.make(Transform3D.IDENTITY, 60.0, 0.0, 5.0)], true, 2.0))
	assert_true(_director.is_control_taken())
	_director.stop_all()
	assert_false(_director.is_driving())
	assert_eq(_current(), _camera)
	assert_eq(changes, [true, false] as Array[bool])
	assert_eq(_director.describe(), "base")


func test_shots_advance_and_end() -> void:
	var shots: Array[int] = []
	_director.shot_changed.connect(func(_s: CameraSequence, index: int) -> void: shots.append(index))
	var sequence: CameraSequence = _sequence([
		CameraShot3D.make(Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0)), 60.0, 0.0, 0.1),
		CameraShot3D.make(Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, 0.0)), 60.0, 0.0, 0.1),
	])
	_director.play(sequence)
	assert_true(await until(func() -> bool: return not _director.is_playing(sequence), 2.0))
	assert_eq(shots, [0, 1] as Array[int])
	assert_eq(_current(), _camera)


func test_live_shot_follows_its_camera() -> void:
	var other: Camera3D = add_test_node(Camera3D.new()) as Camera3D
	other.position = Vector3(2.0, 2.0, 2.0)
	other.fov = 90.0
	_camera.make_current()
	_director.play(_sequence([CameraShot3D.following(other, 0.0, 0.0)]))
	assert_true(_near(_director.rig.global_position, Vector3(2.0, 2.0, 2.0)))
	other.position = Vector3(5.0, 2.0, 2.0)
	other.fov = 110.0
	other.h_offset = 0.1
	await frames(2)
	assert_true(_near(_director.rig.global_position, Vector3(5.0, 2.0, 2.0)), "moves with it")
	assert_almost(_director.rig.fov, 110.0, 0.01, "its fov animation is kept")
	assert_almost(_director.rig.h_offset, 0.1, 0.001, "and its shake")


func test_live_shot_saves_its_pose_only() -> void:
	var other: Camera3D = add_test_node(Camera3D.new()) as Camera3D
	other.position = Vector3(1.0, 2.0, 3.0)
	var shot: CameraShot3D = CameraShot3D.following(other, 0.0, 0.0)
	var copy: CameraShot3D = CameraShotBase.from_dict(shot.to_dict()) as CameraShot3D
	assert_null(copy.source, "a node is not saved")
	assert_true(_near(copy.transform.origin, Vector3(1.0, 2.0, 3.0)))
	other.queue_free()
	await frames(1)
	assert_null(shot.live_source(), "freed camera: no longer live")


func test_shot_point_gives_its_pose_and_never_becomes_current() -> void:
	var point: CameraShotPoint3D = CameraShotPoint3D.new()
	point.position = Vector3(3.0, 4.0, 5.0)
	point.fov = 40.0
	point.blend_time = 0.2
	point.hold_time = 0.5
	add_test_node(point)
	assert_eq(_current(), _camera, "the game camera stays current")
	var shot: CameraShot3D = point.to_shot()
	assert_true(_near(shot.transform.origin, Vector3(3.0, 4.0, 5.0)))
	assert_almost(shot.fov, 40.0, 0.01)
	assert_almost(shot.blend_time, 0.2, 0.001)
	assert_almost(shot.hold_time, 0.5, 0.001)
