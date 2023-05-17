#----------------------------------------

# This wraps the all of the `{guid}/` data

class_name Asset extends AssetBase

#----------------------------------------

func asset_scene(root_node: Node3D, parent: Node3D = null):
	trace("AssetScene")

	match self.type:
		"ModelImporter":
			return asset_model_importer(root_node, parent)
		"NativeFormatImporter":
			match self.extension:
				"prefab":
					return asset_native_format_importer_prefab(root_node, parent)
				"mat":
					return asset_native_format_importer_material(root_node, parent)
				_:
					push_error("Asset::AssetScene::UnsupportedType::%s::%s" % [
						self.type,
						self.extension
					])
					return null
		"TextureImporter":
			return asset_texture_importer(root_node, parent)
		"DefaultImporter":
			return asset_default_importer_prefab(root_node, parent)
		"PrefabImporter":
			return asset_native_format_importer_prefab(root_node, parent)
		_:
			push_error("Asset::AssetScene::UnsupportedType::%s" % self.type)
			return null

#----------------------------------------
# *.unity
func asset_default_importer_prefab(root_node: Node3D, parent: Node3D = null):
	trace("DefaultImporterPrefab")

	if upack.enable_memcache && data.has("_memcache_default_importer_prefab"):
		trace("DefaultImporterPrefab", "FromMemCache", Color.GREEN)
		return instantiate(
			root_node,
			parent,
			data._memcache_default_importer_prefab,
			"DefaultImporterPrefab 1"
		)

	if asset_is_on_disk():
		trace("DefaultImporterPrefab", "FromDisk", Color.GREEN)
		data._memcache_default_importer_prefab = asset_packed_scene_from_disk()
		return instantiate(
			root_node,
			parent,
			data._memcache_default_importer_prefab,
			"DefaultImporterPrefab 2"
		)

	trace("DefaultImporterPrefab", "Building", Color.GREEN)

	var root_children_docs = docs.filter(_helper_is_root_node)
	root_children_docs.sort_custom(_helper_sort_root_order)

	# Whoever creates it must add it and owner tag it
	var new_root_node: Node = Node3D.new()
	if parent != null:
		parent.add_child(new_root_node)
		new_root_node.owner = root_node

	new_root_node.name = self.filename
	set_created_by(new_root_node, "Asset::DefaultImporterPrefab")
	append_ufile_ids(new_root_node, [data._ufile_id], "Asset::DefaultImporterPrefab")

	upack.progress.progress_add(root_children_docs.size(), "Root Nodes")

	for child_doc in root_children_docs:
		child_doc.comp_doc_scene(new_root_node, new_root_node)
		upack.progress.progress_tick(child_doc.asset.pathname)

	# node_dump(new_root_node, "DefaultImporterPrefab 1")

	data._memcache_default_importer_prefab = asset_save_node_get_packed_scene(new_root_node, "DefaultImporterPrefab")
	return instantiate(
		root_node,
		parent,
		data._memcache_default_importer_prefab,
		"DefaultImporterPrefab 3"
	)

#----------------------------------------
# *.prefab
func asset_native_format_importer_prefab(root_node: Node3D, parent: Node3D = null) -> Node3D:
	trace("NativeFormatImporterPrefab")

	if upack.enable_memcache && data.has("_memcache_native_format_importer_prefab"):
		trace("NativeFormatImporterPrefab", "FromMemCache", Color.GREEN)
		return instantiate(
			root_node,
			parent,
			data._memcache_native_format_importer_prefab,
			"NativeFormatImporterPrefab 1"
		)

	if asset_is_on_disk():
		trace("NativeFormatImporterPrefab", "FromDisk", Color.GREEN)
		data._memcache_native_format_importer_prefab = asset_packed_scene_from_disk()
		return instantiate(
			root_node,
			parent,
			data._memcache_native_format_importer_prefab,
			"NativeFormatImporterPrefab 2"
		)

	trace("NativeFormatImporterPrefab", "Building", Color.GREEN)

	if docs == null:
		push_error("Asset::NativeFormatImporterPrefab::DocsMissing::%s" % self)
		return null

	var root_children_docs = docs.filter(_helper_is_root_node)
	root_children_docs.sort_custom(_helper_sort_root_order)

	if root_children_docs.size() == 0:
		push_error("Asset::NativeFormatImporterPrefab::RootDocNotFound::%s" % self)
		return null

	var root_doc = root_children_docs.front() as CompDoc
	trace("NativeFormatImporterPrefab", "%s::%s" % [
		"RootTransform",
		str(root_doc)
	], Color.PURPLE)

	var node = root_doc.comp_doc_scene(null, null)

	data._memcache_native_format_importer_prefab = asset_save_node_get_packed_scene(node, "NativeFormatImporterPrefab")
	return instantiate(
		root_node,
		parent,
		data._memcache_native_format_importer_prefab,
		"NativeFormatImporterPrefab 3"
	)

