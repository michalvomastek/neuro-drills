## Formatting helpers shared by result screens.
class_name Format
extends RefCounted


## Milliseconds as seconds with two decimals, using the locale's decimal separator.
static func seconds(ms: int) -> String:
	var text := "%.2f s" % (ms / 1000.0)
	if TranslationServer.get_locale().begins_with("cs"):
		text = text.replace(".", ",")
	return text


## Milliseconds as seconds with one decimal, for a live timer that should not flicker.
static func seconds_short(ms: int) -> String:
	var text := "%.1f s" % (ms / 1000.0)
	if TranslationServer.get_locale().begins_with("cs"):
		text = text.replace(".", ",")
	return text


## Milliseconds as a whole number with unit, for reaction times.
static func millis(ms: float) -> String:
	return "%d ms" % roundi(ms)


## Fraction 0..1 as a percentage.
static func percent(fraction: float) -> String:
	return "%d %%" % roundi(fraction * 100.0)


## Dimensionless ratio with two decimals, locale decimal separator.
static func ratio(value: float) -> String:
	var text := "%.2f" % value
	if TranslationServer.get_locale().begins_with("cs"):
		text = text.replace(".", ",")
	return text


## A calendar date in local time ([param tz_bias_min] minutes east of UTC,
## the same bias the day arithmetic of Gamification uses): "14. 2. 2026"
## in Czech, "14/2/2026" otherwise. With [param year_if_current] false the
## year is left out inside the current year ("14. 2." / "14/2", chart labels).
static func date(unix: int, tz_bias_min: int, year_if_current: bool = true) -> String:
	var local := Time.get_datetime_dict_from_unix_time(unix + tz_bias_min * 60)
	var today := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + tz_bias_min * 60)
	var year: int = local["year"]
	var month: int = local["month"]
	var day: int = local["day"]
	var current_year: int = today["year"]
	var with_year := year_if_current or year != current_year
	if TranslationServer.get_locale().begins_with("cs"):
		return "%d. %d. %d" % [day, month, year] if with_year else "%d. %d." % [day, month]
	return "%d/%d/%d" % [day, month, year] if with_year else "%d/%d" % [day, month]


## Seconds as "m:ss min" for durations of a whole training.
static func minutes_seconds(seconds: int) -> String:
	return "%d:%02d min" % [seconds / 60, seconds % 60]
