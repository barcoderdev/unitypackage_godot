#----------------------------------------

class_name PivotFixer
extends GLTFDocumentExtension

#----------------------------------------

func _import_node(_state: GLTFState, _gltf_node: GLTFNode, json: Dictionary, node: Node) -> Error:
	if json.has("pivot"):
		var pivot = Vector3(json.pivot[0], json.pivot[1], json.pivot[2])
		# Used to set transform.origin in AssetDoc::_asset_doc_mesh_filter__mesh_from_ref 
		node.position = pivot * -1.0
	return OK

#----------------------------------------
