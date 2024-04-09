package editor

import "core:fmt"
import "core:strings"
import "core:slice"
import "core:os"
import rl "vendor:raylib"

color_from_hex :: #force_inline proc($hex: int) -> rl.Color
{
    return rl.Color{
        u8((hex >> 24) & 0xFF),
        u8((hex >> 16) & 0xFF),
        u8((hex >>  8) & 0xFF),
        u8((hex >>  0) & 0xFF),
    }
}

@(require_results)
read_dir :: proc(dir_name: string, sort_names := true) -> ([]os.File_Info, os.Errno)
{
    f, err := os.open(dir_name, os.O_RDONLY)
    if err != 0 do return nil, err
    defer os.close(f)

    infos: []os.File_Info
    infos, err = os.read_dir(f, -1)
    if err != 0 do return nil, err

    if sort_names {
        slice.sort_by(infos, proc(a, b: os.File_Info) -> bool {
            return a.name < b.name
        })
    }
    return infos, 0
}

name_without_ext :: proc(name: string) -> string
{
    if len(name) == 0 do return name

    dot: int
    for character, index in name {
        if character == '.' {
            dot = index
            break
        }
    }
    if dot == 0 {
        if name[0] == '.' do return ""
        else do return name
    }
    return strings.string_from_ptr(raw_data(name), dot)
}

flags_to_int :: proc(flags: TileFlags) -> (result: int)
{
    for flag in TileFlag {
        if flag in flags {
            result |= int(flag)
        }
    }
    return
}

int_to_flags :: proc(number: int) -> (result: TileFlags)
{
    for flag in TileFlag {
        if number & int(flag) == int(flag) {
            result += {flag}
        }
    }
    return
}

bake_texture :: proc($path: cstring) -> (texture: rl.Texture2D)
{
    data :: #load("../" + path)
    temp_image := rl.LoadImageFromMemory(rl.GetFileExtension(path), raw_data(data), cast(i32)len(data))
    texture = rl.LoadTextureFromImage(temp_image)
    rl.UnloadImage(temp_image)
    return texture
}

load_data :: proc()
{
    clear_dynamic_array(&editor.tile_layers)

    name := editor.level_loader.names[editor.level_loader.cursor]

    builder := strings.builder_make(len=0, cap=len("levels/")+len(name))
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "levels/")
    strings.write_string(&builder, name)

    serialize_load_and_log(strings.to_string(builder))
    if len(editor.tile_layers) == 0 do append(&editor.tile_layers, TileLayer{})

}

save_data :: proc()
{
    if !editor.level_loader.loaded do return

    save_path := save_textbox_string(&editor.save_textbox)
    defer strings.builder_destroy(&save_path)

    serialize_save_and_log(strings.to_string(save_path))
}