#----------------------------------------

class_name UPackGDBase

#----------------------------------------

const MIN_UNITYPACKAGE_UTIL_VERSION = "0.1.3"

#----------------------------------------

# https://docs.unity3d.com/351/Documentation/Manual/YAMLSceneExample.html

#----------------------------------------
# Built in native importers
#
# https://docs.unity3d.com/Manual/BuiltInImporters.html
#
# AssemblyDefinitionImporter              asmdef
# AssemblyDefinitionReferenceImporter     asmref
# AudioImporter                           ogg, aif, aiff, flac, wav, mp3, mod, it, s3m, xm
# ComputeShaderImporter                   compute
# DefaultImporter                         rsp, unity
# FBXImporter                             fbx, mb, ma, max, jas, dae, dxf, obj, c4d, blend, lxo
# IHVImageFormatImporter                  astc, dds, ktx, pvr
# LocalizationImporter                    po
# Mesh3DSImporter                         3ds
# NativeFormatImporter                    anim, animset, asset, blendtree, buildreport, colors, controller, cubemap
#                                         , curves, curvesNormalized, flare, fontsettings, giparams, gradients, guiskin, ht, mask, mat, mesh
#                                         , mixer, overrideController, particleCurves, particleCurvesSigned, particleDoubleCurves
#                                         , particleDoubleCurvesSigned, physicMaterial, physicsMaterial2D, playable, preset, renderTexture
#                                         , shadervariants, spriteatlas, state, statemachine, texture2D, transition, webCamTexture, brush, terrainlayer, signal
# PackageManifestImporter                 json
# PluginImporter                          dll, winmd, so, jar, java, kt, aar, suprx, prx, rpl, cpp, cc, c, h, jslib, jspre, bc, a, m, mm, swift, xib, bundle, dylib, config
# PrefabImporter                          prefab
# RayTracingShaderImporter                raytrace
# ShaderImporter                          cginc, cg, glslinc, hlsl, shader
# SketchUpImporter                        skp
# SpeedTreeImporter                       spm, st
# SubstanceImporter                       .sbsar
# TextScriptImporter                      txt, html, htm, xml, json, csv, yaml, bytes, fnt, manifest, md, js, boo, rsp
# TextureImporter                         jpg, jpeg, tif, tiff, tga, gif, png, psd, bmp, iff, pict, pic, pct, exr, hdr
# TrueTypeFontImporter                    ttf, dfont, otf, ttc
# VideoClipImporter                       avi, asf, wmv, mov, dv, mp4, m4v, mpg, mpeg, ogv, vp8, webm
# VisualEffectImporter                    vfx, vfxoperator, vfxblock
#----------------------------------------

var package_path: String
var catalog: Dictionary
var debug_log: bool
var unitypackage_util: String
var fbx2gltf: String
var enable_disk_storage: bool = false
var enable_memcache: bool = false
var upack_config: UPackGDConfig

#----------------------------------------

static func call_only_once():
	print("UPackGD::CallOnlyOnce::RegisterPivotFixer")
	GLTFDocument.register_gltf_document_extension(PivotFixer.new(), true)

#----------------------------------------

func directories() -> PackedStringArray:
	if catalog == null || catalog.is_empty():
		push_error("UPackGD::_directories::NotReady")
		return []

	var dir_only = func(guid) -> bool:
		return catalog[guid].asset_meta[0].folderAsset == true

	var to_pathname = func(guid) -> String:
		return catalog[guid].pathname

	var dirs: PackedStringArray = (catalog
		.keys()
		.filter(dir_only)
		.map(to_pathname))

	dirs.sort()
	return dirs

#----------------------------------------

# callback(UPackGD, dir_path: String, files: Array)

func files(dir_path: String, callback: Callable = Callable()) -> Array:
	if callback.is_valid():
		WorkerThreadPool.add_task(func():
			var dirs = _files(dir_path)
			callback.call_deferred(self, dir_path, dirs)
		)
		return []
	else:
		return _files(dir_path)

#----------------------------------------

