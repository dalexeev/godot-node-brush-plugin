tool
extends PopupDialog

var undo_redo: UndoRedo
var editor_interface: EditorInterface

var _type := 'scene' # scene | node
var _mode := 'add_child' # add_child | next_sibling

var _packed_scene: PackedScene
var _ci: CanvasItem

var _instances := {}
var _id := 0

onready var _scene_select := $'%SceneSelect' as Button
onready var _node_copy    := $'%NodeCopy'    as Button

var _file_dialog := EditorFileDialog.new()
var _file_dialog_shown := false

func _init() -> void:
	_file_dialog.mode = EditorFileDialog.MODE_OPEN_FILE
	_file_dialog.add_filter('*.tscn, *.scn; Scenes')
	_file_dialog.connect('file_selected', self, '_on_scene_selected')
	add_child(_file_dialog)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _ci:
			_ci.free()

func paint_node(root: Node, selected: Node, position: Vector2) -> void:
	var source: Object
	if _type == 'scene':
		source = _packed_scene
	elif _type == 'node':
		source = _ci
	
	if !source:
		printerr('Node Brush: No scene or node selected.')
		return
	
	var parent: Node
	var prev_sib: Node
	
	if _mode == 'add_child':
		parent = selected
	elif _mode == 'next_sibling':
		if selected == root:
			printerr('Node Brush: Cannot add a sibling to the root node.')
			return
		parent = selected.get_parent()
		prev_sib = selected
	else:
		assert(false)
	
	_id += 1
	
	undo_redo.create_action('Node Brush: Add child scene/node')
	undo_redo.add_do_method(self, '_add_instance', _id, {
		source   = source,
		root     = root,
		parent   = parent,
		prev_sib = prev_sib,
		position = position.snapped(Vector2(8, 8)),
	})
	undo_redo.add_undo_method(self, '_remove_instance', _id)
	undo_redo.commit_action()

func _add_instance(id: int, params: Dictionary) -> void:
	var source:   Object  = params.source
	var root:     Node    = params.root
	var parent:   Node    = params.parent
	var prev_sib: Node    = params.prev_sib
	var position: Vector2 = params.position
	
	if !is_instance_valid(root) || !is_instance_valid(parent):
		printerr('Node Brush: Parent node or scene root has been freed.')
		return
	
	if prev_sib && !is_instance_valid(prev_sib):
		printerr('Node Brush: The previous sibling has been freed. ' \
				+ 'The node is added to the end.')
	
	var ci: CanvasItem
	if source is PackedScene:
		ci = source.instance() as CanvasItem
	elif source is CanvasItem:
		ci = source.duplicate()
	if !is_instance_valid(ci):
		printerr('Node Brush: Scene/node is freed or invalid.')
		return
	
	_instances[id] = ci
	
	if is_instance_valid(prev_sib):
		parent.add_child_below_node(prev_sib, ci)
	else:
		parent.add_child(ci)
	ci.owner = root
	
	if ci is Node2D:
		ci.global_position = position
	elif ci is Control:
		ci.rect_global_position = position
	
	if is_instance_valid(prev_sib):
		editor_interface.edit_node(ci)

func _remove_instance(id: int) -> void:
	var ci := _instances.get(id) as CanvasItem
	if is_instance_valid(ci):
		ci.queue_free()
	_instances.erase(id)

func _on_scene_select_pressed() -> void:
	if _file_dialog_shown:
		_file_dialog.popup()
	else:
		_file_dialog.popup_centered(Vector2(1024, 640))
		_file_dialog_shown = true

func _on_node_copy_pressed() -> void:
	var nodes := editor_interface.get_selection().get_selected_nodes()
	if nodes.size() != 1:
		printerr('Node Brush: Select a single CanvasItem.')
		return
	
	var ci := nodes[0] as CanvasItem
	if !ci:
		printerr('Node Brush: Select a single CanvasItem.')
		return
	
	if _ci:
		_ci.free()
	_ci = ci.duplicate()
	
	_node_copy.text = _ci.name

func _on_node_edit_pressed() -> void:
	editor_interface.inspect_object(_ci)

func _on_scene_selected(path: String) -> void:
	_packed_scene = load(path)
	_scene_select.text = path.get_file()
