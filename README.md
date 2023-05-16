# UnityPackage Godot

- Requires `barcoderdev/FBX2glTF` in root of `res://`
- Requires `barcoderdev/unitypackage_util` in root of `res://`
- Make sure you can run `./FBX2glTF --help` and `./unitypackage_util --help` from command line, to check permissions
- Config in `res://unitypackage_godot_config.tres`

# Notes

- This has only been tested on macOS on M2 hardware
- Main scene in `res://unitypackage_godot/scenes/main.tscn`
- Uncheck `Immediate Load Assets` in `res://unitypackage_godot_config.tres` to only load what is opened in the UI
- `*.unity` files are converted if they are manually loaded in the UI

# TODO

- Skeleton3D on SkinnedMeshRenderer
- Collision components
- Audio assets
- More material properties
- Convert unitypackage_util to GDExtension: https://github.com/godot-rust/gdext
   - with fbx2gltf included: https://docs.rs/cxx/latest/cxx/