#----------------------------------------

func asset_native_format_importer_material(_root_node: Node3D, _parent: Node3D = null) -> MeshInstance3D:
	trace("NativeFormatImporterMaterial", "Building", Color.GREEN)

	var node = MeshInstance3D.new()
	node.name = self.filename

	var sphere = SphereMesh.new()
	node.mesh = sphere

	node.material_override = asset_material()

	set_created_by(node, "Asset::NativeFormatImporterMaterial")
	append_ufile_ids(node, [data._ufile_id], "Asset::NativeFormatImporterMaterial")

	return node

#----------------------------------------

func asset_texture_importer(_root_node: Node3D, _parent: Node3D = null) -> Node3D:
	trace("TextureImporter")

	trace("TextureImporter", "Building", Color.GREEN)

	var image = asset_image()
	if not image is Image:
		push_error("Asset::TextureImporter::ImageFailed")
		return null

	var texture = ImageTexture.new()
	texture.image = image

	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.resource_name = self.filename

	var node = MeshInstance3D.new()
	node.name = self.filename
	node.material_override = material

	var sphere = SphereMesh.new()
	node.mesh = sphere

	set_created_by(node, "Asset::TextureImporter")
	append_ufile_ids(node, [data._ufile_id], "TextureImporter")

	return node

#----------------------------------------

func asset_model_importer(root_node: Node3D, parent: Node3D = null) -> Node3D:
	trace("ModelImporter")

	if upack.enable_memcache && data.has("_memcache_model_importer"):
		trace("ModelImporter", "FromMemCache", Color.GREEN)
		return instantiate(
			root_node,
			parent,
			data._memcache_model_importer,
			"ModelImporter 1"
		)

	if asset_is_on_disk():
		trace("ModelImporter", "FromDisk", Color.GREEN)
		var packed = asset_packed_scene_from_disk()
		data._memcache_model_importer = packed
		return instantiate(
			root_node,
			parent,
			data._memcache_model_importer,
			"ModelImporter 2"
		)

	trace("ModelImporter", "Loading Binary", Color.GREEN)

	var buffer = self.load_binary()
	if buffer.size() == 0:
		push_error("Asset::ModelImporter::BufferEmpty")
		return null

	trace("ModelImporter", "Building", Color.GREEN)

	var doc = GLTFDocument.new()
	var state = GLTFState.new()

	# We are manually building a scene
	# Might not need to load it from the saved file here
	var result = doc.append_from_buffer(buffer, "", state)
	if result != OK:
		push_error("Asset::ModelImporter::AppendFromBufferFailed")
		return null

	var node = doc.generate_scene(state)
	node.name = self.filename

	set_created_by(node, "Asset::ModelImporter")
	append_ufile_ids(node, [data._ufile_id], "Asset::ModelImporter")

	# This is a temporary view of a material
	# No need to save, just pack
	data._memcache_model_importer = asset_node_to_packed_scene(node)
	return instantiate(
		root_node,
		parent,
		data._memcache_model_importer,
		"ModelImporter 3"
	)

#----------------------------------------

func asset_image() -> Image:
	trace("Image")

	if upack.enable_memcache && data.has("_memcache_image"):
		trace("Image", "FromMemCache", Color.GREEN)
		return data._memcache_image

	if self.type != "TextureImporter":
		push_error("Asset::Image::UnsupportedType::%s" % self.type)
		return null

	var supported_formats = ["png", "bmp", "tga", "jpg", "jpeg", "webp"]
	if !supported_formats.has(self.extension):
		push_error("Asset::Image::NotImage::%" % self)
		return null

	if asset_is_on_disk():
		trace("Image", "FromDisk", Color.GREEN)
		data._memcache_image = Image.load_from_file(asset_path_on_disk())
		asset_resource_from_disk()
		return data._memcache_image

	trace("Image", "Building", Color.GREEN)

	var buffer = self.load_binary()
	var image: Image

	if data.has("_disk_storage_binary_path"):
		image = Image.load_from_file(data._disk_storage_binary_path)
	else:
		image = Image.new()
		if !asset_image__load_image_from_buffer(image, buffer):
			push_error("Asset::Image::LoadFromBufferFailed")

	data._memcache_image = image
	return data._memcache_image

#----------------------------------------

func asset_image__load_image_from_buffer(image: Image, buffer: PackedByteArray) -> bool:
	match data.content_type:
		"image/png":				return image.load_png_from_buffer(buffer) == OK
		"image/bmp":				return image.load_bmp_from_buffer(buffer) == OK
		"image/tga":				return image.load_tga_from_buffer(buffer) == OK
		"image/jpg", "image/jpeg":	return image.load_jpg_from_buffer(buffer) == OK
		"image/webp":				return image.load_webp_from_buffer(buffer) == OK
	match self.extension:
		"png":			return image.load_png_from_buffer(buffer) == OK
		"bmp":			return image.load_bmp_from_buffer(buffer) == OK
		"tga":			return image.load_tga_from_buffer(buffer) == OK
		"jpg", "jpeg":	return image.load_jpg_from_buffer(buffer) == OK
		"webp":			return image.load_webp_from_buffer(buffer) == OK
	return false

