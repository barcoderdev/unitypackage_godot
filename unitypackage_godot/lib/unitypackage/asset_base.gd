#----------------------------------------

class_name AssetBase extends BaseCommon

#----------------------------------------

const DISK_STORAGE_VERSION: float = 0.1
const DISK_STORAGE_VERSION_KEY: String = "disk_store_ver"

#----------------------------------------

# Do not store anything on this
# Store it on data for persistence

var uurs: UPackRS
var data: Dictionary

#----------------------------------------

var meta: AssetMeta
var docs
var type: String
var filename: String
var extension: String
var pathname: String
var _file_id: String

#----------------------------------------

func trace(method: String, message: String = "", color: Color = Color.DODGER_BLUE) -> void:
	if !debug_log:
		return

	var emojis = {
		"Material": "🎨",
		"ModelImporter": "🗽",
		"NativeFormatImporter": "🖨️",
		"TextureImporter": "🖌️",
		"DefaultImporter": "👌"
	}

	var emoji = "%s " % emojis[self.meta.type] if emojis.has(self.meta.type) else ""

	var text = "%s[color=%s][Asset] %s::%s[/color]" % [
		emoji,
		color.to_html(),
		method,
		str(self) if message == "" else message
	]
	if debug_log:
		print_rich(text)
	uurs.progress.message.emit(text)

#----------------------------------------

func load_binary() -> PackedByteArray:
	trace("LoadBinary")

	# _memcache_packagebinary used by load_binary, save_binary

	if data.has("_memcache_packagebinary"):
		return data.get("_memcache_packagebinary", null) as PackedByteArray

	var disk_path = disk_storage_path()
	if FileAccess.file_exists(disk_path):
		data._memcache_packagebinary = load_binary_from_cache()
		if data._memcache_packagebinary.size() == 0:
			# Cache might have been cleared but file record still exists?
			# Try reloading below
			data._memcache_packagebinary = null

	if data.get("_memcache_packagebinary", null) == null:
		var convert_fbx = data.content_type == "data/fbx"
		var bin_data = uurs.package_extract_binary(data._guid, convert_fbx)
		if bin_data.size() == 0:
			push_error("Asset::LoadBinary::PackageExtractBinaryFailed")
			var _null = null
			return PackedByteArray()
		data._memcache_packagebinary = bin_data
		save_binary()

	return data.get("_memcache_packagebinary", null) as PackedByteArray

#----------------------------------------

func load_binary_from_cache() -> PackedByteArray:
	trace("LoadBinaryFromCache")

	var disk_path = disk_storage_path()

	var file = FileAccess.open(disk_path, FileAccess.READ)
	if file == null:
		push_warning("Asset::_LoadCachedBinary::FileOpenError::%s::%s" % [
			FileAccess.get_open_error(),
			disk_path
		])
		return PackedByteArray()

	var buffer = file.get_buffer(file.get_length())

	data._disk_storage_binary_path = disk_path

	file.close()
	return buffer

#----------------------------------------

func save_binary() -> bool:
	if !uurs.enable_disk_storage:
		trace("SaveBinary::EnableDiskStorage::Disabled", "", Color.RED)
		return false

	trace("SaveBinary")

	if data.get("_memcache_packagebinary", null) == null:
		push_warning("Asset::_SaveBinary::NoData")
		return false

	var disk_path = disk_storage_path()
	DirAccess.make_dir_recursive_absolute(disk_path.get_base_dir())

	var file = FileAccess.open(disk_path, FileAccess.WRITE)
	if file == null:
		push_warning("Asset::_SaveBinary::FileOpenError::%s::%s" % [FileAccess.get_open_error(), disk_path])
		return false

	file.store_buffer(data._memcache_packagebinary)
	file.close()

	data._disk_storage_binary_path = disk_path
	return true

#----------------------------------------

func disk_storage_path() -> String:
	var path: String = "%s/%s/%s" % [
		uurs.upack_config.extract_path,
		uurs.package_path.get_file().get_basename(),
		data.pathname
	]
	path = path.simplify_path()

	if data.content_type == "data/fbx":
		path = "%s.glb" % path.get_basename()

	return path

