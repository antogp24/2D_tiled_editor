package editor

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

Tool :: enum {
    Brush,
    Picker,
    Rectangle,
    Copy_Paste,
    Move,
    Column,
    Count,
}

ToolState :: struct {
    temp_layer: TileLayer,

    rectangle: struct {
        selection: TileSelection,
        erasing, placing: bool,
    },
    move: struct {
        selection: TileSelection,
        offset: struct {start, end: [2]int},
        initial: struct {start, end: [2]int},
        active, moving, placing: bool,
    },
    copy: struct {
        layer: TileLayer,
        selection: TileSelection,
        offset: struct {start, end: [2]int},
        active, placing: bool,
    },
}

tools: ToolState

@(private="file")
paste_from_temp_layer :: proc(l: ^TileLayer)
{
    offset := tools.move.offset.end - tools.move.offset.start
    for pos, info in tools.temp_layer.tiles {
        new_pos := pos + offset
        if pos in tools.temp_layer.tiles do l.tiles[new_pos] = tools.temp_layer.tiles[pos]
        update_level_boundaries(&editor.x_boundary, &editor.y_boundary, new_pos)
    }
    clear_map(&tools.temp_layer.tiles)
}


tools_update :: proc()
{
    // Switching between tools.
    for i in 0..<int(Tool.Count) {
        key := rl.KeyboardKey(int(rl.KeyboardKey.ONE) + i)
        if rl.IsKeyDown(.LEFT_ALT) && rl.IsKeyDown(key) {
            editor.current_tool = Tool(i)
        }
    }

    // Quitting the selections.
    if rl.IsKeyPressed(.ESCAPE) ||
        (rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.D))
    {
        tools.move.active = false
        tools.copy.active = false
    }

    // Actions based on the current tool.

    #partial switch editor.current_tool {

        case Tool.Brush: {

            // Placing tiles in the editor.
            if is_mouse_on_editor() && 
                rl.IsMouseButtonDown(.LEFT)
            {
                place_tile_on_mouse(&editor.tile_layers[editor.current_layer])
            }

            // Deleting tiles in the editor.
            if is_mouse_on_editor() &&
                rl.IsMouseButtonDown(.RIGHT)
            {
                erase_tile_on_mouse(&editor.tile_layers[editor.current_layer])
            }
        }

        case Tool.Picker: {
            if rl.IsMouseButtonPressed(.LEFT) {
                pos := get_mouse_tile_pos()
                if pos in editor.tile_layers[editor.current_layer].tiles {
                    info := editor.tile_layers[editor.current_layer].tiles[pos]
                    editor.selected_tile = {info.i, info.j}
                    editor.current_spritesheet = info.texture_index
                    editor.flags = int_to_flags(info.flags)
                    editor.current_tool = Tool.Brush
                }
            }
        }

        case Tool.Rectangle: {
            using tools.rectangle

            // Placing a rectangle of tiles in the editor.
            if is_mouse_on_editor() &&
                rl.IsMouseButtonPressed(.LEFT)
            {
                placing = true
                selection.start = get_mouse_tile_pos()
            }

            if rl.IsMouseButtonUp(.LEFT) && placing {
                place_rectangle_tiles_on_mouse(&editor.tile_layers[editor.current_layer])
                placing = false
            }

            // Deleting a rectangle of tiles in the editor.
            if is_mouse_on_editor() &&
                rl.IsMouseButtonPressed(.RIGHT)
            {
                erasing = true
                selection.start = get_mouse_tile_pos()
            }

            if rl.IsMouseButtonUp(.RIGHT) && erasing {
                erase_rectangle_tiles_on_mouse(&editor.tile_layers[editor.current_layer])
                erasing = false
            }
        }

        case Tool.Copy_Paste: {
            using tools.copy

            // Placing a selection in the editor.
            if is_mouse_on_editor() && rl.IsMouseButtonPressed(.LEFT)
            {
                placing = true
                selection.start = get_mouse_tile_pos()
                active = true
            }

            if placing {
                selection.end = get_mouse_tile_pos()
            }

            if rl.IsMouseButtonUp(.LEFT) && placing {
                placing = false
            }

            // Copying the selection in the editor.
            if active && rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.C) {
                offset.start = selection.start
                clear_map(&layer.tiles)
                layer_copy(&editor.tile_layers[editor.current_layer], &layer, selection)
            }

            // Cutting the selection in the editor.
            if active && rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.X) {
                offset.start = selection.start
                clear_map(&layer.tiles)
                layer_cut(&editor.tile_layers[editor.current_layer], &layer, selection)
            }

            // Pasting the selection in the editor.
            if active && rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.V) {
                offset.end = selection.start
                off := offset.end - offset.start
                layer_paste(layer, &editor.tile_layers[editor.current_layer], off)
                active = false
            }
        }

        case Tool.Move: {
            using tools.move

            // Placing a moveable selection in the editor.
            if is_mouse_on_editor() &&
                rl.IsMouseButtonPressed(.LEFT)
            {
                placing = true
                selection.start = get_mouse_tile_pos()
                initial.start = selection.start
                active = true
            }

            if placing {
                selection.end = get_mouse_tile_pos()
                initial.end = selection.end
            }

            if rl.IsMouseButtonUp(.LEFT) && placing {
                placing = false
            }

            // Moving the selection in the editor.
            if is_mouse_on_editor() &&
               active && 
               rl.IsMouseButtonPressed(.RIGHT)
            {
                moving = true
                offset.start = get_mouse_tile_pos()
                layer_cut(&editor.tile_layers[editor.current_layer], &tools.temp_layer, selection)
            }

            if rl.IsMouseButtonUp(.RIGHT) && moving {
                initial.start = selection.start
                initial.end = selection.end
                paste_from_temp_layer(&editor.tile_layers[editor.current_layer])
                moving = false
            }

            if rl.IsMouseButtonDown(.RIGHT) {
                offset.end = get_mouse_tile_pos()
                offset := offset.end - offset.start
                selection.start = initial.start + offset
                selection.end = initial.end + offset
            }
        }

        case Tool.Column: {
            if is_mouse_on_editor() {
                if rl.IsMouseButtonPressed(.LEFT) {
                    insert_row_in_layer(&editor.tile_layers[editor.current_layer])
                }
                if rl.IsMouseButtonPressed(.RIGHT) {
                    remove_row_in_layer(&editor.tile_layers[editor.current_layer])
                }
            }
        }
    }
}

