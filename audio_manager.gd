extends Node

const SAMPLE_RATE := 22050
const POOL_SIZE := 6

var players: Array[AudioStreamPlayer] = []
var generators: Array[AudioStreamGenerator] = []
var index := 0

func _ready() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = SAMPLE_RATE
		generator.buffer_length = 0.32
		player.stream = generator
		add_child(player)
		players.append(player)
		generators.append(generator)

func play_sound(kind: String) -> void:
	var player := players[index]
	index = (index + 1) % POOL_SIZE
	if player.playing:
		player.stop()
	player.play()
	var playback := player.get_stream_playback()
	if playback == null:
		return
	var settings := _sound_settings(kind)
	var frequency: float = settings[0]
	var duration: float = settings[1]
	var volume: float = settings[2]
	var sweep: float = settings[3]
	var waveform: int = int(settings[4])
	var frames := PackedVector2Array()
	var count := int(duration * SAMPLE_RATE)
	frames.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var attack: float = min(1.0, t / 0.008)
		var release: float = min(1.0, (duration - t) / 0.035)
		var envelope: float = max(0.0, min(attack, release))
		var f: float = max(35.0, frequency + sweep * (t / duration))
		var phase: float = TAU * f * t
		var sample: float = 0.0
		match waveform:
			1:
				sample = 1.0 if sin(phase) >= 0.0 else -1.0
			2:
				sample = 2.0 * (t * f - floor(t * f + 0.5))
			_:
				sample = sin(phase)
		sample *= envelope * volume
		frames[i] = Vector2(sample, sample)
	playback.push_buffer(frames)

func _sound_settings(kind: String) -> Array:
	match kind:
		"shoot":
			return [760.0, 0.075, 0.18, -210.0, 2]
		"hit":
			return [180.0, 0.09, 0.24, 90.0, 1]
		"hurt":
			return [120.0, 0.18, 0.28, -40.0, 1]
		"pickup":
			return [520.0, 0.18, 0.2, 420.0, 0]
		"dash":
			return [260.0, 0.14, 0.2, 620.0, 2]
		"explode":
			return [90.0, 0.32, 0.3, -60.0, 1]
		"stage":
			return [320.0, 0.38, 0.16, 520.0, 0]
		_:
			return [440.0, 0.12, 0.12, 0.0, 0]
