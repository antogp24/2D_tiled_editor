package editor

import "core:reflect"
import rl "vendor:raylib"

CheckBox :: struct {
    using rect: rl.Rectangle,
    scale: f32,
    text: string,
    checked: bool,
}

// -------------------------------------------------------------------------------- //

checkbox_new :: proc(text: string, scale: f32 = 2, checked := false) -> (c: CheckBox)
{
    c.text = text
    c.scale = scale
    c.checked = checked
    c.width = cast(f32)editor.check_icon.width * scale
    c.height = cast(f32)editor.check_icon.height * scale
    return
}

// -------------------------------------------------------------------------------- //

init_tileflag_checkboxes :: proc()
{
    for &checkbox, index in editor.tileflags_checkboxes {
        flag_name := reflect.enum_string(TileFlag(index))
        is_checked := TileFlag(index) in editor.flags
        checkbox = checkbox_new(flag_name, checked=is_checked)
    }
}

// -------------------------------------------------------------------------------- //

checkbox_update :: proc(using checkbox: ^CheckBox) -> bool
{
    if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse.pos, rect) {
        checked = !checked
        return true
    }
    return false
}

// -------------------------------------------------------------------------------- //

checkbox_draw :: proc(using checkbox: ^CheckBox)
{
    rl.DrawRectangleLinesEx(rect, scale, PALETTE07)
    if checked do rl.DrawTextureEx(editor.check_icon, {rect.x, rect.y}, 0, scale, rl.WHITE)
    text_pos := rl.Vector2{
        rect.x + rect.width + 10,
        rect.y + rect.height/2 - scale*editor.font.h/2,
    }
    font_image_draw(&editor.font, scale, text, text_pos.x, text_pos.y, PALETTE07)
}
