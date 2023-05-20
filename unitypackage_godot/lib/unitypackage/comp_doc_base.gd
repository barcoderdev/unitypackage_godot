#----------------------------------------

class_name CompDocBase extends BaseCommon

#----------------------------------------

# Do not store anything on this
# Store it on data for persistence

var upack: UPackGD
var asset: Asset
var data: Dictionary

#----------------------------------------

var doc_debug_log_disable: bool = false

#----------------------------------------

var _file_id: String
var _ufile_id: String
var content
var type: String

#----------------------------------------

func trace(method: String, message: String = "", color: Color = Color.GREEN_YELLOW) -> void:
	if !debug_log:
		return

	var emojis = {
		"Material": "🎨",
		"Transform": "🧭",
		"MeshFilter": "🗽",
		"MeshRenderer": "🖌️",
		"AppendUFileIDs": "➕"
	}
 
	var emoji = "%s " % emojis[data.type] if emojis.has(data.type) else ""

	var text = "%s[color=%s][CompDoc] %s::%s[/color]" % [
		emoji,
		color.to_html(),
		method,
		str(self) if message == "" else message
	]
	if debug_log:
		print_rich(text)
	upack.progress.message.emit(text)

#----------------------------------------

func get_root_order():
	match self.type:
		"Transform":
			return data.content.get("m_RootOrder", 0)
		"PrefabInstance":
			var mods = data.content.m_Modification.m_Modifications
			var root_order_mod = mods.filter(func(mod): return mod.propertyPath == "m_RootOrder")
			return root_order_mod[0].value if root_order_mod.size() else 0

	return 0

#----------------------------------------

func find_node_by_ufile_id(ufile_id: String, parent: Node) -> Node:
	if not parent is Node:
		return null

	var keys = parent.get_meta("ufile_ids", [])
	if keys.has(ufile_id):
		return parent

	for child in parent.get_children():
		var node = find_node_by_ufile_id(ufile_id, child)
		if node is Node:
			return node

	return null

#----------------------------------------

func find_nodes_by_ufile_id(ufile_id: String, parent: Node) -> Array[Node]:
	var nodes: Array[Node] = []

	for_all_nodes(parent, func(node):
		var keys = node.get_meta("ufile_ids", [])
		if keys.has(ufile_id):
			nodes.push_back(node)
	)

	return nodes

#----------------------------------------

func set_ufile_ids(node: Node, keys: PackedStringArray, _reason: String):
	# push_warning("CompDocBase::SetUFileIDs::%s" % reason)
	node.set_meta("ufile_ids", keys)

#----------------------------------------

func get_comp_doc_by_ref(file_ref: Dictionary) -> CompDoc:
	return upack.get_comp_doc_by_ref({
		"fileID": file_ref.fileID,
		"guid": file_ref.get("guid", data._guid)
	})

#----------------------------------------

func is_stripped_transform():
	return (data.type == "Transform"
		&& data._extra == "stripped")

#----------------------------------------

func is_root_transform():
	return (data.type == "Transform"
		&& data._extra != "stripped"
		&& data.content.m_Father.fileID == "0")

#----------------------------------------

func is_root_node():
	if (data.type == "Transform"
		&& data._extra != "stripped"
		&& data.content.m_Father.fileID == "0"
	): return true

	if (data.type == "PrefabInstance"
		&& data.content.m_Modification.m_TransformParent.fileID == "0"
	): return true

	return false

#----------------------------------------

func is_prefab_instance():
	return data.type == "PrefabInstance"

#----------------------------------------

func is_prefab():
	return data.type == "Prefab"

#----------------------------------------

func node_to_packed_scene(node: Node3D) -> PackedScene:
	var packer = PackedScene.new()
	var result = packer.pack(node)
	if result != OK:
		push_error("CompDoc::NodeToPackedSceneFailed::%d" % result)
		return null

	return packer

#----------------------------------------

func _to_string():
	var _comp_doc_mesh_filter = data.has("_memcache_meshfilter")
	var loaded = _comp_doc_mesh_filter

	return "[CompDoc] %s | [color=#ffffff]%s[/color] | %s # %s" % [
		data.type,
		asset.pathname, #.get_file(),
		data._guid,
		data._file_id
	]

#----------------------------------------

func _init(_upack: UPackGD, _asset: Asset, _data: Dictionary):
	upack = _upack
	asset = _asset
	data = _data

	debug_log = !doc_debug_log_disable && upack.debug_log

	_file_id = data._file_id
	_ufile_id = data._ufile_id
	content = data.content
	type = data.type
	

#----------------------------------------

