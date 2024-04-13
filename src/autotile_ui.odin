package editor

import rl "vendor:raylib"

AutoTileInterface :: struct {
    checkbox: CheckBox,
    selection: TileSelection,
    placing, adding: bool,
}

get_autotile_info_rect :: proc(autotile_info: AutoTileInfo) -> rl.Rectangle
{
    pos := get_tile_selector_pos()
    return rl.Rectangle{
        cast(f32)autotile_info.offset.x * editor.tile_w * SCALE + pos.x,
        cast(f32)autotile_info.offset.y * editor.tile_h * SCALE + pos.y,
        cast(f32)autotile_info.w * editor.tile_w * SCALE,
        cast(f32)autotile_info.h * editor.tile_h * SCALE,
    }
}

get_autotile_selected_info :: proc(autotile_infos: [dynamic]AutoTileInfo) -> Maybe(AutoTileInfo)
{
    for autotile_info in autotile_infos {
        rect := get_autotile_info_rect(autotile_info)
        selected := get_tile_selector_selected_rect()
        if rl.CheckCollisionRecs(rect, selected) {
            return autotile_info
        }
    }
    return nil
}

autotile_ui_update :: proc()
{
    using editor.autotile
    if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.A) {
        adding = !adding
    }

    if adding {
        if rl.IsMouseButtonDown(.RIGHT) && is_mouse_on_tile_selector() {
            for i: int; i < len(editor.spritesheets[editor.current_spritesheet].autotile); {
                autotile_info := editor.spritesheets[editor.current_spritesheet].autotile[i]
                rect := get_autotile_info_rect(autotile_info)
                if rl.CheckCollisionPointRec(mouse.pos, rect) {
                    ordered_remove(&editor.spritesheets[editor.current_spritesheet].autotile, i)
                } else {
                    i += 1
                }
            }
        }
        if rl.IsMouseButtonPressed(.LEFT) && is_mouse_on_tile_selector() {
            selection.start = get_tile_selector_mouse_tile()
            placing = true
        }
        if rl.IsMouseButtonDown(.LEFT) && placing {
            selection.end = get_tile_selector_mouse_tile()
        }
        if rl.IsMouseButtonUp(.LEFT) && placing {
            selection.end = get_tile_selector_mouse_tile()
            swap_selection_boundaries_if_needed(&selection)
            autotile_info := AutoTileInfo{
                selection.start,
                selection.end.x - selection.start.x + 1,
                selection.end.y - selection.start.y + 1,
                editor.current_spritesheet,
                .invalid,
            }
            if autotile_info.w == 3 && autotile_info.h == 3 {
                autotile_info.arrangement = .m3x3
            } else if autotile_info.w == 3 && autotile_info.h == 1 {
                autotile_info.arrangement = .m1x3
            }

            if autotile_info.arrangement != .invalid {
                append(&editor.spritesheets[editor.current_spritesheet].autotile, autotile_info)
            }
            placing = false
        }
    }
}

autotile_ui_draw :: proc()
{
    using editor.autotile
    if placing do selection_draw(selection, offset=get_tile_selector_pos())
}