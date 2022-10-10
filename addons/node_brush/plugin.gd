tool
extends EditorPlugin

const _ParamsScene = preload('params.tscn')
const _Params = preload('params.gd')

var _enabled := false
var _button := ToolButton.new()
var _button_visible := false
var _params := _ParamsScene.instance() as _Params

func _init() -> void:
	_button.text = 'Brush'
	_button.hint_tooltip = 'LMB: Enable/Disable\nRMB: Edit Params\n\n' \
			+ 'When active, RMB in the workspace adds the scene/node ' \
			+ 'at the clicked position.'
	_button.toggle_mode = true
	_button.connect('toggled', self, '_on_button_toggled')
	_button.connect('gui_input', self, '_on_button_gui_input')
	_button.add_child(_params)

func _ready() -> void:
	_params.undo_redo = get_undo_redo()
	_params.editor_interface = get_editor_interface()

func _exit_tree() -> void:
	make_visible(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_button.free()

func handles(object: Object) -> bool:
	return (object is Node) && !(object is Spatial)

func make_visible(visible: bool) -> void:
	if visible && !_button_visible:
		add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _button)
		_button_visible = true
	elif !visible && _button_visible:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _button)
		_button_visible = false

func forward_canvas_gui_input(event: InputEvent) -> bool:
	if !_enabled || !_button_visible:
		return false
	
	var e := event as InputEventMouseButton
	if !e || !e.pressed || e.button_index != BUTTON_RIGHT:
		return false
	
	var root := get_editor_interface().get_edited_scene_root()
	if !root:
		return false
	
	var nodes := get_editor_interface().get_selection().get_selected_nodes()
	if nodes.size() != 1:
		return false
	
	var viewport := root.get_parent() as Viewport
	assert(viewport)
	
	var position := viewport.global_canvas_transform.affine_inverse() \
			.xform(e.position) as Vector2
	
	_params.paint_node(root, nodes[0], position)
	
	return true

func _on_button_toggled(button_pressed: bool) -> void:
	_enabled = button_pressed

func _on_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.pressed \
			&& event.button_index == BUTTON_RIGHT:
		_params.rect_global_position = _button.rect_global_position \
				+ Vector2(0, _button.rect_size.y)
		_params.popup()
		get_viewport().set_input_as_handled()