tools_draw :: proc()
{
    // Drawing the rectangle tool.
    {
        using tools.rectangle
        if placing do draw_place_rectangle_tiles_on_mouse()
        else if erasing do draw_erase_rectangle_tiles_on_mouse()
    }

    // Drawing the copy paste tool.
    if tools.copy.active {
        selection_draw(tools.copy.selection)
    } 

    // Drawing the move tool.
    if tools.move.active {
        offset := tools.move.offset.end - tools.move.offset.start
        for pos, info in tools.temp_layer.tiles {
            v := linalg.array_cast(pos + offset, f32) * {editor.tile_w, editor.tile_h} * SCALE
            draw_tile(editor.spritesheets, info, v.x, v.y, 0.8)
        }
        selection_draw(tools.move.selection)
    }


    // Drawing the insert row tool line.
    if editor.current_tool == Tool.Column && is_mouse_on_editor() {
        start: rl.Vector2 = {cast(f32)mouse.tiled.x, cast(f32)mouse.tiled.y} + {0, screen.h/editor.cam.zoom}
        end  : rl.Vector2 = {cast(f32)mouse.tiled.x, cast(f32)mouse.tiled.y} - {0, screen.h/editor.cam.zoom}
        rl.DrawLineEx(start, end, 1/editor.cam.zoom, PALETTE07)
    }
}