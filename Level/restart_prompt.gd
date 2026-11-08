extends Node
## A quiet failure-only cue; never changes button text, bounds or input handling.
const GOLD := Color("ffda88")
const PULSE_SPEED: float = 2.4
const BEEP_VOLUME_DB: float = -36.0
const FAILURE_HINT := "Missed. Press R to restart."
var active: bool = false
var _button: Button
var _keycap: Control
var _styles: Dictionary = {}
var _phase: float = 0.0
var _beep_remaining: float = 0.0
var _metric_scale: float = 1.0
var _audio: AudioStreamPlayer

static func attach(button: Button, metric_scale: float = 1.0) -> Node:
	var cue: Node = load("res://Level/restart_prompt.gd").new()
	cue.name = "RestartPrompt"
	cue._metric_scale = metric_scale
	button.add_child(cue)
	return cue

func _ready() -> void:
	_button = get_parent() as Button
	_keycap = _button.get_node_or_null("KeycapVisual")
	_audio = AudioStreamPlayer.new()
	_audio.name = "QuietRestartBeep"
	_audio.volume_db = BEEP_VOLUME_DB
	_audio.stream = _make_beep()
	add_child(_audio)
	set_process(false)

func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	_phase = 0.0
	_beep_remaining = 0.0
	if active and _keycap == null:
		for state: String in ["normal", "hover", "pressed"]:
			var style: StyleBoxFlat = _button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			_styles[state] = style
			_button.add_theme_stylebox_override(state, style)
	elif not active:
		_audio.stop()
		if _keycap != null:
			_keycap.set_restart_glow(Color.TRANSPARENT, Color.TRANSPARENT, 0)
		for state: String in _styles:
			_button.remove_theme_stylebox_override(state)
		_styles.clear()
	set_process(active)

func _process(delta: float) -> void:
	if _button.disabled or not _button.is_visible_in_tree():
		return
	_phase += delta * PULSE_SPEED
	var pulse: float = 0.5 + 0.5 * sin(_phase)
	var border: Color = GOLD.darkened(0.25 * (1.0 - pulse))
	var shadow := Color(GOLD, 0.16 + 0.34 * pulse)
	var radius: int = roundi((4.0 + 8.0 * pulse) * _metric_scale)
	if _keycap != null:
		_keycap.set_restart_glow(border, shadow, radius)
	for style: StyleBoxFlat in _styles.values():
		style.border_color = border
		style.shadow_color = shadow
		style.shadow_size = radius
	_beep_remaining -= delta
	if _beep_remaining <= 0.0:
		_audio.play()
		_beep_remaining = TAU / PULSE_SPEED

func _make_beep() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count: int = roundi(0.055 * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for sample: int in range(count):
		var envelope: float = pow(sin(PI * float(sample) / float(count)), 2.0)
		var wave: float = sin(TAU * 520.0 * float(sample) / float(stream.mix_rate))
		data.encode_s16(sample * 2, roundi(wave * envelope * 16000.0))
	stream.data = data
	return stream
