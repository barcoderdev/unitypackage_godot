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
		var pivot = Vector3(json.pivot[0], json.pivot[1], json.pivot[2])
		# Used to set transform.origin in CompDoc::_comp_doc_mesh_filter__mesh_from_ref
		node.position = pivot * -1.0
		
		var updated_name = (json.name as String)
		for k in CharMap.keys():
			updated_name = updated_name.replace(k, CharMap[k])
		node.name = updated_name
	return OK

#----------------------------------------
