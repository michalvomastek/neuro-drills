extends TestCase


func test_notes_roundtrip_and_text() -> void:
	var log := FeedbackLog.new()
	log.add(FeedbackLog.make_note("  Red flash too weak \n", {"drill": "Schulte", "variant": "7×7", "result": "Time 85 s", "platform": "Web", "screen": "1280×720"}, 1000))
	log.add(FeedbackLog.make_note("Second, newer", {"drill": "General"}, 2000))
	assert_eq(log.notes[0]["text"], "Red flash too weak")
	var text := log.to_text()
	assert_true(text.begins_with("## "), text)
	assert_true(text.find("Second, newer") < text.find("Red flash too weak"), "newest first")
	assert_true(text.contains("Schulte (7×7)"))
	assert_true(text.contains("Time 85 s"))
	assert_true(text.contains("Web, 1280×720"))
	var loaded := FeedbackLog.parse(log.serialize() + "{\"no\": \"id\"}\n")
	assert_eq(loaded.notes.size(), 2)
	assert_eq(loaded.notes[0]["at"], 1000)
	var first_id: String = loaded.notes[0]["id"]
	assert_true(loaded.remove(first_id))
	assert_false(loaded.remove(first_id))
	assert_eq(loaded.notes.size(), 1)
	assert_true(FeedbackLog.new().to_text().is_empty())


func test_issue_url() -> void:
	var note := FeedbackLog.make_note("Flash too weak", {"drill": "Schulte", "variant": "7×7", "platform": "Web"}, 1700000000)
	var url := FeedbackLog.issue_url(note)
	assert_true(url.begins_with("https://github.com/" + FeedbackLog.ISSUE_REPO + "/issues/new?labels=feedback&title="), url)
	assert_true(url.contains("%5Bfeedback%5D%20Schulte%202023-11-14"), url)
	assert_true(url.contains("Flash%20too%20weak"), url)
	assert_false(url.contains(" "), "spaces are encoded")
