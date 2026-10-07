extends TestCase

const DAY := Gamification.DAY_S
const NOW := 1_699_920_000 + 12 * 3600  # noon UTC of 2023-11-14


func _rec(at: int, total_ms: int = 60000, level: int = 0, drill_id: String = "reaction_time") -> Dictionary:
	return {"at": at, "total_ms": total_ms, "level": level, "drill_id": drill_id}


func test_xp_per_record_and_levels() -> void:
	assert_eq(Gamification.xp_for_record(_rec(NOW, 0, -1)), 10)
	assert_eq(Gamification.xp_for_record(_rec(NOW, 90000, 0)), 12, "one full minute")
	assert_eq(Gamification.xp_for_record(_rec(NOW, 60000, 2)), 32, "elite bonus")
	assert_eq(Gamification.xp_for_record(_rec(NOW, 60 * 60000, 1)), 10 + 20 + 10, "minutes capped")
	var l := Gamification.level_for_xp(0)
	assert_eq(l["level"], 1)
	assert_eq(l["span"], 100)
	l = Gamification.level_for_xp(100)
	assert_eq(l["level"], 2)
	assert_eq(l["into"], 0)
	assert_eq(l["span"], 150)
	l = Gamification.level_for_xp(100 + 150 + 200 + 10)
	assert_eq(l["level"], 4)
	assert_eq(l["into"], 10)


func test_streak_counts_consecutive_local_days() -> void:
	var records: Array[Dictionary] = [_rec(NOW), _rec(NOW - DAY), _rec(NOW - 2 * DAY), _rec(NOW - 4 * DAY)]
	assert_eq(Gamification.streak(records, NOW, 0), 3)
	assert_eq(Gamification.streak(records, NOW + DAY, 0), 3, "yesterday still keeps the streak")
	assert_eq(Gamification.streak(records, NOW + 2 * DAY, 0), 0, "two idle days break it")
	assert_eq(Gamification.best_streak(records, 0), 3)
	assert_eq(Gamification.streak([], NOW, 0), 0)
	# 23:30 local on day d and 00:30 local on day d+1 are two days in the local zone.
	var late := NOW + 11 * 3600 + 1800  # 23:30 UTC
	var two: Array[Dictionary] = [_rec(late), _rec(late + 3600)]
	assert_eq(Gamification.streak(two, late + 3600, 0), 2)
	assert_eq(Gamification.streak(two, late + 3600, -120), 1, "in UTC-2 both runs fall on the same day")


func test_daily_goal_and_badges() -> void:
	var records: Array[Dictionary] = []
	for i in 7:
		records.append(_rec(NOW - i * DAY, 5 * 60000, 0, "reaction_time"))
		records.append(_rec(NOW - i * DAY + 60, 6 * 60000, 1, "schulte_table"))
	assert_eq(Gamification.seconds_on_day(records, NOW, 0), 11 * 60)
	assert_eq(Gamification.goal_days(records, NOW, 0, 10, 7), 7)
	assert_eq(Gamification.goal_days(records, NOW, 0, 12, 7), 0)
	var categories := {"reaction_time": "CATEGORY_REACTION", "schulte_table": "CATEGORY_ATTENTION"}
	var earned := Gamification.badges(records, NOW, 0, 10, categories, 2)
	assert_eq(earned, ["first_run", "runs_10", "first_advanced", "streak_3", "streak_7", "week_full", "all_categories", "goal_7"])
	earned = Gamification.badges(records, NOW, 0, 10, categories, 3)
	assert_false(earned.has("all_categories"))
	assert_eq(Gamification.badges([], NOW, 0, 10, categories, 2), [])
	var times := Gamification.badge_times(records, NOW, 0, 10, categories, 2)
	assert_eq(times["first_run"], NOW - 6 * DAY, "the oldest run")
	assert_eq(times["runs_10"], NOW - 2 * DAY + 60, "the tenth run in time order")
	assert_eq(times["streak_3"], NOW - 4 * DAY, "third day")
	assert_eq(times["streak_7"], NOW, "seventh day")
	assert_eq(times["all_categories"], NOW - 6 * DAY + 60, "second run")
	assert_false(times.has("first_elite"))
	assert_eq(Gamification.badge_times([], NOW, 0, 10, categories, 2), {})
