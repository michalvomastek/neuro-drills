## Short synthesised sounds, generated once at start-up (no audio assets):
## feedback tones that the settings can switch off, and stimulus tones
## (metronome tick, auditory variants) that always play. 16-bit mono WAV.
extends Node

const MIX_RATE := 22050
const ATTACK_S := 0.005
const RELEASE_S := 0.03
const GAIN := 0.45

## Name -> sequence of [frequency_hz, seconds] notes.
const SOUNDS: Dictionary = {
	"correct": [[660.0, 0.07], [880.0, 0.1]],
	"wrong": [[220.0, 0.18]],
	"done": [[523.25, 0.09], [659.25, 0.09], [783.99, 0.16]],
	"tick": [[1200.0, 0.025]],
	"tone": [[880.0, 0.15]],
	"high": [[1000.0, 0.15]],
	"low": [[400.0, 0.15]],
}
## Sounds that are part of the task, so they ignore the feedback toggle.
const STIMULUS: Array[String] = ["tick", "tone", "high", "low"]

## Feedback sounds on or off (mirrors StatsStore.sound_enabled).
var enabled: bool = true

var _players: Dictionary = {}


func _ready() -> void:
	enabled = StatsStore.sound_enabled
	for name: String in SOUNDS:
		var notes: Array = SOUNDS[name]
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = MIX_RATE
		stream.stereo = false
		stream.data = synth(notes, MIX_RATE)
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.max_polyphony = 3
		player.bus = &"Master"
		add_child(player)
		_players[name] = player


## Plays [param name]; feedback sounds only when enabled.
func play(name: String) -> void:
	if not enabled and not STIMULUS.has(name):
		return
	var player: AudioStreamPlayer = _players.get(name)
	if player != null:
		player.play()


## Renders the notes as little-endian signed 16-bit mono samples with a soft
## attack and release per note so the tones do not click.
static func synth(notes: Array, mix_rate: int) -> PackedByteArray:
	var total := 0
	for note: Array in notes:
		var seconds: float = note[1]
		total += int(seconds * mix_rate)
	var data := PackedByteArray()
	data.resize(total * 2)
	var position := 0
	for note: Array in notes:
		var frequency: float = note[0]
		var seconds: float = note[1]
		var frames := int(seconds * mix_rate)
		var attack := maxi(1, int(ATTACK_S * mix_rate))
		var release := maxi(1, int(RELEASE_S * mix_rate))
		for i in frames:
			var t := float(i) / mix_rate
			var envelope := minf(1.0, float(i) / attack) * minf(1.0, float(frames - i) / release)
			var sample := (sin(TAU * frequency * t) + 0.25 * sin(TAU * frequency * 2.0 * t)) * GAIN * envelope
			data.encode_s16(position * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
			position += 1
	return data