#----------------------------------------

func disk_storage_handler(disk_path: String, builder: Callable) -> Variant:
	if !uurs.enable_disk_storage:
		trace("DiskStorageHandler::EnableDiskStorage::Disabled", "", Color.RED)
		return builder.call()

	trace("DiskStorageHandler", disk_path)
	
	# Valid if:
	# - PackedScene
	# - Object with correct disk version in meta
	var is_valid = func(loaded: Variant) -> bool:
		var is_object = loaded is Object
		var is_packed_scene = loaded is PackedScene
		var disk_version = loaded.get_meta(DISK_STORAGE_VERSION_KEY, 0.0)
		return (
			is_packed_scene
			|| (
				loaded is Object
				&& loaded.get_meta(DISK_STORAGE_VERSION_KEY, 0.0) == DISK_STORAGE_VERSION
				)
		)

	# Try loading from disk
	if FileAccess.file_exists(disk_path):
		var loaded = load(disk_path)
		if is_valid.call(loaded):
			trace("DiskStorageHandler::Loaded")
			return loaded

	DirAccess.make_dir_recursive_absolute(disk_path.get_base_dir())

	# Build it
	trace("DiskStorageHandler::Building")
	var built = builder.call()
	if built is Node:
		trace("DiskStorageHandler::Packing::%s" % built.name)
		var packer = PackedScene.new()
		packer.pack(built)
		built = packer

	if built is Object || built is PackedScene:
		built.set_meta(DISK_STORAGE_VERSION_KEY, DISK_STORAGE_VERSION)
		if ResourceSaver.save(built, disk_path) != OK:
			breakpoint

		# Try loading from disk again
		if FileAccess.file_exists(disk_path):
			var loaded = load(disk_path)
			if is_valid.call(loaded):
				trace("DiskStorageHandler::Reloaded")
				return loaded

	# Build or disk load completely failed
	push_error("Asset::DiskStorageHandler::BuildLoadFailed::%s" % disk_path)
	return null

#----------------------------------------

func asset_path_on_disk() -> String:
	var path_name = ("%s/%s/%s" % [
		uurs.upack_config.extract_path,
		uurs.package_path.get_file().get_basename(),
		data.pathname
	])
	var base_name = path_name.get_basename().simplify_path()

	match self.type:
		"ModelImporter":
			return "%s.tscn" % base_name
		"NativeFormatImporter":
			match self.extension:
				"prefab":
					return "%s.tscn" % base_name
				"mat":
					return "%s.material" % base_name
				_:
					breakpoint
					return ""
		"TextureImporter":
			return path_name.simplify_path() # "%s.tres" % base_name
		"DefaultImporter":
			return "%s.tscn" % base_name
		"PrefabImporter":
			return "%s.tscn" % base_name
		_:
					breakpoint
					return ""

#----------------------------------------

func asset_is_on_disk() -> bool:
	if !uurs.enable_disk_storage:
		trace("AssetIsOnDisk::DiskStorageDisabled")
		return false

	var path = asset_path_on_disk()
	var result = FileAccess.file_exists(path)
	trace("AssetIsOnDisk::%s" % ["True" if result else "False"], "", Color.GREEN)
	return result

#----------------------------------------

func asset_packed_scene_from_disk() -> PackedScene:
	trace("AssetInstantiateFromDisk", "", Color.YELLOW)
	var result = _asset_load_from_disk()
	if not result is PackedScene:
		breakpoint
	return result

#----------------------------------------

func asset_resource_from_disk():
	trace("AssetResourceFromDisk::Cached", "", Color.YELLOW)
	return _asset_load_from_disk()

#----------------------------------------

func _asset_load_from_disk():
	if data.has("_memcache_assetloadfromdisk"):
		trace("AssetLoadFromDisk::Cached", "", Color.GREEN)
		return data._memcache_assetloadfromdisk

	trace("AssetLoadFromDisk::Loading", "", Color.GREEN)
	data._memcache_assetloadfromdisk = load(asset_path_on_disk())
	return data._memcache_assetloadfromdisk

#----------------------------------------

