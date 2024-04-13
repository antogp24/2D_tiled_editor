package editor

import "core:strings"
import "core:strconv"
import rl "vendor:raylib"

LAYERS_UI_H :: 80

is_mouse_on_layers_ui :: proc() -> bool
{
    rect := layers_ui_get_container()
    return rl.CheckCollisionPointRec(mouse.pos, rect)
}

layers_ui_get_container :: proc() -> rl.Rectangle
{
    return rl.Rectangle{
        editor.split_x + SPLIT_THICK/2,
        TOOLBAR_H,
        screen.w - (editor.split_x + SPLIT_THICK/2),
        LAYERS_UI_H,
    }
}

layers_ui_draw :: proc()
{
    container := layers_ui_get_container()
    rl.DrawRectangleRec(container, PALETTE03)

    layers_text :: "layers"
    layers_text_len :: len(layers_text)
    layers_text_scale :: 2

    layers_text_pos := rl.Vector2{
        container.x + 10,
        container.y + container.height/2 - layers_text_scale * editor.font.h/2,
    }
    font_image_draw(&editor.font, layers_text_scale, layers_text, layers_text_pos.x, layers_text_pos.y, PALETTE07)

    scale :: 4
    padding :: 10

    max_rect_w := cast(f32)len_int(len(editor.tile_layers)-1)

    for i in 0..<len(editor.tile_layers) {
        alpha: f32 = 1 if i == editor.current_layer else 0.6
        color := PALETTE05 if i == editor.current_layer else PALETTE04

        rect := rl.Rectangle{
            layers_text_pos.x + layers_text_len * editor.font.w * layers_text_scale + padding,
            container.y,
            max_rect_w * editor.font.w * scale + scale * 2,
            editor.font.h * scale + padding,
        }
        rect.x += f32(i) * (rect.width + padding)
        rect.y += container.height - rect.height - padding/2
        rl.DrawRectangleRec(rect, rl.ColorAlpha(color, alpha))
        rl.DrawRectangleLinesEx(rect, 1, rl.ColorAlpha(PALETTE00, alpha))

        if rl.IsMouseButtonDown(.LEFT) && rl.CheckCollisionPointRec(mouse.pos, rect) {
            editor.current_layer = i
        }

        text_pos := rl.Vector2{
            rect.x + rect.width/2 - scale * editor.font.w*f32(len_int(i))/2,
            rect.y + rect.height/2 - scale * editor.font.h/2,
        }
        buf: [32]byte
        strconv.itoa(buf[:], i)
        number_text := strings.string_from_null_terminated_ptr(raw_data(buf[:]), len(buf))
        font_image_draw(&editor.font, scale, number_text, text_pos.x, text_pos.y, rl.ColorAlpha(PALETTE07, alpha))

        eye_scale :: 2
        eye_rect := rl.Rectangle{
            rect.x + rect.width/2,
            rect.y,
            cast(f32)editor.eye_opened.width * eye_scale,
            cast(f32)editor.eye_opened.height * eye_scale,
        }
        eye_rect.x -= eye_rect.width/2
        eye_rect.y -= eye_rect.height + padding/2
        if editor.tile_layers[i].visible {
            rl.DrawTextureEx(editor.eye_opened, {eye_rect.x, eye_rect.y}, 0, eye_scale, rl.WHITE)
        } else {
            rl.DrawTextureEx(editor.eye_closed, {eye_rect.x, eye_rect.y}, 0, eye_scale, rl.WHITE)
        }

        if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse.pos, eye_rect) {
            editor.tile_layers[i].visible = !editor.tile_layers[i].visible
        }
    }

    icon_w := cast(f32)editor.plus_icon.width * scale
    icon_h := cast(f32)editor.plus_icon.height * scale

    minus_pos := rl.Vector2{
        container.x + container.width - icon_w - padding,
        container.y + container.height/2 - icon_h/2,
    }
    plus_pos: rl.Vector2 = minus_pos - {icon_w + padding, 0}

    plus_rect := rl.Rectangle{plus_pos.x, plus_pos.y, icon_w, icon_h}
    minus_rect := rl.Rectangle{minus_pos.x, minus_pos.y, icon_w, icon_h}

    rl.DrawTextureEx(editor.plus_icon, plus_pos, 0, scale, rl.WHITE)
    rl.DrawRectangleLinesEx(plus_rect, 1, PALETTE00)
    rl.DrawTextureEx(editor.minus_icon, minus_pos, 0, scale, rl.WHITE)
    rl.DrawRectangleLinesEx(minus_rect, 1, PALETTE00)

    if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse.pos, plus_rect) {
        editor.current_layer += 1
        inject_at(&editor.tile_layers, editor.current_layer, TileLayer{visible=true})
        editor.current_layer = clamp(editor.current_layer, 0, len(editor.tile_layers))
    }
    if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse.pos, minus_rect) && len(editor.tile_layers) - 1 > 0 {
        ordered_remove(&editor.tile_layers, editor.current_layer)
        editor.current_layer -= 1
        editor.current_layer = clamp(editor.current_layer, 0, len(editor.tile_layers))
    }
}