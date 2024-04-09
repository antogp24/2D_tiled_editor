package editor

import "core:fmt"
import "core:math"
import rl "vendor:raylib"


// Globals
// -------------------------------------------------------------------------------- //

PALETTE00 := color_from_hex(0x040c06ff)
PALETTE01 := color_from_hex(0x112318ff)
PALETTE02 := color_from_hex(0x1e3a29ff)
PALETTE03 := color_from_hex(0x305d42ff)
PALETTE04 := color_from_hex(0x4d8061ff)
PALETTE05 := color_from_hex(0x89a257ff)
PALETTE06 := color_from_hex(0xbedc7fff)
PALETTE07 := color_from_hex(0xeeffccff)
// https://lospec.com/palette-list/ammo-8

TOOLBAR_H :: 60
PROPERTIES_H :: 120
SPLIT_THICK :: 12
SPLIT_OFFSET :: 60
SCALE :: 10

State :: struct {
    cursor_icon: rl.Texture2D,
    check_icon: rl.Texture2D,
    tileflags_checkboxes: [TileFlag.Count]CheckBox,

    flags: TileFlags,
    selected_tile: [2]int,

    save_textbox, tile_w_textbox, tile_h_textbox: TextBox,

    x_boundary, y_boundary: LevelBoundaries,

    tile_layers: [dynamic]TileLayer,
    current_layer: int,
    current_tool: Tool,

    spritesheets: SpriteSheets,
    current_spritesheet: int,

    level_loader: LevelLoader,

    font: FontImage,

    tile_w, tile_h: f32,

    holding_split: bool,
    min_split_x, split_x: f32,

    cam: rl.Camera2D,
}

Screen :: struct {
    w, h: f32,
}

Time :: struct {
    now: f32,
    delta: f32,
}

Mouse :: struct {
    using pos: rl.Vector2,
    world: rl.Vector2,
    wheel: f32,
    tiled: [2]int,
}

editor: State
time: Time
screen: Screen
mouse: Mouse

// Entry point.
// -------------------------------------------------------------------------------- //
main :: proc()
{
    rl.SetTraceLogLevel(.NONE)
    rl.SetTargetFPS(60)
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_MAXIMIZED})
    rl.InitWindow(640, 480, "Editor")
    defer rl.CloseWindow()
    rl.SetExitKey(.KEY_NULL)

    rl.HideCursor()
    rl.MaximizeWindow()

    screen.w = cast(f32)rl.GetScreenWidth()
    screen.h = cast(f32)rl.GetScreenHeight()

    tool_icons := [?]rl.Texture2D {
        bake_texture("icons/brush.png"),
        bake_texture("icons/picker.png"),
        bake_texture("icons/rectangle.png"),
        bake_texture("icons/copy_paste.png"),
        bake_texture("icons/glove.png"),
        bake_texture("icons/insert_column.png"),
    }
    defer for i in 0..<len(tool_icons) do rl.UnloadTexture(tool_icons[i])

    editor.cursor_icon = bake_texture("icons/cursor.png")
    defer rl.UnloadTexture(editor.cursor_icon)

    editor.check_icon = bake_texture("icons/check.png")
    defer rl.UnloadTexture(editor.check_icon)

    editor.font = font_image_load("fonts/font.png", w=6, h=9, start=32)
    defer font_image_unload(&editor.font)

    level_loader_init(&editor.level_loader)
    defer level_loader_delete(&editor.level_loader)

    editor.save_textbox = textbox_new(fontsize=2, text="level_0", N=15, extra_w=10, extra_h=10)
    editor.save_textbox.x = 10
    editor.save_textbox.y = TOOLBAR_H/2 - editor.save_textbox.h/2

    editor.tile_w_textbox = textbox_new(fontsize=2, text="5", N=2, extra_w=20, extra_h=20, numbers_only=true, associated_value=&editor.tile_w)
    editor.tile_h_textbox = textbox_new(fontsize=2, text="5", N=2, extra_w=20, extra_h=20, numbers_only=true, associated_value=&editor.tile_h)

    editor.spritesheets = spritesheets_load("pngs")
    defer spritesheets_unload(editor.spritesheets)

    editor.cam.offset = {editor.split_x + (screen.w - editor.split_x)/2, TOOLBAR_H + (screen.h - TOOLBAR_H)/2}
    editor.cam.zoom = 1.0

    editor.current_tool = Tool.Brush
    editor.flags = {.Collideable}
    init_tileflag_checkboxes()

    if len(editor.tile_layers) == 0 do append(&editor.tile_layers, TileLayer{})

    // Game loop.
    // -------------------------------------------------------------------------------- //
    for !rl.WindowShouldClose() {
        time.now = cast(f32)rl.GetTime()
        time.delta = rl.GetFrameTime()
        screen.w = cast(f32)rl.GetScreenWidth()
        screen.h = cast(f32)rl.GetScreenHeight()
        mouse.wheel = rl.GetMouseWheelMove()
        mouse.pos = rl.GetMousePosition()
        mouse.world = rl.GetScreenToWorld2D(mouse.pos, editor.cam)

        if !editor.level_loader.active {
            editor_update()
        }
        if editor.level_loader.active {
            level_loader_update(&editor.level_loader)
        }

        // Toggling the level loader.
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.L) {
            level_loader_toggle(&editor.level_loader)
        }
        if rl.IsKeyPressed(.ESCAPE) do editor.level_loader.active = false

        // Saving.
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.S) {
            save_data()
        }

        // Rendering.
        // -------------------------------------------------------------------------------- //
        rl.ClearBackground(PALETTE00)
        rl.BeginDrawing()

            rl.BeginMode2D(editor.cam)
                editor_draw(tool_icons[:])
            rl.EndMode2D()

            editor_draw_HUD(tool_icons[:])

        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    when AUTO_SAVE do save_data()
}
