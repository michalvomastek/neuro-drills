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
