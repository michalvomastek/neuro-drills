## Renders a scene for a few frames and saves the main viewport as a PNG.
##
## Meant to be run through `tools/godot.sh screenshot`, which passes the user
## arguments: `<scene.tscn> <out.png> [frames]`. Lets a headless session (no
## display) look at UI layouts through software rendering under Xvfb. The
## environment variable SCREENSHOT_LOCALE (e.g. "cs") selects the UI language.
extends SceneTree

const DEFAULT_FRAMES := 3

var _frames_left: int = DEFAULT_FRAMES
var _out_path: String = ""
var _failed: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -s res://tools/screenshot.gd -- <scene.tscn> <out.png> [frames]")
		_failed = true
		return
	_out_path = args[1]
	var locale := OS.get_environment("SCREENSHOT_LOCALE")
	if not locale.is_empty():
		TranslationServer.set_locale(locale)
	if args.size() > 2:
		_frames_left = maxi(1, int(args[2]))
	var packed: PackedScene = load(args[0]) as PackedScene
	if packed == null:
		push_error("screenshot: cannot load scene %s" % args[0])
		_failed = true
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if _failed:
		quit(1)
		return true
	_frames_left -= 1
	if _frames_left > 0:
		return false
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(_out_path)
	if err != OK:
		push_error("screenshot: save_png failed with error %d" % err)
		quit(1)
		return true
	print("screenshot saved: %s (%dx%d)" % [_out_path, image.get_width(), image.get_height()])
	quit(0)
	return true