#----------------------------------------

func asset_material__m_TexEnvs(material: StandardMaterial3D, mat_doc: CompDoc) -> void:
	var shader_keywords = mat_doc.content.get("m_ShaderKeywords", "")
	if shader_keywords == null:
		shader_keywords = ""

	for tex in mat_doc.content.m_SavedProperties.m_TexEnvs:
		var name = tex.keys().front()
		tex = tex[name]

		if tex.m_Texture.fileID == 0 && !tex.m_Texture.has("guid"):
			continue

		var image_asset = upack.get_asset_by_ref(tex.m_Texture)
		if not image_asset is Asset:
			push_warning("Asset::Material::TextureAssetMissing::%s::%s" % [
				self,
				tex.m_Texture
			])
			continue

		var image = image_asset.asset_image()
		if not image is Image:
			push_warning("Asset::Material::ImageFailed")
			continue

		var texture = ImageTexture.new()
		texture.image = image

		match name:
			# TODO
			"_BumpMap": pass
			"_DetailAlbedoMap": pass
			"_DetailMask": pass
			"_DetailNormalMap": pass
			"_EmissionMap":
				if shader_keywords.contains("_EMISSION"):
					material.emission_enabled = true
					material.emission_texture = texture
					material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			"_MainTex":
				material.albedo_texture = texture
			"_MetallicGlossMap":
				# TODO: Test if this is correct behavior
				if shader_keywords.contains("_METALLICGLOSSMAP"):
					material.metallic_texture = texture
			"_OcclusionMap": pass
			"_ParallaxMap": pass

#----------------------------------------

func asset_material__m_Colors(material: StandardMaterial3D, mat_doc: CompDoc) -> void:
	for color in mat_doc.content.m_SavedProperties.m_Colors:
		match color.keys().front():
			"_Color":
				material.albedo_color = Color(
					float(color._Color.r),
					float(color._Color.g),
					float(color._Color.b),
					float(color._Color.a)
				)
			"_EmisColor": pass
			"_EmissionColorUI": pass
			"_EmissionColor":
				material.emission = Color(
					float(color._EmissionColor.r),
					float(color._EmissionColor.g),
					float(color._EmissionColor.b),
					float(color._EmissionColor.a)
				)
			"_TintColor": pass

#----------------------------------------

func asset_material__m_Floats(material: StandardMaterial3D, mat_doc: CompDoc) -> void:
	for f in mat_doc.content.m_SavedProperties.m_Floats:
		match f.keys().front():
			# TODO
			"_BumpScale": pass
			"_Cutoff": pass
			"_DetailNormalMapScale": pass
			"_DstBlend": pass
			"_Glossiness": pass
			"_GlossMapScale": pass
			"_GlossyReflections": pass
			"_Metallic":
				material.metallic = float(f._Metallic)
			"_Mode":
				material.transparency = (f._Mode == 1)
			"_OcclusionStrength": pass
			"_Parallax": pass
			"_SmoothnessTextureChannel": pass
			"_SpecularHighlights": pass
			"_SrcBlend": pass
			"_UVSec": pass
			"_ZWrite": pass

#----------------------------------------

func asset_material() -> Material:
	if upack.enable_memcache && data.has("_memcache_material"):
		trace("Material", "FromMemCache", Color.GREEN)
		return data._memcache_material

	if asset_is_on_disk():
		data._memcache_material = asset_resource_from_disk()
		return data._memcache_material

	trace("Material", "Loading", Color.YELLOW)

	var main_object_file_id: int
	if self.meta.content.has("mainObjectFileID"):
		main_object_file_id = self.meta.content.mainObjectFileID
	else:
		main_object_file_id = self.docs[0]._file_id

	var mat_doc = upack.get_comp_doc(data._guid, main_object_file_id)
	if not mat_doc is CompDoc:
		push_error("_Material::CompDocNotFound::%s" % main_object_file_id)
		return null

	if mat_doc.content.m_Shader.guid != "0000000000000000f000000000000000":
		push_warning("Asset::_Material::NonStandardShader::%s::%s" % [
			mat_doc,
			mat_doc.content.m_Shader
		])

	var material = StandardMaterial3D.new()
	material.resource_name = mat_doc.content.m_Name
	
	asset_material__m_TexEnvs(material, mat_doc)
	asset_material__m_Colors(material, mat_doc)
	asset_material__m_Floats(material, mat_doc)

	data._memcache_material = asset_save_resource_to_disk(material, "Asset::Material")
	return data._memcache_material

#----------------------------------------
