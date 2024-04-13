package editor

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

TileFlag :: enum int {
    Collideable,
    Collectable,
    Count,
}
TileFlags :: distinct bit_set[TileFlag; int]

AutoTileArrangement :: enum {
    invalid,
    m3x3,
    m1x3,
}

AutoTileInfo :: struct {
    offset: [2]int,
    w, h, texture_index: int,
    arrangement: AutoTileArrangement,
}

TileInfo :: struct {
    i, j, texture_index, flags: int,
}

Tile :: struct {
    info: TileInfo,
    x, y: int,
}

TileSelection :: struct {
    start, end: [2]int
}

LevelBoundaries :: struct {
    min, max: int
}

TileLayer :: struct {
    tiles: map[[2]int]TileInfo,
    visible: bool,
}
SaveTileLayer :: map[string]TileInfo

// -------------------------------------------------------------------------------- //

get_selected_tile_info :: #force_inline proc() -> TileInfo
{
    return {editor.selected_tile.x, editor.selected_tile.y, editor.current_spritesheet, flags_to_int(editor.flags)}
}

// -------------------------------------------------------------------------------- //

clamp_selected_tiles :: proc()
{
    w := cast(int)editor.spritesheets[editor.current_spritesheet].texture.width
    h := cast(int)editor.spritesheets[editor.current_spritesheet].texture.height
    tw := cast(int)editor.tile_w
    th := cast(int)editor.tile_h
    editor.selected_tile.x = clamp(editor.selected_tile.x, 0, w / tw - 1)
    editor.selected_tile.y = clamp(editor.selected_tile.y, 0, h / th - 1)
}

// -------------------------------------------------------------------------------- //

get_mouse_tile_pos :: proc() -> [2]int
{
    return {
        mouse.tiled.x / int(editor.tile_w * SCALE),
        mouse.tiled.y / int(editor.tile_h * SCALE),
    }
}

// -------------------------------------------------------------------------------- //

update_level_boundaries :: proc(x, y: ^LevelBoundaries, pos: [2]int)
{
    if pos.y < y.min do y.min = pos.y
    if pos.y > y.max do y.max = pos.y
    if pos.x < x.min do x.min = pos.x
    if pos.x > x.max do x.max = pos.x
}

// -------------------------------------------------------------------------------- //

get_selection_rect :: proc(using selection: TileSelection) -> rl.Rectangle
{
    return rl.Rectangle {
        f32(start.x) * editor.tile_w * SCALE,
        f32(start.y) * editor.tile_h * SCALE,
        f32(end.x - start.x + 1) * editor.tile_w * SCALE,
        f32(end.y - start.y + 1) * editor.tile_h * SCALE,
    }
}

// -------------------------------------------------------------------------------- //

swap_selection_boundaries_if_needed :: proc(using selection: ^TileSelection)
{
    if end.x < start.x do start.x, end.x = end.x, start.x
    if end.y < start.y do start.y, end.y = end.y, start.y
}

// -------------------------------------------------------------------------------- //

selection_draw :: proc(selection: TileSelection, color := PALETTE05, offset := [2]f32{0, 0})
{
    selection := selection
    swap_selection_boundaries_if_needed(&selection)
    rect := get_selection_rect(selection)
    rect.x += offset.x
    rect.y += offset.y
    rl.DrawRectangleRec(rect, rl.ColorAlpha(PALETTE05, 0.4))
    rl.DrawRectangleLinesEx(rect, 2/editor.cam.zoom, PALETTE07)
}

// -------------------------------------------------------------------------------- //