func asset_save_node_get_packed_scene(node: Node3D, source: String) -> PackedScene:
	if !uurs.enable_disk_storage:
		trace("SaveNodeGetPackedScene::DiskStorageDisabled", "", Color.YELLOW)
		return asset_node_to_packed_scene(node)

	if data.has("_memcache_savenodegetpackedscene"):
		trace("SaveNodeGetPackedScene::Cached", "", Color.GREEN)
		return data._memcache_savenodegetpackedscene

	if false:
		node.set_meta("saved_by", source)

	trace("SaveNodeGetPackedScene::Packing", "", Color.YELLOW)
	var packed = asset_node_to_packed_scene(node)
	if not packed is PackedScene:
		trace("SaveNodeGetPackedScene::PackError", "", Color.RED)
		return null

	var path = asset_path_on_disk()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	trace("SaveNodeGetPackedScene::Saving", "", Color.YELLOW)
	var result = ResourceSaver.save(packed, path)
	if result != OK:
		trace("SaveNodeGetPackedScene::SaveError", "", Color.RED)
		push_error("SaveNodeGetPackedScene::SaveError::%d::%s" % [result, self])
		return null

	trace("SaveNodeGetPackedScene::Reloading", "", Color.GREEN)
	data._memcache_savenodegetpackedscene = load(asset_path_on_disk())
	return data._memcache_savenodegetpackedscene

#----------------------------------------

func asset_node_to_packed_scene(node: Node3D) -> PackedScene:
	var packer = PackedScene.new()
	var result = packer.pack(node)
	if result != OK:
		push_error("NodeToPackedScene::PackFailed::%d::%s" % [
			result,
			self
		])
		return null
	return packer

#----------------------------------------

func asset_save_resource_to_disk(_asset, _source: String):
	if !uurs.enable_disk_storage:
		trace("AssetSaveResourceToDisk::DiskStorageDisabled", "", Color.YELLOW)
		return _asset

	var path = asset_path_on_disk()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var result = ResourceSaver.save(_asset, path)
	if result != OK:
		trace("AssetSaveResourceToDisk::Error", "", Color.RED)
		push_error("AssetSaveResourceToDisk::SaveError::%d::%s" % [result, self])
		return _asset

	trace("AssetSaveToDisk::Reloading", "", Color.GREEN)
	return load(path)

#----------------------------------------

func get_asset_doc_by_id(file_id: int) -> AssetDoc:
	if docs == null:
		return null
	for doc in docs:
		if doc._file_id == file_id:
			return doc
	return null

#----------------------------------------

func get_transform_doc_from_gameobject_id(file_id: int) -> AssetDoc:
	if docs == null:
		return null
	for doc in docs:
		if doc.type == "Transform" && doc.content.m_GameObject.fileID == file_id:
			return doc
	return null

#----------------------------------------

func _helper_is_root_node(doc: AssetDoc):
	return doc.is_root_node()

func _helper_sort_root_order(a: AssetDoc, b: AssetDoc):
	return a.get_root_order() < b.get_root_order()

#----------------------------------------

func _to_string():
#	return "[Asset] GUID: %s | Loaded: %s | %s" % [
#		data._guid,
#		"No" if data.has("_memcache_packagebinary") else "Yes",
#		data.pathname
#	]
	return "[Asset] [color=#ffffff]%s[/color] | %s" % [
		data.pathname, #.get_file(),
		data._guid
	]

#----------------------------------------

func _get(property: StringName):
	if property != "script":
		print("AssetBase::_get::%s" % property)

	if property == "_file_id":
		breakpoint

	if property == "asset":
		breakpoint

	if data == null || !data.has(property):
		return null

	return data.get(property)

#----------------------------------------

func _init(_uurs: UPackRS, _data: Dictionary):
	uurs = _uurs
	data = _data
	meta = AssetMeta.new(uurs, self, data.asset_meta[0])

	debug_log = uurs.debug_log

	type = meta.type
	filename = data.pathname.get_basename().get_file()
	extension = data.pathname.get_extension().to_lower()
	pathname = data.pathname

	if data.asset != null:
		docs = data.asset.map(func(doc):
			return AssetDoc.new(uurs, self, doc))

#----------------------------------------
