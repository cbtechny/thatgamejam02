extends Node2D
## Ocean-only pickups and the same three dim-to-filled key icons as Level One.
const KEY_TEXTURES: Array[Texture2D] = [
	preload("res://Art/Textures/Resources/Key/key0.tres"),
	preload("res://Art/Textures/Resources/Key/key1.tres"),
	preload("res://Art/Textures/Resources/Key/key2.tres"),
]
const DIM := Color(0.65, 0.72, 0.85, 0.5)
const PICKUP_SCALE := 0.06

var middle_platform: int = -1
var collected: Array[bool] = [true, false, false]
var icons: Array[Sprite2D] = []
var _room: Node2D
var _hud: Control
var _time: float = 0.0
var _celebration: AudioStreamPlayer
var _icon_tweens: Array[Tween] = []
var _pickups: Array[Sprite2D] = []
var _highlights: Array[HighlightPulse] = []
var _sparkles: Array[CPUParticles2D] = []

func _ready() -> void:
	_room = get_parent() as Node2D
	# The lighthouse mask occupies z=10; pickups remain visible beyond its beam.
	z_index = 12
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	for index: int in [1, 2]:
		var pickup := Sprite2D.new()
		pickup.texture = KEY_TEXTURES[index]
		pickup.scale = Vector2.ONE * PICKUP_SCALE
		add_child(pickup)
		_pickups.append(pickup)
		_highlights.append(HighlightPulse.attach(pickup, 150.0))
		_sparkles.append(HighlightPulse.attach_sparkles(pickup, pickup.scale * _room.GUIDANCE_PIXELS_PER_UNIT))
	var layer := CanvasLayer.new()
	layer.name = "KeyHUD"
	layer.layer = 20
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	for texture: Texture2D in KEY_TEXTURES:
		var icon := Sprite2D.new()
		icon.texture = texture
		_hud.add_child(icon)
		icons.append(icon)
	get_viewport().size_changed.connect(_layout_hud)
	_celebration = AudioStreamPlayer.new()
	_celebration.name = "FragmentCelebration"
	_celebration.process_mode = Node.PROCESS_MODE_ALWAYS
	_celebration.volume_db = -22.0
	_celebration.stream = _make_celebration()
	add_child(_celebration)
	_layout_hud()
	reset()

func _layout_hud() -> void:
	var extent: Vector2 = get_viewport_rect().size
	var factor: float = minf(extent.x / 1920.0, extent.y / 1080.0)
	for index: int in range(icons.size()):
		icons[index].position = Vector2(extent.x * 0.5 + (index - 1) * 120.0 * factor, 54.0 * factor)
		icons[index].scale = Vector2.ONE * 0.22 * factor

func reset() -> void:
	for tween: Tween in _icon_tweens:
		if tween.is_valid():
			tween.kill()
	_icon_tweens.clear()
	_layout_hud()
	if is_instance_valid(_celebration):
		_celebration.stop()
	collected = [true, false, false]
	for index: int in range(icons.size()):
		icons[index].self_modulate = Color.WHITE if collected[index] else DIM
	refresh()
	for particles: CPUParticles2D in _sparkles:
		particles.restart()
	set_guidance(false, false)

func collect_on_landing(platform: int) -> void:
	var index: int = 1 if platform == middle_platform else 2 if platform == _room._platform_names.size() - 1 else -1
	if index < 0 or collected[index]:
		return
	collected[index] = true
	icons[index].self_modulate = Color.WHITE
	_celebration.play()
	var original_scale: Vector2 = icons[index].scale
	var pulse := create_tween()
	pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulse.tween_property(icons[index], "scale", original_scale * 1.4, 0.10).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(icons[index], "scale", original_scale, 0.25).set_trans(Tween.TRANS_SINE)
	_icon_tweens.append(pulse)
	refresh()

func refresh() -> void:
	# Use the gameplay clock so pause, entrance locks and Reset also govern bobbing.
	_time = _room._elapsed_time
	for index: int in [1, 2]:
		var pickup: Sprite2D = _pickups[index - 1]
		pickup.position = pickup_position(index)
		pickup.visible = not collected[index]


func set_guidance(active: bool, ready_to_launch: bool) -> void:
	var next_piece: int = 2 if collected[1] else 1
	for index: int in [1, 2]:
		var highlighted: bool = active and index == next_piece and not collected[index]
		var halo: HighlightPulse = _highlights[index - 1]
		halo.glow_color = HighlightPulse.READY_COLOR if ready_to_launch else HighlightPulse.WAITING_COLOR
		halo.set_active(highlighted)
		_sparkles[index - 1].emitting = highlighted

func pickup_position(index: int) -> Vector2:
	var platform: int = middle_platform if index == 1 else _room._platform_names.size() - 1
	if index == 2:
		# This is the actual landing target, not a decoration above the goal.
		return _room._keyhole_position(platform)
	return _room._platform_anchor(platform) + Vector2(6.0, -18.0 + sin(_time * 2.0 + index) * 1.5)

func _make_celebration() -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var data := PackedByteArray()
	var count: int = roundi(0.42 * sound.mix_rate)
	data.resize(count * 2)
	var notes: Array[float] = [523.25, 659.25, 783.99]
	for sample: int in range(count):
		var time: float = float(sample) / sound.mix_rate
		var wave: float = 0.0
		for note: int in range(notes.size()):
			var age: float = time - note * 0.055
			if age >= 0.0:
				var envelope: float = minf(age / 0.008, 1.0) * exp(-age * 10.0)
				wave += sin(TAU * notes[note] * age) * envelope / 3.0
		data.encode_s16(sample * 2, roundi(clampf(wave, -1.0, 1.0) * 26000.0))
	sound.data = data
	return sound
