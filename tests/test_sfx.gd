extends TestCase


func test_synth_length_and_silence_at_edges() -> void:
	var data := Sfx.synth([[440.0, 0.1], [880.0, 0.05]], 10000)
	assert_eq(data.size(), (1000 + 500) * 2, "two bytes per frame")
	assert_eq(data.decode_s16(0), 0, "attack starts from silence")
	assert_true(absi(data.decode_s16(data.size() - 2)) < 100, "release ends near silence")
	var peak := 0
	for i in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(i)))
	assert_true(peak > 8000 and peak <= 32767, "audible but not clipping: %d" % peak)


func test_every_sound_has_notes() -> void:
	for name: String in Sfx.SOUNDS:
		var notes: Array = Sfx.SOUNDS[name]
		assert_false(notes.is_empty(), name)
	for name in Sfx.STIMULUS:
		assert_true(Sfx.SOUNDS.has(name), name)
