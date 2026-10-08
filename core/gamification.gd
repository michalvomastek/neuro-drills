## Streak, daily goal, experience points, player level and badges, all derived
## from the stored run records so nothing extra has to be persisted (except
## which badges were already shown, kept by StatsStore). Pure logic; days are
## counted in local time through [param tz_bias_min] (minutes east of UTC).
class_name Gamification
extends RefCounted

const DAY_S := 86400
## Minutes of play that count as a done day for the goal pill and the goal
## badge; independent of the training length the player picks.
const DAILY_GOAL_MINUTES := 5
const BASE_XP := 10
## Extra points per minute of play, up to [constant MAX_MINUTE_XP] minutes.
const MINUTE_XP := 2
const MAX_MINUTE_XP := 10
## Extra points per benchmark level (beginner 0, advanced 1, elite 2).
const LEVEL_XP := 10
## Points needed to pass level n: FIRST_LEVEL_XP + (n - 1) * LEVEL_STEP_XP.
const FIRST_LEVEL_XP := 100
const LEVEL_STEP_XP := 50

## Badge ids in display order; each has BADGE_<ID> and BADGE_<ID>_DESC texts.
const BADGE_ORDER: Array[String] = [
	"first_run", "runs_10", "runs_100", "runs_500",
	"first_advanced", "first_elite", "streak_3", "streak_7", "streak_30",
	"week_full", "all_categories", "goal_7",
]


## Points for one run record.
static func xp_for_record(record: Dictionary) -> int:
	var total_ms: int = record.get("total_ms", 0)
	var minutes := mini(MAX_MINUTE_XP, total_ms / 60000)
	var level: int = record.get("level", -1)
	return BASE_XP + minutes * MINUTE_XP + maxi(0, level) * LEVEL_XP


static func total_xp(records: Array[Dictionary]) -> int:
	var total := 0
	for record in records:
		total += xp_for_record(record)
	return total


## Points needed to finish [param level] (1-based).
static func xp_to_pass(level: int) -> int:
	return FIRST_LEVEL_XP + (level - 1) * LEVEL_STEP_XP


## {"level": n (from 1), "into": points earned inside the level, "span": points
## the level needs, "total": all points}.
static func level_for_xp(xp: int) -> Dictionary:
	var level := 1
	var remaining := xp
	while remaining >= xp_to_pass(level):
		remaining -= xp_to_pass(level)
		level += 1
	return {"level": level, "into": remaining, "span": xp_to_pass(level), "total": xp}


## Local day index of a unix time.
static func day_of(unix: int, tz_bias_min: int) -> int:
	return floori((unix + tz_bias_min * 60) / float(DAY_S))


## Distinct local days with at least one run, newest first.
static func played_days(records: Array[Dictionary], tz_bias_min: int) -> Array[int]:
	var seen: Dictionary = {}
	for record in records:
		var at: int = record["at"]
		seen[day_of(at, tz_bias_min)] = true
	var days: Array[int] = []
	for day: int in seen:
		days.append(day)
	days.sort()
	days.reverse()
	return days


## Consecutive days with a run ending today or yesterday (a streak survives
## until the end of the day after the last run); 0 when it is broken.
static func streak(records: Array[Dictionary], now_unix: int, tz_bias_min: int) -> int:
	var days := played_days(records, tz_bias_min)
	if days.is_empty():
		return 0
	var today := day_of(now_unix, tz_bias_min)
	if days[0] < today - 1:
		return 0
	var length := 1
	for i in range(1, days.size()):
		if days[i] == days[i - 1] - 1:
			length += 1
		else:
			break
	return length


## Longest streak ever, for badges.
static func best_streak(records: Array[Dictionary], tz_bias_min: int) -> int:
	var days := played_days(records, tz_bias_min)
	var best := 0
	var length := 0
	for i in days.size():
		length = length + 1 if i > 0 and days[i] == days[i - 1] - 1 else 1
		best = maxi(best, length)
	return best


## Seconds of play on the local day of [param now_unix].
static func seconds_on_day(records: Array[Dictionary], now_unix: int, tz_bias_min: int) -> int:
	var today := day_of(now_unix, tz_bias_min)
	var total_ms := 0
	for record in records:
		var at: int = record["at"]
		if day_of(at, tz_bias_min) == today:
			var ms: int = record.get("total_ms", 0)
			total_ms += ms
	return total_ms / 1000


## Number of the last [param window] days (today included) whose play reached
## [param goal_minutes].
static func goal_days(records: Array[Dictionary], now_unix: int, tz_bias_min: int, goal_minutes: int, window: int) -> int:
	var today := day_of(now_unix, tz_bias_min)
	var ms_per_day: Dictionary = {}
	for record in records:
		var at: int = record["at"]
		var day := day_of(at, tz_bias_min)
		if day > today - window:
			var ms: int = record.get("total_ms", 0)
			var so_far: int = ms_per_day.get(day, 0)
			ms_per_day[day] = so_far + ms
	var count := 0
	for day: int in ms_per_day:
		var ms: int = ms_per_day[day]
		if ms >= goal_minutes * 60000:
			count += 1
	return count


