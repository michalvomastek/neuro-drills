extends TestCase


func test_scale_size() -> void:
	assert_eq(Layout.scale_size(Vector2i(1280, 720)), Vector2i(1280, 720), "design size is unchanged")
	assert_eq(Layout.scale_size(Vector2i(2560, 1440)), Vector2i(1280, 720), "a 2x monitor shows the same layout")
	assert_eq(Layout.scale_size(Vector2i(2560, 1080)), Vector2i(1707, 720), "ultrawide keeps 720 units of height")
	assert_eq(Layout.scale_size(Vector2i(412, 915)), Vector2i(480, 1066), "phone portrait is 480 units wide")
	assert_eq(Layout.scale_size(Vector2i(1080, 2340)), Vector2i(480, 1040), "device pixels do not matter, only the aspect")
	assert_eq(Layout.scale_size(Vector2i(0, 0)), Vector2i(0, 0))
