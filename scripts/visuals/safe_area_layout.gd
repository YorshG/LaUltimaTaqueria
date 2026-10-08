extends Control
## App-only presentation. Screen pixels -> local canvas; no session state ownership.

var effective_safe_rect := Rect2()
var units_per_point := 1.0
var metric_source := "desktop"
var _test_metrics: Dictionary = {}
var _poll := 0.0
var _last_signature: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().session_replaced.connect(func(_generation): refresh_layout(true))
	get_parent().resized.connect(func(): refresh_layout(true))
	get_viewport().size_changed.connect(func(): refresh_layout(true))
	get_parent().get_node("%RestartButton").minimum_size_changed.connect(func(): call_deferred("refresh_layout", true))
	call_deferred("refresh_layout", true)

func _process(delta: float) -> void:
	_poll += delta
	if _poll >= 0.25:
		_poll = 0.0
		refresh_layout()

func set_test_metrics(safe_pixels: Rect2, canvas_to_screen: Transform2D, pixel_scale: float) -> void:
	_test_metrics = {"safe": safe_pixels, "transform": canvas_to_screen, "scale": pixel_scale}
	refresh_layout(true)

static func project_safe_rect(screen_rect: Rect2, canvas_to_screen: Transform2D, bounds: Rect2) -> Rect2:
	if absf(canvas_to_screen.determinant()) < 0.00001: return bounds
	var mapped := canvas_to_screen.affine_inverse() * screen_rect
	var clipped := mapped.intersection(bounds)
	return clipped if clipped.has_area() else bounds

func refresh_layout(force: bool = false) -> void:
	var app := get_parent() as Control
	if not app.is_node_ready(): return
	var bounds := Rect2(Vector2.ZERO, app.size)
	var transform := app.get_global_transform_with_canvas()
	if get_viewport() is Window:
		transform = get_viewport().get_screen_transform() * transform
	var screen_safe := transform * bounds
	var pixel_scale := 1.0
	metric_source = "desktop/full viewport"
	if not _test_metrics.is_empty():
		transform = _test_metrics.transform
		screen_safe = _test_metrics.safe
		pixel_scale = _test_metrics.scale
		metric_source = "synthetic"
	elif DisplayServer.get_name() != "headless" and get_viewport() is Window:
		screen_safe = Rect2(DisplayServer.get_display_safe_area())
		pixel_scale = maxf(1, DisplayServer.screen_get_scale())
		metric_source = DisplayServer.get_name()
	effective_safe_rect = project_safe_rect(screen_safe, transform, bounds)
	units_per_point = pixel_scale / maxf(0.001, minf(transform.x.length(), transform.y.length()))
	var signature := [effective_safe_rect, units_per_point]
	if not force and signature == _last_signature: return
	_last_signature = signature
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = effective_safe_rect.position
	size = effective_safe_rect.size
	var session_host := app.get_node("%SessionHost") as Control
	session_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var button := app.get_node("%RestartButton") as Button
	var height := maxf(132, 44 * units_per_point)
	button.custom_minimum_size = Vector2(maxf(250, 80 * units_per_point), height)
	var button_size := button.get_combined_minimum_size()
	var top_bar := get_node("TopBar") as Control
	top_bar.position = Vector2(maxf(0, size.x - button_size.x - 24), 8)
	top_bar.size = button_size
	var main = app.get_session()
	if is_instance_valid(main):
		main.set_meta("ui_units_per_point", units_per_point)
		main.set_meta("restart_reserved_width", button_size.x + 24)
		main.set_meta("restart_reserved_height", button_size.y)
		main.get_node("Margin").add_theme_constant_override("margin_top", 8)
		main.get_node("Margin").add_theme_constant_override("margin_bottom", 8)
		main.get_node("Margin/Content").queue_layout()
	var center := app.confirmation.get_node("Center") as Control
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	center.position = effective_safe_rect.position
	center.size = effective_safe_rect.size
	for control in [app.confirm_button, app.cancel_button]:
		control.custom_minimum_size.y = height