func _files(dir_path: String) -> Array:
	if catalog == null || catalog.is_empty():
		push_error("UPackGD::_directory_list::NotReady")
		return []

	var dir_path_files_only = func (guid: String, dir_path: String) -> bool:
		if catalog[guid].pathname == null:
			return false
		var a = catalog[guid].pathname.begins_with(dir_path)
		var b = !catalog[guid].asset_meta[0].folderAsset
		return a && b

	var to_asset = func (guid) -> Dictionary:
		return catalog[guid]

	var contents: Array = (catalog
		.keys()
		.filter(dir_path_files_only.bind(dir_path))
		.map(to_asset))

	var sort = func(a: Dictionary, b: Dictionary) -> bool:
		var a_name: String = a.pathname
		var b_name: String = b.pathname
		return a_name.casecmp_to(b_name) == 0

	contents.sort_custom(sort)
	return contents

#----------------------------------------

func package_extract_binary(guid: String, _fbx2gltf: bool) -> PackedByteArray:
	if _fbx2gltf && ["Windows", "UWP"].has(OS.get_name()):
		# Binary pipes do not work on Windows
		# Get the FBX file in base64
		var data64 = _util_execute([
			package_path,
			"extract",
			guid,
			"--base64"
		], [""])[0]

		# Decode it
		var raw_fbx = Marshalls.base64_to_raw(data64)

		# Save to temp file
		var temp_file = "%s/%s-%s.temp" % [
			upack_config.extract_path,
			str(Time.get_unix_time_from_system()),
			str(Time.get_ticks_msec())
		]
		DirAccess.make_dir_recursive_absolute(temp_file.get_base_dir())
		var file = FileAccess.open(temp_file, FileAccess.WRITE)
		assert(file != null, "TempFileError")
		file.store_buffer(raw_fbx)
		file.close()

		# Convert to GLB
		_fbx2gltf_execute([
			"-b",
			"-i",
			ProjectSettings.globalize_path(temp_file),
			"-o",
			ProjectSettings.globalize_path("%s.glb" % temp_file)
		], false)

		# Load the GLB
		file = FileAccess.open("%s.glb" % temp_file, FileAccess.READ)
		assert(file != null)
		var buffer = file.get_buffer(file.get_length())
		file.close()

		DirAccess.remove_absolute(temp_file)
		DirAccess.remove_absolute("%s.glb" % temp_file)

		return buffer
	else:
		var result = _util_execute([
			package_path,
			"extract",
			guid,
			# -f, --fbx2gltf
			# -b, --base64
			"-fb" if _fbx2gltf else "-b"
		], [""])[0]
		return Marshalls.base64_to_raw(result)

#----------------------------------------

func package_extract_json(guid: String):
	return JSON.parse_string(_util_execute([
		package_path,
		"extract",
		guid,
		"-j"
	], [""])[0])

#----------------------------------------

func unitypackage_util_version_check() -> bool:
	var version: String = _util_execute([
		"--version"
	], [""])[0].replace("unitypackage_util ", "")
	return compare_sem_ver(version, MIN_UNITYPACKAGE_UTIL_VERSION) != -1

#----------------------------------------

func compare_sem_ver(version1: String, version2: String) -> int:
	var v1 = version1.split(".")
	var v2 = version2.split(".")

	if v1.size() != 3 || v2.size() != 3:
		return -1

	for i in range(3): # Assuming SemVer format of <major>.<minor>.<revision>
		var num1 = int(v1[i])
		var num2 = int(v2[i])

		if num1 > num2:
			return 1
		elif num1 < num2:
			return -1

	return 0  # Versions are equal

#----------------------------------------