place_rectangle_tiles_on_mouse :: proc(l: ^TileLayer)
{
    tools.rectangle.selection.end = get_mouse_tile_pos()
    swap_selection_boundaries_if_needed(&tools.rectangle.selection)

    using tools.rectangle.selection
    if !editor.autotile.checkbox.checked {
        for y in start.y..=end.y {
            for x in start.x..=end.x {
                pos := [2]int{x, y}
                l.tiles[pos] = get_selected_tile_info()
                update_level_boundaries(&editor.x_boundary, &editor.y_boundary, pos)
            }
        }
    } else {
        autotile_info, ok := get_autotile_selected_info(editor.spritesheets[editor.current_spritesheet].autotile).?
        if !ok do return
        if autotile_info.arrangement == .invalid do return

        flags := flags_to_int(editor.flags)

        rows_loop: for y, j in start.y..=end.y {
            cols_loop: for x, i in start.x..=end.x {
                pos := [2]int{x, y}

                info_offset: [2]int
                #partial switch autotile_info.arrangement {
                    case .m3x3: {
                        if j == 0 && i == 0 {
                            info_offset = {0, 0}
                        } else if j == 0 && i > 0 && i < math.abs(end.x - start.x) {
                            info_offset = {1, 0}
                        } else if j == 0 && i == math.abs(end.x - start.x) {
                            info_offset = {2, 0}
                        } else if j > 0 && j < math.abs(end.y - start.y)  && i == 0 {
                            info_offset = {0, 1}
                        } else if j > 0 && j < math.abs(end.y - start.y)  && i == math.abs(end.x - start.x) {
                            info_offset = {2, 1}
                        } else if j == math.abs(end.y - start.y)  && i == 0 {
                            info_offset = {0, 2}
                        } else if j == math.abs(end.y - start.y)  && i > 0 && i < math.abs(end.x - start.x) {
                            info_offset = {1, 2}
                        } else if j == math.abs(end.y - start.y)  && i == math.abs(end.x - start.x) {
                            info_offset = {2, 2}
                        } else {
                            info_offset = {1, 1}
                        }
                    }
                    case .m1x3: {
                        if j > 0 do break rows_loop

                        if j == 0 && i == 0 {
                            info_offset = {0, 0}
                        } else if j == 0 && i > 0 && i < math.abs(end.x - start.x) {
                            info_offset = {1, 0}
                        } else if j == 0 && i == math.abs(end.x - start.x) {
                            info_offset = {2, 0}
                        }
                    }
                }
                info := TileInfo{
                    autotile_info.offset.x + info_offset.x, 
                    autotile_info.offset.y + info_offset.y, 
                    autotile_info.texture_index, 
                    flags, 
                }
                l.tiles[pos] = info
                update_level_boundaries(&editor.x_boundary, &editor.y_boundary, pos)
            }
        }
    }
}

// -------------------------------------------------------------------------------- //

erase_rectangle_tiles_on_mouse :: proc(l: ^TileLayer)
{
    tools.rectangle.selection.end = get_mouse_tile_pos()
    swap_selection_boundaries_if_needed(&tools.rectangle.selection)

    using tools.rectangle.selection
    for y in start.y..=end.y {
        for x in start.x..=end.x {
            pos := [2]int{x, y}
            delete_key(&l.tiles, pos)
        }
    }
    shrink_map(&l.tiles)
}

// -------------------------------------------------------------------------------- //

draw_tile :: proc(spritesheets: SpriteSheets, tile_info: TileInfo, x, y: f32, alpha := f32(1), outline := f32(0))
{
    dst := rl.Rectangle{x, y, editor.tile_w * SCALE, editor.tile_h * SCALE}
    if alpha > 0 {
        src := rl.Rectangle{f32(tile_info.i) * editor.tile_w, f32(tile_info.j) * editor.tile_h, editor.tile_w, editor.tile_h}
        rl.DrawTexturePro(spritesheets[tile_info.texture_index].texture, src, dst, {0, 0}, 0, rl.ColorAlpha(rl.WHITE, alpha))
    }
    if outline > 0 do rl.DrawRectangleLinesEx(dst, 2/editor.cam.zoom, rl.ColorAlpha(PALETTE07, outline))
}

// -------------------------------------------------------------------------------- //

draw_selected_tile :: proc()
{
    info := get_selected_tile_info()
    draw_tile(editor.spritesheets, info, f32(mouse.tiled.x), f32(mouse.tiled.y), 0.4, 0.8)
}

draw_selected_tile_outline_only :: proc()
{
    info := get_selected_tile_info()
    draw_tile(editor.spritesheets, info, f32(mouse.tiled.x), f32(mouse.tiled.y), 0.0, 0.8)
}

// -------------------------------------------------------------------------------- //

draw_place_rectangle_tiles_on_mouse :: proc()
{
    tools.rectangle.selection.end = get_mouse_tile_pos()
    swap_selection_boundaries_if_needed(&tools.rectangle.selection)

    info := get_selected_tile_info()

    using tools.rectangle.selection
    for y in start.y..=end.y {
        for x in start.x..=end.x {
            draw_tile(editor.spritesheets, info, f32(x) * editor.tile_w * SCALE, f32(y) * editor.tile_h * SCALE, 0.4)
        }
    }

    rect := get_selection_rect(tools.rectangle.selection)
    rl.DrawRectangleLinesEx(rect, 1/editor.cam.zoom, rl.ColorAlpha(PALETTE07, 0.4))
}

