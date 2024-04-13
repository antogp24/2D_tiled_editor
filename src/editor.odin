package editor

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

editor_update :: proc()
{
    // Getting the mouse position snapped to the tile dimentions.
    mouse.tiled.x = int(math.floor(mouse.world.x/(editor.tile_w*SCALE))*editor.tile_w*SCALE)
    mouse.tiled.y = int(math.floor(mouse.world.y/(editor.tile_h*SCALE))*editor.tile_h*SCALE)

    // Interacting with the textboxes.
    textbox_update(&editor.save_textbox)
    textbox_update(&editor.tile_w_textbox)
    textbox_update(&editor.tile_h_textbox)

    // Interacting with the checkboxes.
    for &checkbox, index in editor.tileflags_checkboxes {
        padding :: 10
        tr := get_tile_selector_rect()
        checkbox.x = tr.x + tr.width/2 - (checkbox.width + 10 + cast(f32)len(checkbox.text)*checkbox.scale*editor.font.w)/2
        checkbox.y = screen.h - PROPERTIES_H + f32(index) * (checkbox.height + padding) + 22

        updated := checkbox_update(&checkbox)

        if updated && checkbox.checked {
            editor.flags += {TileFlag(index)}
        } else if updated && !checkbox.checked {
            editor.flags -= {TileFlag(index)}
        }
    }

    // Interacting with the autotile interface.
    if editor.current_tool == Tool.Rectangle {
        container := get_tile_selector_rect()
        whole_thing_w := editor.autotile.checkbox.width + cast(f32)len(editor.autotile.checkbox.text) * editor.font.w * editor.autotile.checkbox.scale + 10
        editor.autotile.checkbox.x = container.x + container.width/2 - whole_thing_w/2
        editor.autotile.checkbox.y = container.y + container.height + 10
        updated := checkbox_update(&editor.autotile.checkbox)
    }
    autotile_ui_update()

    // Using the mouse to move the split.
    if is_mouse_on_split() && rl.IsMouseButtonPressed(.LEFT) {
        editor.holding_split = true
    }

    if rl.IsMouseButtonUp(.LEFT) && editor.holding_split {
        editor.holding_split = false
    }

    if editor.holding_split && mouse.x > editor.min_split_x && mouse.x < screen.w {
        editor.split_x = mouse.x
    }

    // Selecting the active tile with the mouse.
    if is_mouse_on_tile_selector() && rl.IsMouseButtonDown(.LEFT) {
        editor.selected_tile = get_tile_selector_mouse_tile()
    }
    if editor.selected_tile.x > int(editor.split_x / (editor.tile_w * SCALE)) - 1 {
        editor.selected_tile.x = int(editor.split_x / (editor.tile_w * SCALE))
    }

    // Moving the camera with the mouse.
    if rl.IsMouseButtonDown(.MIDDLE) {
        delta := rl.GetMouseDelta()
        delta *= -(time.delta * 60) / editor.cam.zoom
        editor.cam.target = editor.cam.target + delta
    }
    if mouse.wheel != 0 {
        editor.cam.zoom += time.delta * mouse.wheel * 1
        editor.cam.zoom = clamp(editor.cam.zoom, 0.1, 1.0)
    }
    editor.cam.offset = {
        editor.split_x + (screen.w - editor.split_x)/2,
        TOOLBAR_H + LAYERS_UI_H + (screen.h - TOOLBAR_H)/2
    }

    // Interacting with tools.
    tools_update()

    // Changing the current spritesheet or image.
    if rl.IsKeyDown(.LEFT_SHIFT) && rl.IsKeyPressed(.LEFT) {
        editor.current_spritesheet -= 1
        editor.current_spritesheet %%= len(editor.spritesheets)
        editor.selected_tile = {0, 0}
    }
    if rl.IsKeyDown(.LEFT_SHIFT) && rl.IsKeyPressed(.RIGHT) {
        editor.current_spritesheet += 1
        editor.current_spritesheet %%= len(editor.spritesheets)
        editor.selected_tile = {0, 0}
    }

    // Changing the selected tile with the mouse.
    if rl.IsKeyDown(.LEFT_ALT) && rl.IsKeyPressed(.LEFT) {
        editor.selected_tile.x -= 1
        clamp_selected_tiles()
    }
    if rl.IsKeyDown(.LEFT_ALT) && rl.IsKeyPressed(.RIGHT) {
        editor.selected_tile.x += 1
        clamp_selected_tiles()
    }
    if rl.IsKeyDown(.LEFT_ALT) && rl.IsKeyPressed(.UP) {
        editor.selected_tile.y -= 1
        clamp_selected_tiles()
    }
    if rl.IsKeyDown(.LEFT_ALT) && rl.IsKeyPressed(.DOWN) {
        editor.selected_tile.y += 1
        clamp_selected_tiles()
    }
}

editor_draw :: proc(tool_icons: []rl.Texture2D)
{
    // Drawing all the tiles in the editor.
    for &layer in editor.tile_layers {
        if layer.visible {
            for pos, info in layer.tiles {
                draw_tile(editor.spritesheets, info, f32(pos.x) * editor.tile_w * SCALE, f32(pos.y) * editor.tile_h * SCALE)
            }
        }
    }

    if !editor.level_loader.active do tools_draw()

    if !editor.level_loader.active && is_mouse_on_editor() {
        // Drawing the selected tile in the split above.
        #partial switch editor.current_tool {
            case Tool.Rectangle: fallthrough
            case Tool.Brush: draw_selected_tile()
            case: draw_selected_tile_outline_only()
        }
        rl.DrawTextureEx(tool_icons[int(editor.current_tool)], mouse.world, 0, 2/editor.cam.zoom, rl.WHITE)
    }
}

editor_draw_HUD :: proc(tool_icons: []rl.Texture2D)
{
    // Drawing the toolbar.
    draw_toolbar(tool_icons)

    // Drawing the layers user interface.
    layers_ui_draw()

    // Drawing rectangle to prevent seeing stuff from the editor.
    rl.DrawRectangleRec({0, TOOLBAR_H, editor.split_x, screen.h - TOOLBAR_H}, PALETTE01)
    draw_tile_selector()
    
    // Drawing the split line.
    rl.DrawLineEx({editor.split_x, TOOLBAR_H}, {editor.split_x, screen.h}, SPLIT_THICK, PALETTE04)
    rl.DrawRectangleLinesEx({editor.split_x - SPLIT_THICK/2, TOOLBAR_H-1, SPLIT_THICK, screen.h - TOOLBAR_H + 1}, 1, PALETTE00)

    // Drawing the current grid position of the cursor.
    draw_mouse_grid_pos()

    // Drawing the cursor.
    if !is_mouse_on_editor() {
        rl.DrawTextureEx(editor.cursor_icon, mouse.pos, 0, 2, rl.WHITE)
    }

    // Drawing the level loader.
    if editor.level_loader.active {
        level_loader_draw(&editor.level_loader)
    }
}