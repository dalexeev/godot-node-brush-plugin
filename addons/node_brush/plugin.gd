@tool
extends EditorPlugin


const _Params = preload("./params.gd")

var _button: Button
var _params: _Params


func _ready() -> void:
	_params = preload("./params.tscn").instantiate()
	_params.undo_redo = get_undo_redo()
	_params.unfocusable = true
	_params.hide()

	_button = Button.new()
	_button.theme_type_variation = &"FlatMenuButton"
	_button.icon = EditorInterface.get_editor_theme().get_icon(&"CanvasItem", &"EditorIcons")
	_button.text = "Brush"
	_button.tooltip_text = "LMB: Enable/Disable Brush Mode\n" \
			+ "RMB: Edit Brush Parameters\n\n" \
			+ "When the brush mode is active, RMB on the workspace\n" \
			+ "adds the scene/node at the clicked position."
	_button.toggle_mode = true
	_button.flat = true
	_button.gui_input.connect(_on_button_gui_input)
	_button.add_child(_params)


func _exit_tree() -> void:
	_make_visible(false)


func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_PREDELETE:
		_button.free()


func _handles(p_object: Object) -> bool:
	return p_object is Node and p_object is not Node3D


func _make_visible(p_visible: bool) -> void:
	if p_visible:
		if not is_instance_valid(_button.get_parent()):
			add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _button)
	else:
		if is_instance_valid(_button.get_parent()):
			remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _button)


func _forward_canvas_gui_input(p_event: InputEvent) -> bool:
	if not is_instance_valid(_button.get_parent()) or not _button.button_pressed:
		return false

	var mb_event: InputEventMouseButton = p_event as InputEventMouseButton
	if not is_instance_valid(mb_event) or not mb_event.pressed \
			or mb_event.button_index != MOUSE_BUTTON_RIGHT:
		return false

	var root: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(root):
		return false

	var selected_nodes: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.size() != 1:
		return false

	var viewport: Viewport = root.get_parent()
	var transform: Transform2D = viewport.global_canvas_transform.affine_inverse()
	_params.paint_node(root, selected_nodes[0], transform * mb_event.position)

	return true


func _on_button_gui_input(p_event: InputEvent) -> void:
	var mb_event: InputEventMouseButton = p_event as InputEventMouseButton
	if not is_instance_valid(mb_event):
		return

	if mb_event.pressed and mb_event.button_index == MOUSE_BUTTON_RIGHT:
		_params.position = _button.get_screen_position() + Vector2(0, _button.size.y)
		_params.popup()
		get_viewport().set_input_as_handled()
