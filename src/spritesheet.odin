package editor

import "core:os"
import "core:slice"
import "core:strings"
import "core:path/filepath"

import rl "vendor:raylib"

SpriteSheet :: struct {
    texture: rl.Texture2D,
    name: string,
}

SpriteSheets :: #soa[dynamic]SpriteSheet

spritesheets_load :: proc(path: string) -> (spritesheets: SpriteSheets)
{
    dir_contents, err := read_dir(path)
    assert(err == os.ERROR_NONE)
    defer delete(dir_contents)

    i, least_wide: i32

    for &listing in dir_contents {
        if !listing.is_dir && strings.compare(filepath.long_ext(listing.name), ".png") == 0 {
            to_concatenate := [3]string{path, "/", listing.name}
            path, _ := strings.concatenate(to_concatenate[:], context.temp_allocator)
            path_null_terminated := strings.clone_to_cstring(path, context.temp_allocator)

            spritesheet := SpriteSheet {
                rl.LoadTexture(path_null_terminated), 
                strings.clone(listing.name)
            }
            append_soa(&spritesheets, spritesheet)

            using spritesheet
            if i == 0 do least_wide = texture.width
            if least_wide > texture.width do least_wide = texture.width
            i += 1
        }
    }
    editor.min_split_x = f32(least_wide * SCALE) + SPLIT_THICK/2
    editor.split_x = f32(spritesheets[editor.current_spritesheet].texture.width) * SCALE + SPLIT_THICK/2

    return spritesheets
}

spritesheets_unload :: proc(spritesheets: SpriteSheets)
{
    for &spritesheet in spritesheets {
        rl.UnloadTexture(spritesheet.texture)
        delete_string(spritesheet.name)
    }
}