## Ids of the badges earned so far, in BADGE_ORDER. [param categories] maps a
## drill id to its category key, [param category_count] is how many exist.
static func badges(records: Array[Dictionary], now_unix: int, tz_bias_min: int, goal_minutes: int, categories: Dictionary, category_count: int) -> Array[String]:
	var earned: Array[String] = []
	var runs := records.size()
	var advanced := false
	var elite := false
	var played_categories: Dictionary = {}
	for record in records:
		var level: int = record.get("level", -1)
		advanced = advanced or level >= Benchmarks.Level.ADVANCED
		elite = elite or level >= Benchmarks.Level.ELITE
		var drill_id: String = record["drill_id"]
		if categories.has(drill_id):
			played_categories[categories[drill_id]] = true
	var checks := _badge_checks(runs, advanced, elite, played_categories.size(), category_count, best_streak(records, tz_bias_min), _days_in_window(records, now_unix, tz_bias_min, 7), goal_days(records, now_unix, tz_bias_min, goal_minutes, 7))
	for id in BADGE_ORDER:
		var ok: bool = checks[id]
		if ok:
			earned.append(id)
	return earned


## The rule of every badge in BADGE_ORDER from the numbers that decide them:
## runs so far, the level flags, how many categories were played out of how
## many exist, the longest streak, played days and goal days in the 7-day
## window ending today. Shared by badges() and badge_times().
static func _badge_checks(runs: int, advanced: bool, elite: bool, played_categories: int, category_count: int, best: int, week_days: int, goal_days_count: int) -> Dictionary:
	return {
		"first_run": runs >= 1,
		"runs_10": runs >= 10,
		"runs_100": runs >= 100,
		"runs_500": runs >= 500,
		"first_advanced": advanced,
		"first_elite": elite,
		"streak_3": best >= 3,
		"streak_7": best >= 7,
		"streak_30": best >= 30,
		"week_full": week_days >= 7,
		"all_categories": category_count > 0 and played_categories >= category_count,
		"goal_7": goal_days_count >= 7,
	}


## When each earned badge was earned: the time of the run after which it
## first counted, keyed by badge id. One pass over the records in time
## order keeps the running state the checks of [method badges] need (run
## count, level flags, played categories, distinct days for the streak and
## the week window, play per day for the goal window), so the profile does
## not replay the whole history per record. A window badge that lapsed and
## is not earned now is left out.
static func badge_times(records: Array[Dictionary], now_unix: int, tz_bias_min: int, goal_minutes: int, categories: Dictionary, category_count: int) -> Dictionary:
	var ordered: Array[Dictionary] = records.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var at_a: int = a["at"]
		var at_b: int = b["at"]
		return at_a < at_b)
	var times: Dictionary = {}
	var runs := 0
	var advanced := false
	var elite := false
	var played_categories: Dictionary = {}
	var days: Array[int] = []
	var streak_length := 0
	var best := 0
	var ms_per_day: Dictionary = {}
	var goal_ms := goal_minutes * 60000
	for record in ordered:
		var at: int = record["at"]
		runs += 1
		var level: int = record.get("level", -1)
		advanced = advanced or level >= Benchmarks.Level.ADVANCED
		elite = elite or level >= Benchmarks.Level.ELITE
		var drill_id: String = record["drill_id"]
		if categories.has(drill_id):
			played_categories[categories[drill_id]] = true
		var today := day_of(at, tz_bias_min)
		if days.is_empty() or days[days.size() - 1] != today:
			streak_length = streak_length + 1 if not days.is_empty() and days[days.size() - 1] == today - 1 else 1
			best = maxi(best, streak_length)
			days.append(today)
		var ms: int = record.get("total_ms", 0)
		var so_far: int = ms_per_day.get(today, 0)
		ms_per_day[today] = so_far + ms
		# Days inside the 7-day window ending today, and those that reached the goal.
		var week_days := 0
		var goal_days_count := 0
		var i := days.size() - 1
		while i >= 0 and days[i] > today - 7:
			week_days += 1
			var day_ms: int = ms_per_day[days[i]]
			if day_ms >= goal_ms:
				goal_days_count += 1
			i -= 1
		var checks := _badge_checks(runs, advanced, elite, played_categories.size(), category_count, best, week_days, goal_days_count)
		for id in BADGE_ORDER:
			var ok: bool = checks[id]
			if ok and not times.has(id):
				times[id] = at
		if times.size() == BADGE_ORDER.size():
			break
	var final := badges(records, now_unix, tz_bias_min, goal_minutes, categories, category_count)
	for id: String in times.keys():
		if not final.has(id):
			times.erase(id)
	return times


static func _days_in_window(records: Array[Dictionary], now_unix: int, tz_bias_min: int, window: int) -> int:
	var today := day_of(now_unix, tz_bias_min)
	var count := 0
	for day in played_days(records, tz_bias_min):
		if day > today - window and day <= today:
			count += 1
	return count