func package_dump():
	var catalog_path: String = "%s/%s/catalog.json" % [
		upack_config.extract_path,
		package_path.get_file().get_basename()
	]
	var location_path: String = "%s/%s/location.txt" % [
		upack_config.extract_path,
		package_path.get_file().get_basename()
	]

	if upack_config.enable_disk_storage && FileAccess.file_exists(catalog_path):
		var json = FileAccess.get_file_as_string(catalog_path)
		return JSON.parse_string(json)

	var json = _package_dump()

	if upack_config.enable_disk_storage:
		DirAccess.make_dir_recursive_absolute(catalog_path.get_base_dir())
		var file = FileAccess.open(catalog_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(json))
			file.close()
		else:
			push_warning("UPackGD::PackageDump::FileOpenError::%s::%s" % [FileAccess.get_open_error(), catalog_path])

		file = FileAccess.open(location_path, FileAccess.WRITE)
		if file != null:
			file.store_string(package_path)
			file.close()
		else:
			push_warning("UPackGD::PackageDump::FileOpenError::%s::%s" % [FileAccess.get_open_error(), location_path])

	return json

#----------------------------------------

func _package_dump():
	var dump = _util_execute([
		package_path,
		"dump"
	], [""])[0]

	if dump == "":
		push_error("AssetUtilRS::PackageDump::DumpFailed")
		return null

	var json = JSON.parse_string(dump)
	if json == null:
		push_error("AssetUtilRS::PackageDump::JsonParseFailed")
		return null

	var copy_guid_ufile = func(guid: String, dict: Dictionary):
		var asset = dict[guid]
		asset._ufile_id = "%s:%s" % [guid, "_"]
		asset._guid = guid
		if asset.asset != null:
			asset.asset.map(func(asset):
				asset._guid = guid
				asset._ufile_id = "%s:%s" % [guid, asset._file_id]
			)

	(json
		.keys()
		.map(copy_guid_ufile.bind(json))
	)

	return json

#----------------------------------------

func _util_execute(arguments: PackedStringArray, default: Variant):
	# print("UPackGD::UtilExecute::%s %s" % [unitypackage_util, " ".join(arguments)])
	var output = []
	var result = OS.execute(ProjectSettings.globalize_path(unitypackage_util), arguments, output)
	if result != 0:
		push_error("Error _util_execute %d: %s %s = %s" % [result, unitypackage_util, arguments, output])
		return default
	return output

#----------------------------------------

func _fbx2gltf_execute(arguments: PackedStringArray, default: Variant):
	# print("UPackGD::Fbx2GltfExecute::%s %s" % [fbx2gltf, " ".join(arguments)])
	var output = []
	var result = OS.execute(ProjectSettings.globalize_path(fbx2gltf), arguments, output)
	if result != 0:
		push_error("Error _fbx2gltf_execute %d: %s %s = %s" % [result, fbx2gltf, arguments, output])
		return default
	return output

#----------------------------------------

func xxhash64(text: String) -> String:
	var output = []
	var arguments = [
		"none",
		"xx-hash",
		text
	]
	var result = OS.execute(ProjectSettings.globalize_path(unitypackage_util), arguments, output)
	if result != 0:
		push_error("Error xxhash64 %d: %s %s = %s" % [result, unitypackage_util, arguments, output])
		return ""
	return output[0]

#----------------------------------------

func _init(_package_path: String, _upack_config: UPackGDConfig):
	package_path = _package_path
	upack_config = _upack_config

	unitypackage_util = upack_config.unitypackage_util_path
	fbx2gltf = upack_config.fbx2gltf_path
	debug_log = upack_config.debug_log

	enable_disk_storage = upack_config.enable_disk_storage
	enable_memcache = upack_config.enable_memcache

	assert(FileAccess.file_exists(upack_config.unitypackage_util_path), "unitypackage_util not found")
	assert(FileAccess.file_exists(upack_config.fbx2gltf_path), "fbx2gltf not found")

	assert(unitypackage_util_version_check(), "unitypackage_util needs updating to %s" % MIN_UNITYPACKAGE_UTIL_VERSION)

#----------------------------------------

func trace(message: String, color: Color = Color.VIOLET) -> void:
	if debug_log:
		print_rich("📦 [color=%s][UPackGD] %s[/color]" % [
			color.to_html(),
			message
		])

#----------------------------------------
