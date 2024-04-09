package editor

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

LevelLoader :: struct {
    names: [dynamic]string,
    cursor_icon: rl.Texture2D,
    cursor: int,
    scroll: f32,
    loaded, active: bool,
}

@(private="file") _SCALE :: 4
@(private="file") _PADDING :: _SCALE


level_loader_init :: proc(using loader: ^LevelLoader)
{
    level_loader_fetch_names(loader)
    cursor_icon = bake_texture("icons/level_loader_cursor.png")
    return
}

level_loader_delete :: proc(using loader: ^LevelLoader)
{
    delete(editor.level_loader.names)
    rl.UnloadTexture(cursor_icon)
}

level_loader_fetch_names :: proc(using loader: ^LevelLoader)
{
    file_infos, err := read_dir("levels")
    assert(err == os.ERROR_NONE)
    defer delete(file_infos)

    for &listing in file_infos {
        if !listing.is_dir {
            append(&loader.names, listing.name)
        }
    }
}

@(private="file")
get_listing_rect :: proc(using loader: ^LevelLoader) -> rl.Rectangle
{
    return rl.Rectangle {
        screen.w/2,
        screen.h/2 - scroll,
        editor.font.w * _SCALE * 20,
        editor.font.h * _SCALE + _SCALE,
    }
}

level_loader_toggle :: proc(using loader: ^LevelLoader)
{
    active = !active
    scroll = 0
    cursor = 0
}

level_loader_load :: proc(using loader: ^LevelLoader, index: int)
{
    file_name := name_without_ext(names[index])
    textbox_set_text(&editor.save_textbox, file_name)
    load_data()
    active = false
    loaded = true
}

level_loader_update :: proc(using loader: ^LevelLoader)
{
    if rl.IsKeyPressed(.UP) {
        cursor -= 1
        cursor %%= len(names)
    }
    if rl.IsKeyPressed(.DOWN) {
        cursor += 1
        cursor %%= len(names)
    }

    if rl.IsKeyPressed(.ENTER) {
        level_loader_load(loader, cursor)
    }

    rect_height := get_listing_rect(loader).height
    if mouse.wheel != 0 do scroll += 60 * rect_height * mouse.wheel * time.delta
}

level_loader_draw :: proc(using loader: ^LevelLoader)
{
    rl.DrawRectangleRec({0, 0, screen.w, screen.h}, rl.ColorAlpha(PALETTE00, 0.8))

    for name, i in names {
        name := name_without_ext(name)
        rect := get_listing_rect(loader)
        rect.x -= rect.width/2
        rect.y += (cast(f32)i - cast(f32)len(names)/2) * (rect.height + _PADDING)

        rl.DrawRectangleRec(rect, PALETTE03 if i % 2 != 0 else PALETTE04)
        text_pos: rl.Vector2 = {
            rect.x + rect.width/2 - cast(f32)len(name) * _SCALE * editor.font.w/2,
            rect.y + rect.height/2 - editor.font.h/2 * _SCALE,
        }
        font_image_draw(&editor.font, _SCALE, name, text_pos.x, text_pos.y, PALETTE07)

        if i == cursor {
            icon_w, icon_h := f32(cursor_icon.width)*_SCALE, f32(cursor_icon.height)*_SCALE
            pos: rl.Vector2 = {rect.x - icon_w, rect.y + rect.height/2 - icon_h/2}
            rl.DrawTextureEx(cursor_icon, pos, 0, _SCALE, PALETTE07)
        }
    }
    rl.DrawTextureEx(editor.cursor_icon, mouse.pos, 0, 2, rl.WHITE)
}
