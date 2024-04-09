package editor

import "core:os"
import "core:strings"
import "core:reflect"
import rl "vendor:raylib"

// -------------------------------------------------------------------------------- //

is_mouse_on_toolbar :: proc() -> bool
{
    return mouse.y < TOOLBAR_H
}

is_mouse_on_editor :: proc() -> bool
{
    return mouse.y > TOOLBAR_H && mouse.x > editor.split_x
}

is_mouse_on_split :: proc() -> bool
{
    return mouse.x >= editor.split_x - SPLIT_THICK/2 && mouse.x <= editor.split_x + SPLIT_THICK/2
}

is_mouse_on_tile_selector :: proc() -> bool
{
    return rl.CheckCollisionPointRec(mouse.pos, get_tile_selector_rect())
}

// -------------------------------------------------------------------------------- //

get_tile_selector_rect :: proc() -> rl.Rectangle
{
    texture_w := SCALE * cast(f32)editor.spritesheets[editor.current_spritesheet].texture.width
    texture_h := SCALE * cast(f32)editor.spritesheets[editor.current_spritesheet].texture.height

    return rl.Rectangle{
        (editor.split_x - SPLIT_THICK/2)/2 - texture_w/2,
        TOOLBAR_H + SPLIT_OFFSET + 10,
        texture_w,
        texture_h,
    }
}


// -------------------------------------------------------------------------------- //

draw_adjust_tile_text :: proc(font: ^FontImage, textfontsize: f32, t0, t1: ^TextBox)
{
    OFFSET :: 20
    text_w_len := cast(f32)len("w:")
    text_h_len := cast(f32)len("h:")

    text_w_x := f32(0)
    text_h_x := (text_w_len * font.w * textfontsize) + t0.w + OFFSET
    text_y := TOOLBAR_H + SPLIT_OFFSET/2 - (font.h * textfontsize)/2
    textbox_y := TOOLBAR_H + SPLIT_OFFSET/2 - t0.h/2

    // centering everything.
    whole_thing_w := text_h_x + (text_h_len * font.w * textfontsize) + t1.w
    text_w_x += editor.split_x/2 - whole_thing_w/2
    text_h_x += editor.split_x/2 - whole_thing_w/2

    t0.x = text_w_x + text_w_len * font.w * textfontsize
    t0.y = textbox_y

    t1.x = text_h_x + text_h_len * font.w * textfontsize
    t1.y = textbox_y

    font_image_draw(font, textfontsize, "w:", text_w_x, text_y, PALETTE07)
    draw_textbox(t0)
    font_image_draw(font, textfontsize, "h:", text_h_x, text_y, PALETTE07)
    draw_textbox(t1)
}

// -------------------------------------------------------------------------------- //

draw_toolbar :: proc(tool_icons: []rl.Texture2D)
{
    rl.DrawRectangleRec({0, 0, screen.w, TOOLBAR_H}, PALETTE01)
    draw_textbox(&editor.save_textbox)

    icons_scale :: 2
    icons_padding :: 10

    icons_w := cast(f32)tool_icons[0].width * icons_scale
    icons_h := cast(f32)tool_icons[0].height * icons_scale
    icons_offset_x := editor.save_textbox.x + editor.save_textbox.w + 20

    selected_rect := rl.Rectangle{
        icons_offset_x + f32(editor.current_tool) * (icons_w + icons_padding),
        TOOLBAR_H/2 - icons_h/2,
        icons_w,
        icons_h,
    }
    rl.DrawRectangleRounded(selected_rect, 0.25, 10, PALETTE04)

    for i in 0..<len(tool_icons) {
        rect := rl.Rectangle{
            f32(i) * (icons_w + icons_padding) + icons_offset_x,
            TOOLBAR_H/2 - icons_h/2,
            icons_w,
            icons_h,
        }
        if rl.IsMouseButtonDown(.LEFT) &&
           rl.CheckCollisionPointRec(mouse.pos, rect) {
            editor.current_tool = Tool(i)
        }
        rl.DrawTextureEx(tool_icons[i], {rect.x, rect.y}, 0, icons_scale, rl.WHITE)
    }
}