// -------------------------------------------------------------------------------- //

draw_erase_rectangle_tiles_on_mouse :: proc()
{
    tools.rectangle.selection.end = get_mouse_tile_pos()
    swap_selection_boundaries_if_needed(&tools.rectangle.selection)

    using tools.rectangle.selection
    for y in start.y..=end.y {
        for x in start.x..=end.x {
            pos := rl.Vector2{f32(x) * editor.tile_w, f32(y) * editor.tile_h} * SCALE
            rl.DrawLineEx(
                pos,
                pos + {editor.tile_w, editor.tile_h} * SCALE,
                1/editor.cam.zoom,
                rl.ColorAlpha(rl.RED, 0.8))
        }
    }

    rect := get_selection_rect(tools.rectangle.selection)
    rl.DrawRectangleRec(rect, rl.ColorAlpha(PALETTE00, 0.4))
    rl.DrawRectangleLinesEx(rect, 2/editor.cam.zoom, rl.RED)
}

// -------------------------------------------------------------------------------- //

place_tile_on_mouse :: proc(l: ^TileLayer)
{
    pos := get_mouse_tile_pos()
    l.tiles[pos] = get_selected_tile_info()
    update_level_boundaries(&editor.x_boundary, &editor.y_boundary, pos)
}

// -------------------------------------------------------------------------------- //

erase_tile_on_mouse :: proc(l: ^TileLayer)
{
    pos := get_mouse_tile_pos()
    delete_key(&l.tiles, pos)
}

// -------------------------------------------------------------------------------- //

layer_cut :: proc(from, to: ^TileLayer, selection: TileSelection)
{
    selection := selection
    using selection
    swap_selection_boundaries_if_needed(&selection)

    for y in start.y..=end.y {
        for x in start.x..=end.x {
            pos := [2]int{x, y}
            if pos in from.tiles do to.tiles[pos] = from.tiles[pos]
            delete_key(&from.tiles, pos)
        }
    }
}

// -------------------------------------------------------------------------------- //

layer_copy :: proc(from, to: ^TileLayer, selection: TileSelection)
{
    selection := selection
    using selection
    swap_selection_boundaries_if_needed(&selection)

    for y in start.y..=end.y {
        for x in start.x..=end.x {
            pos := [2]int{x, y}
            if pos in from.tiles do to.tiles[pos] = from.tiles[pos]
        }
    }
}

// -------------------------------------------------------------------------------- //

layer_paste :: proc(from: TileLayer, to: ^TileLayer, offset: [2]int = {0, 0})
{
    for pos, info in from.tiles {
        new_pos := pos + offset
        to.tiles[new_pos] = from.tiles[pos]
        update_level_boundaries(&editor.x_boundary, &editor.y_boundary, new_pos)
    }
}

// -------------------------------------------------------------------------------- //

insert_row_in_layer :: proc(l: ^TileLayer)
{
    from := get_mouse_tile_pos().x

    selection := TileSelection{{from, editor.y_boundary.min}, {editor.x_boundary.max, editor.y_boundary.max}}
    layer_cut(l, &tools.temp_layer, selection)
    editor.x_boundary.max += 1

    for pos, info in tools.temp_layer.tiles {
        new_pos := pos + {1, 0}
        if pos in tools.temp_layer.tiles do l.tiles[new_pos] = tools.temp_layer.tiles[pos]
        update_level_boundaries(&editor.x_boundary, &editor.y_boundary, pos)
    }
    clear_map(&tools.temp_layer.tiles)
}

// -------------------------------------------------------------------------------- //

remove_row_in_layer :: proc(l: ^TileLayer)
{
    from := get_mouse_tile_pos().x

    selection := TileSelection{{from, editor.y_boundary.min}, {editor.x_boundary.max, editor.y_boundary.max}}
    layer_cut(l, &tools.temp_layer, selection)
    editor.x_boundary.max -= 1

    for pos, info in tools.temp_layer.tiles {
        new_pos := pos - {1, 0}
        if pos in tools.temp_layer.tiles do l.tiles[new_pos] = tools.temp_layer.tiles[pos]
        update_level_boundaries(&editor.x_boundary, &editor.y_boundary, pos)
    }
    clear_map(&tools.temp_layer.tiles)
}