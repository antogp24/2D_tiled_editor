package editor

import "core:reflect"
import rl "vendor:raylib"

CheckBox :: struct {
    using rect: rl.Rectangle,
    scale: f32,
    text: string,
    checked: bool,
}

init_tileflag_checkboxes :: proc()
{
    for &checkbox, index in editor.tileflags_checkboxes {
        flag_name := reflect.enum_string(TileFlag(index))
        checkbox.text = flag_name
        checkbox.scale = 2
        checkbox.width = cast(f32)editor.check_icon.width * checkbox.scale
        checkbox.height = cast(f32)editor.check_icon.height * checkbox.scale
        checkbox.checked = TileFlag(index) in editor.flags
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
