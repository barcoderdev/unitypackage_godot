#----------------------------------------

extends Control

#----------------------------------------

var threading: bool = false
var threading_for_load: bool = false

#----------------------------------------

@onready var dir_tree: Tree = $VSplitContainer/VBoxContainerTop/Tree
@onready var file_list: ItemList = $VSplitContainer/VBoxContainerBottom/ItemList
@onready var console: RichTextLabel = $"../VSplitContainer/Console"

@onready var import_button: Button = $VSplitContainer/VBoxContainerTop/Button
@onready var file_dialog: FileDialog = $FileDialog

@export var progress_bar: ProgressBar
@export var viewport: Viewport

@onready var upack_config = load("res://unitypackage_godot_config.tres") as UPackConfig

#----------------------------------------

var progress_mutex: Mutex = Mutex.new()

#----------------------------------------

func _init():
	UPackRS.call_only_once()
	init.call_deferred()

#----------------------------------------

func init():
	file_dialog.root_subfolder = upack_config.default_open_path

	var root_dir_item = dir_tree.create_item()
	root_dir_item.set_text(0, "/")

	import_button.pressed.connect(func(): file_dialog.show())
	dir_tree.item_activated.connect(load_directory_files)
	file_list.item_activated.connect(load_asset_file)
	file_dialog.file_selected.connect(func(path): load_package(path))

#----------------------------------------

var loaded_packages = []

func load_package(package: String):

	var uurs = UPackRS.new(package, upack_config)

	uurs.progress.progress.connect(progress_update)
	uurs.progress.message.connect(progress_message)

	if loaded_packages.has(package):
		pprint("Already Loaded: %s" % package)
	elif !uurs.load_catalog():
		pprint("Load Catalog Failed: %s" % uurs.package_path, false)
	else:
		loaded_packages.push_back(package)
		load_directories(uurs)
		if upack_config.immediate_load_assets:
			uurs.build_all_prefabs(false)

#----------------------------------------

func load_directories(uurs: UPackRS):
	var dirs = uurs.directories()
	var root_path = dirs[0]

	var package_item = dir_tree.create_item()
	package_item.set_text(0, uurs.package_path.get_file().get_basename())

	for dir in dirs:
		if dir == root_path:
			continue
		var item = dir_tree.create_item(package_item)
		var dir_path = dir.replace(root_path, "") + "/"
		item.set_text(0, dir_path)
		item.set_metadata(0, [uurs, dir])

#----------------------------------------

func load_directory_files():
	var selected = dir_tree.get_selected()
	var meta = selected.get_metadata(0)
	if meta == null:
		return

	var uurs = meta[0]
	var dir = meta[1]

	load_dir_items(uurs, dir)

#----------------------------------------

func load_dir_items(uurs: UPackRS, dir: String):
	uurs.files(dir, func(_uurs: UPackRS, _dir_path: String, files: Array):
		file_list.clear()
		for item in uurs.files(dir):
			var item_name = item.pathname.replace(dir + "/", "") as String
			if item_name.contains("/"):
				continue
			var index = file_list.add_item(item_name)
			file_list.set_item_metadata(index, [uurs, item._guid, item.pathname])

		file_list.sort_items_by_text()
	)

#----------------------------------------

func load_asset_file(index):
	console.clear()

	var meta = file_list.get_item_metadata(index)
	var uurs = meta[0] as UPackRS
	var guid = meta[1] as String
	var path = meta[2] as String

	var asset = uurs.get_asset(guid)
	var packed_scene = asset.asset_scene(null, null)
	var node
	if packed_scene == null:
		print("Browser::NullScene")
		return
	elif packed_scene is PackedScene:
		node = packed_scene.instantiate()
		if not node is Node:
			pprint("Not a node", false)
			return
	else:
		node = packed_scene

	var loaded = get_node("/root/Main/Loaded/")
	for n in loaded.get_children():
		n.queue_free()

	loaded.add_child(node)

#----------------------------------------

func pprint(data, stringify = true, color = "#FFFFFF", print_console = false):
	var text = ""
	if stringify:
		text = JSON.stringify(data, "\t\t", true)
	else:
		text = data
	print(text)
	if print_console:
		console.append_text("[color=%s]%s[/color]" % [color, text] + "\n")

#----------------------------------------

func progress(cur, total):
	if progress_bar == null:
		push_warning("progress_bar not set")
		return

	if cur < total:
		progress_bar.value = float(cur) / float(total)
		progress_bar.visible = true
	else:
		progress_bar.visible = false

#----------------------------------------

func progress_update(_cur: int, _max: int, status: String, tick: bool):
	progress_mutex.lock()
	console.append_text("[color=%s][Loader] %d/%d = %s[/color]\n" % [
		Color.GREEN.to_html() if tick else Color.CORNFLOWER_BLUE.to_html(),
		_cur,
		_max,
		status
	])
	progress(_cur, _max)
	progress_mutex.unlock()

#----------------------------------------

func progress_message(text: String):
	progress_mutex.lock()
	console.append_text("%s\n" % text)
	progress_mutex.unlock()

#----------------------------------------
