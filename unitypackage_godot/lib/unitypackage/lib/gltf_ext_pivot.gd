#----------------------------------------

class_name PivotFixer
extends GLTFDocumentExtension

#----------------------------------------

# Godot strips these characters but they are sometimes needed to calculate the xx-hash
const CharMap = {
	"." = "#DOT#",
	":" = "#CLN#",
	"@" = "#AT#",
	"%" = "#PCT#"
}

func _import_node(_state: GLTFState, _gltf_node: GLTFNode, json: Dictionary, node: Node) -> Error:
	if json.has("pivot"):
		# Used to set transform.origin in CompDoc::_comp_doc_mesh_filter__mesh_from_ref
		var pivot = Vector3(json.pivot[0], json.pivot[1], json.pivot[2])
		node.position = pivot * -1.0

		var scale = 0.01 / json.originalUnits
		if int(scale) != 1:
			node.scale = Vector3(1.0/scale, 1.0/scale, 1.0/scale)
			node.position *= 1.0 / scale

		# Used to calculate xxhash values
		var updated_name = (json.name as String)
		for k in CharMap.keys():
			updated_name = updated_name.replace(k, CharMap[k])
		node.name = updated_name
	return OK

#----------------------------------------
