@tool
extends PopupPanel


enum _SourceType {
	SCENE,
	NODE,
}

enum _PasteMode {
	ADD_CHILD,
	ADD_SIBLING,
}

var undo_redo: EditorUndoRedoManager

var _source_type: _SourceType
var _source_scene: PackedScene
var _source_node: CanvasItem

var _paste_mode: _PasteMode

var _file_dialog: EditorFileDialog

@onready var _scene_check: CheckBox = %SceneCheck
@onready var _scene_select: Button = %SceneSelect
@onready var _node_check: CheckBox = %NodeCheck
@onready var _node_copy: Button = %NodeCopy
@onready var _add_child: CheckBox = %AddChild
@onready var _add_sibling: CheckBox = %AddSibling


func _ready() -> void:
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.add_filter("*.tscn, *.scn; Scenes")
	_file_dialog.file_selected.connect(_on_scene_selected)
	add_sibling.call_deferred(_file_dialog)

	_scene_check.pressed.connect(_set_source_type.bind(_SourceType.SCENE))
	_node_check.pressed.connect(_set_source_type.bind(_SourceType.NODE))
	_add_child.pressed.connect(_set_paste_mode.bind(_PasteMode.ADD_CHILD))
	_add_sibling.pressed.connect(_set_paste_mode.bind(_PasteMode.ADD_SIBLING))


func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_source_node):
			_source_node.free()


func paint_node(p_root: Node, p_selected: Node, p_position: Vector2) -> void:
	var parent: Node
	var prev_sibling: Node
	match _paste_mode:
		_PasteMode.ADD_CHILD:
			parent = p_selected
		_PasteMode.ADD_SIBLING:
			if p_selected == p_root:
				printerr("Node Brush: Cannot add a sibling to the root node.")
				return
			parent = p_selected.get_parent()
			prev_sibling = p_selected
		_:
			breakpoint

	var action: String
	var instance: CanvasItem
	match _source_type:
		_SourceType.SCENE:
			if not is_instance_valid(_source_scene):
				printerr("Node Brush: No scene selected.")
				return
			var node: Node = _source_scene.instantiate()
			if node is not CanvasItem:
				printerr("Node Brush: Scene root must be a CanvasItem.")
				node.free()
				return
			action = "Node Brush: Add child scene"
			instance = node
		_SourceType.NODE:
			if not is_instance_valid(_source_node):
				printerr("Node Brush: No node selected.")
				return
			action = "Node Brush: Add child node"
			instance = _source_node.duplicate()
		_:
			breakpoint

	undo_redo.create_action(action)

	if is_instance_valid(prev_sibling):
		undo_redo.add_do_method(prev_sibling, &"add_sibling", instance, true)
	else:
		undo_redo.add_do_method(parent, &"add_child", instance, true)
	undo_redo.add_do_reference(instance)
	undo_redo.add_do_property(instance, &"owner", p_root)
	undo_redo.add_do_property(instance, &"global_position", p_position)
	if is_instance_valid(prev_sibling):
		undo_redo.add_do_method(EditorInterface, &"edit_node", instance)

	undo_redo.add_undo_method(parent, &"remove_child", instance)
	if is_instance_valid(prev_sibling):
		undo_redo.add_undo_method(EditorInterface, &"edit_node", p_selected)

	undo_redo.commit_action()


func _set_source_type(p_source_type: _SourceType) -> void:
	_source_type = p_source_type
	_scene_select.disabled = _source_type != _SourceType.SCENE
	_node_copy.disabled = _source_type != _SourceType.NODE


func _set_paste_mode(p_paste_mode: _PasteMode) -> void:
	_paste_mode = p_paste_mode


func _on_scene_select_pressed() -> void:
	hide()
	_file_dialog.popup_file_dialog()


func _on_scene_selected(p_path: String) -> void:
	_source_scene = load(p_path)
	_scene_select.text = p_path.get_file()


func _on_node_copy_pressed() -> void:
	var selected_nodes: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.size() != 1:
		printerr("Node Brush: Select a single CanvasItem.")
		return

	var source: CanvasItem = selected_nodes[0] as CanvasItem
	if not is_instance_valid(source):
		printerr("Node Brush: Select a single CanvasItem.")
		return

	if source.get_child_count() > 0:
		printerr("Node Brush: Copying node branches is not supported yet.")
		return

	if is_instance_valid(_source_node):
		_source_node.free()
	_source_node = source.duplicate()

	_node_copy.text = _source_node.name
