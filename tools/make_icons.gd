## Renders icon.svg into the PNG sizes the web manifest needs (assets/icon/).
## Run through `tools/godot.sh icons`.
extends SceneTree

const SIZES: Array[int] = [144, 180, 512]


func _initialize() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	for size in SIZES:
		var image := Image.new()
		var err := image.load_svg_from_string(svg, size / 128.0)
		if err != OK:
			push_error("make_icons: cannot rasterise icon.svg (%s)" % error_string(err))
			quit(1)
			return
		var path := "res://assets/icon/icon_%d.png" % size
		err = image.save_png(path)
		if err != OK:
			push_error("make_icons: cannot save %s (%s)" % [path, error_string(err)])
			quit(1)
			return
		print("wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	quit(0)
