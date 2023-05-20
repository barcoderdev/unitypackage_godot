#----------------------------------------

class_name PackagePatcher

#----------------------------------------

func patch_meshfilter_node(upack: UPackGD, node: Node, mesh_name: String):
	if upack.package_path.contains("POLYGON_SciFi_City"):
		scifi_city__patch_meshfilter_node(node, mesh_name)

#----------------------------------------

func scifi_city__patch_meshfilter_node(node: Node, mesh_name: String):
	# Not sure how these are scaled correctly in Unity, maybe something in the FBX?
	var rescale = ["SM_Sign_Billboard_Large_", "SM_Prop_Posters_", "SM_Prop_Cables_"]
	for r in rescale:
		if mesh_name.contains(r):
			trace("PackagePatcher::Rescaling::%s" % mesh_name, Color.ORANGE)
			node.scale *= 0.1
			node.position *= 0.1
			return

	if ["Skydome", "Moon", "Stars", "Sun"].has(mesh_name):
		node.scale *= 100

#----------------------------------------

func trace(message: String, color: Color):
	var text = "[color=%s][PackagePatcher] %s[/color]" % [
		color.to_html(),
		message,
	]
	print_rich(text)

#----------------------------------------