// -------------------------------------------------------------------------------- //

draw_mouse_grid_pos :: proc()
{
    scale :: 2
    x := editor.split_x + SPLIT_THICK/2 + 10
    y := screen.h - editor.font.h*scale - 10

    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)
    strings.write_string(&builder, "(x: ")
    strings.write_int(&builder, mouse.tiled.x / int(editor.tile_w * SCALE))
    strings.write_string(&builder, ", y: ")
    strings.write_int(&builder, mouse.tiled.y / int(editor.tile_h * SCALE))
    strings.write_byte(&builder, ')')

    alpha: f32 = 1 if is_mouse_on_editor() else 0.4
    font_image_draw(&editor.font, scale, strings.to_string(builder), x, y, rl.ColorAlpha(PALETTE07, alpha))
}

// -------------------------------------------------------------------------------- //

draw_tile_selector :: proc()
{
    rect := get_tile_selector_rect()
    sx := f32(editor.selected_tile.x)
    sy := f32(editor.selected_tile.y)

    t0, t1 := &editor.tile_w_textbox, &editor.tile_h_textbox

    rl.DrawRectangleRec({0, TOOLBAR_H, editor.split_x, SPLIT_OFFSET}, PALETTE02)

    draw_adjust_tile_text(&editor.font, 2, t0, t1)

    rl.DrawTextureEx(editor.spritesheets[editor.current_spritesheet].texture, {rect.x, rect.y}, 0, SCALE, rl.WHITE)

    // Drawing the grid.
    {
        // horizontal lines.
        for i in 0..=int(rect.height / (editor.tile_h*SCALE)) {
            startpoint := rl.Vector2{rect.x, rect.y + f32(i)*editor.tile_h*SCALE}
            endpoint := startpoint + {rect.width, 0}
            rl.DrawLineV(startpoint, endpoint, PALETTE05)
        }

        // vertical lines.
        for i in 0..=int(rect.width / (editor.tile_w*SCALE)) {
            startpoint := rl.Vector2{rect.x + f32(i)*editor.tile_w*SCALE, rect.y}
            endpoint := startpoint + {0, rect.height}
            rl.DrawLineV(startpoint, endpoint, PALETTE05)
        }
    }

    // Drawing the dim rectangles.
    {
        alpha :: 0.4
        tw := editor.tile_w * SCALE
        th := editor.tile_h * SCALE

        r1 := rl.Rectangle{rect.x, rect.y, sx * tw, rect.height}
        r2 := rl.Rectangle{rect.x + (sx + 1) * tw, rect.y, rect.width - (sx + 1) * tw, rect.height}
        r3 := rl.Rectangle{rect.x + sx * tw, rect.y, tw, sy * th}
        r4 := rl.Rectangle{rect.x + sx * tw, rect.y + (sy + 1) * th, tw, rect.height - (sy + 1) * th}

        rl.DrawRectangleRec(r1, rl.ColorAlpha(PALETTE00, alpha))
        rl.DrawRectangleRec(r2, rl.ColorAlpha(PALETTE00, alpha))
        rl.DrawRectangleRec(r3, rl.ColorAlpha(PALETTE00, alpha))
        rl.DrawRectangleRec(r4, rl.ColorAlpha(PALETTE00, alpha))
    }


    // Drawing the selected tile's outline.
    rl.DrawRectangleLinesEx(
        {
            rect.x + sx*editor.tile_w*SCALE,
            rect.y + sy*editor.tile_h*SCALE,
            editor.tile_w*SCALE,
            editor.tile_h*SCALE
        },
        4,
        PALETTE07,
    )

    rl.DrawRectangleRec({0, screen.h-PROPERTIES_H, editor.split_x, PROPERTIES_H}, PALETTE02)
    for &checkbox in editor.tileflags_checkboxes {
        checkbox_draw(&checkbox)
    }
}