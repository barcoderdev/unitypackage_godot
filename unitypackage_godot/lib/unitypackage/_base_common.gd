#----------------------------------------

class_name BaseCommon

#----------------------------------------

const UPDATE_OWNER_FLAG: String = "update_owner"
const UPDATE_OWNER_LOG: String = "owner_log"

#----------------------------------------

const BUILT_IN_SHADER_GUID: String = "0000000000000000f000000000000000"

# TODO: Update this with more
const BUILT_IN_SHADER_IDS: Dictionary = {
	"10101" = "GUI/Text Shader",
	"10770" = "UI/Default",
	"10750" = "Unlit/Transparent",
	"10755" = "Hidden/FrameDebuggerRenderTargetDisplay",
	"46" = "Standard",
}

#----------------------------------------

var debug_log: bool = false

#----------------------------------------

func set_created_by(node: Node, by: String) -> void:
	if false:
		node.set_meta("created_by", by)

#----------------------------------------

func append_ufile_ids(node: Node, keys: PackedStringArray, source: String):
	if false:
		trace("AppendUFileIDs", "%s::%s::%s" % [
			source,
			keys,
			str(self)
		], Color.MEDIUM_PURPLE)

	var existing_keys = node.get_meta("ufile_ids", [])

	for new_key in keys:
		if existing_keys.has(new_key):
			push_error("CompDocBase::AppendUFileIDs::NotUnique::%s::in::%s" % [
				new_key,
				existing_keys
			])

	existing_keys.append_array(keys)
	node.set_meta("ufile_ids", existing_keys)

#----------------------------------------

func _append_owner_log(node: Node3D, message: String):
	var m = node.get_meta(UPDATE_OWNER_LOG, [])
	m.append(message)
	node.set_meta(UPDATE_OWNER_LOG, m)

#----------------------------------------

func choose_correct_owner(root_node: Node3D, parent: Node3D, transform: Node3D = null) -> Node3D:
	if root_node != null:
		return root_node
	if parent != null:
		return parent
	return transform

#----------------------------------------

func instantiate(root_node: Node3D, parent: Node3D, scene: PackedScene, message: String) -> Node3D:
	trace("Instantiate::%s" % message)
	var node = scene.instantiate()
#	node.set_meta("instantiated", message)
#	node.set_meta("is_instantiated", true)

	if parent != null:
		parent.add_child(node)
		node.owner = choose_correct_owner(root_node, parent)

	return node

#----------------------------------------
var _duplicate_temp_node

func duplicate(root_node: Node3D, parent: Node3D, node: Node3D, message: String) -> Node3D:
	trace("Duplicate::%s" % message)
	var dupe_node = node.duplicate(Node.DUPLICATE_USE_INSTANTIATION)
#	new_node.set_meta("duplicated", message)
#	new_node.set_meta("is_duplicated", true)

	assert(dupe_node.get_parent() == null)

	if parent != null:
		parent.add_child(dupe_node)
		dupe_node.owner = choose_correct_owner(root_node, parent)

	return dupe_node

#----------------------------------------

func for_all_nodes(node: Node, callback: Callable = Callable()):
	if callback.is_valid():
		callback.call(node)
	for child in node.get_children():
		for_all_nodes(child, callback)

#----------------------------------------

func search_for_node(node: Node, callback: Callable = Callable()):
	if callback.is_valid():
		var result = callback.call(node)
		if result != null:
			return result

	for child in node.get_children():
		var result = search_for_node(child, callback)
		if result != null:
			return result

#----------------------------------------

func to_scale(dict: Dictionary) -> Vector3:
	return Vector3(dict.x, dict.y, dict.z)

#----------------------------------------

func to_position(dict: Dictionary) -> Vector3:
	return Vector3(
		dict.x * -1.0, # Handedness Adjustment
		dict.y,
		dict.z
	)

#----------------------------------------

func to_color(dict: Dictionary) -> Color:
	return Color(dict.r, dict.g, dict.b, dict.a)

#----------------------------------------

func to_quaternion(dict: Dictionary) -> Quaternion:
	return Quaternion(
		dict.x * -1.0, # Handedness Adjustment
		dict.y,
		dict.z,
		dict.w * -1.0 # Handedness Adjustment
	)

#----------------------------------------

# Reverse of PivotFixer.CharMap
const RevCharMap = {
	"#DOT#" = ".",
	"#CLN#" = ":",
	"#AT#" = "@",
	"#PCT#" = "%",
}

func original_name(text: String) -> String:
	for k in RevCharMap:
		text = text.replace(k, RevCharMap[k])
	return text

#----------------------------------------

func node_dump(node: Node3D, message: String) -> Node3D:
	if !debug_log:
		return node

	print_rich("\n🚚🗑️🚚🗑️🚚🗑️🚚🗑️🚚🗑️🚚 [color=%s]Dumping: %s | %s[/color]" % [
		Color.HOT_PINK.to_html(),
		node.name,
		message
	])
	for_all_nodes(node, func(n):
		print("[%s] %s | Parent = [%s] %s | Owner = [%s] %s | Owner Log: %s" % [
			n.get_class(),
			n.name,
			n.get_parent().get_class() if n.get_parent() else "None",
			n.get_parent().name if n.get_parent() else "None",
			n.owner.get_class() if n.owner else "None",
			n.owner.name if n.owner else "None",
			n.get_meta("owner_log", "")
		])
	)
	return node

#----------------------------------------

func trace(_method: String, _message: String = "", _color: Color = Color.GREEN_YELLOW) -> void:
	pass

#----------------------------------------
