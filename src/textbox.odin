package editor

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:math"
import "core:mem"

import rl "vendor:raylib"

TextBox :: struct {
    text: [dynamic]u8,
    cursor: int,
    w, h: f32,
    x, y: f32,
    extra_w, extra_h: int,
    fontsize: f32,
    active: bool,

    is_numbers_only: bool,
    associated_value: ^f32,
}

@(private)
square_wave :: proc(x, frequency: f32) -> bool
{
    result := math.ceil(math.sin(x * math.PI / frequency))
    return cast(bool)cast(int)result
}

textbox_new :: proc(
    $fontsize: f32,
    $text: string,
    $N: int,
    extra_w: int = 0,
    extra_h: int = 0,
    numbers_only: bool = false,
    associated_value: ^f32 = nil) -> (t: TextBox)
{
    reserve(&t.text, N+1)
    t.cursor = 0
    for i in 0..=N do append(&t.text, 0)

    t.is_numbers_only = numbers_only
    t.associated_value = associated_value

    if len(text) != 0 {
        assert(len(text) <= N)
        for c, i in text do t.text[i] = u8(c)
        t.cursor = len(text)
        if numbers_only do t.associated_value^ = textbox_parse(&t)
    }

    t.fontsize = fontsize
    t.extra_w = extra_w
    t.extra_h = extra_h
    t.w = fontsize * editor.font.w * f32(N) + f32(extra_w)
    t.h = fontsize * editor.font.h          + f32(extra_h)
    return
}

textbox_set_text :: proc(using t: ^TextBox, input_text: string)
{
    for i in 0..<len(text) do text[i] = u8(0)
    for c, i in input_text do text[i] = u8(c)
    cursor = len(input_text)
}

textbox_update :: proc(using t: ^TextBox)
{
    rect := rl.Rectangle{x, y, w, h}

    if rl.IsKeyPressed(.ESCAPE) do active = false

    if rl.IsMouseButtonPressed(.LEFT) &&
       rl.CheckCollisionPointRec(mouse.pos, rect)
    {
        active = true
    }

    if rl.IsMouseButtonPressed(.LEFT) &&
       !rl.CheckCollisionPointRec(mouse.pos, rect)
    {
        active = false
    }

    if !active do return

    registered_typing := textbox_register_typing(t)

    if registered_typing && is_numbers_only {
        text_value := textbox_parse(t)
        if text_value > 0 && text_value < 99 do associated_value^ = text_value
    }

    if rl.IsKeyPressed(.LEFT) {
        if rl.IsKeyDown(.LEFT_CONTROL) {
            textbox_move_cursor_left_by_word(t)
        } else {
            textbox_move_cursor_left(t)
        }
    }

    if rl.IsKeyPressed(.RIGHT) {
        if rl.IsKeyDown(.LEFT_CONTROL) {
            textbox_move_cursor_right_by_word(t)
        } else {
            textbox_move_cursor_right(t)
        }
    }

    if is_numbers_only && rl.IsKeyPressed(.UP) {
        text_value := textbox_parse(t)
        textbox_set_number(t, text_value + 1)
    }
    if  is_numbers_only && rl.IsKeyPressed(.DOWN) {
        text_value := textbox_parse(t)
        textbox_set_number(t, text_value - 1)
    }

    if rl.IsKeyPressed(.BACKSPACE) {
        if rl.IsKeyDown(.LEFT_CONTROL) {
            textbox_backspace_by_word(t)
        } else {
            textbox_backspace(t)
        }

        if is_numbers_only {
            text_value := textbox_parse(t)
            textbox_set_number(t, text_value)
        }
    }
}

draw_textbox :: proc(using t: ^TextBox)
{
    text_len := textbox_len(t)

    rect := rl.Rectangle{x, y, w, h}

    text_x := x + w/2 - (fontsize * editor.font.w * cast(f32)text_len)/2
    text_y := y + h/2 - (fontsize * editor.font.h)/2

    cursor_rect := rl.Rectangle{
        text_x + fontsize * editor.font.w * f32(cursor),
        text_y + fontsize,
        2,
        editor.font.h * fontsize - fontsize * 2,
    }

    rl.DrawRectangleRounded(rect, 0.5, 20, PALETTE06)
    font_image_draw(&editor.font, fontsize, textbox_string(t, text_len), text_x, text_y, PALETTE03)
    if active do rl.DrawRectangleRec(cursor_rect, rl.ColorAlpha(PALETTE00, math.cos(math.PI*time.now)*0.35 + 0.65))
}


textbox_string :: proc(t: ^TextBox, length: int) -> string
{
    return strings.string_from_ptr(raw_data(t.text[:]), length)
}

textbox_len :: proc(t: ^TextBox) -> int
{
    index, found := slice.linear_search(t.text[:], 0)
    assert(found)
    return index
}

save_textbox_string :: proc(t: ^TextBox) -> strings.Builder
{
    name := textbox_string(t, textbox_len(t))

    builder := strings.builder_make(len=0, cap=len("levels/")+len(name)+len(".json"))
    strings.write_string(&builder, "levels/")
    strings.write_string(&builder, name)
    strings.write_string(&builder, ".json")
    return builder
}

textbox_set_number :: proc(using t: ^TextBox, number: f32)
{
    if (number > 0) && (number < 99) {
        for i in 0..<len(text) do text[i] = 0

        buf := make_slice([]u8, len(text))
        defer delete(buf)

        parsed := strconv.itoa(buf[:], cast(int)number)
        for c, i in parsed do text[i] = parsed[i]

        associated_value^ = number
    }
}

textbox_parse :: proc(using t: ^TextBox) -> f32
{
    to_parse := textbox_string(t, textbox_len(t) + 1)
    value, could_not := strconv.parse_int(to_parse)
    if could_not do return 0
    return cast(f32)value
}

textbox_append :: proc(using t: ^TextBox, c: u8)
{
    if cursor + 1 < len(text) {
        text[cursor] = c
        cursor += 1
    }
}

textbox_register_typing :: proc(using t: ^TextBox) -> bool
{
    chr := cast(u8)rl.GetCharPressed()

    holding_modifiers := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.LEFT_ALT)

    in_range: bool
    if t.is_numbers_only do in_range = (chr >= '0' && chr <= '9')
    else do in_range = (chr >= ' ' && chr <= '~')

    if in_range && !holding_modifiers {
        textbox_append(t, chr)
        return true
    }
    return false
}

textbox_move_cursor_left :: proc(using t: ^TextBox)
{
    if cursor - 1 >= 0 {
        cursor -= 1
    }
}

textbox_move_cursor_right :: proc(using t: ^TextBox)
{
    if cursor + 1 < textbox_len(t) + 1 {
        cursor += 1
    }
}

textbox_backspace :: proc(using t: ^TextBox)
{
    if cursor == 0 do return

    textbox_move_cursor_left(t)
    mem.copy(&text[cursor], &text[cursor+1], (len(text) - 1 - cursor) * size_of(u8))

    for i in textbox_len(t)+1..<len(text) do text[i] = 0
}

textbox_move_cursor_left_by_word :: proc(using t: ^TextBox)
{
    for (cursor > 0) && (textbox_len(t) > 0) {
        textbox_move_cursor_left(t)
        if (cursor == 0) do break
        c := text[cursor - 1]
        if (c == ' ') || (c == '_') || (c == ';') || (c == ',') || (c == 0) do break
    }
} 

textbox_move_cursor_right_by_word :: proc(using t: ^TextBox)
{
    for {
        textbox_move_cursor_right(t)
        if cursor == textbox_len(t) do break
        c := text[cursor]
        if (c == ' ') || (c == '_') || (c == ';') || (c == ',') || (c == 0) do break
    }
}

textbox_backspace_by_word :: proc(using t: ^TextBox)
{
    for (cursor > 0) && (textbox_len(t) > 0) {
        if textbox_len(t) > 0 do textbox_backspace(t)
        if (cursor == 0) do break
        c := text[cursor - 1]
        if (c == ' ') || (c == '_') || (c == ';') || (c == ',') || (c == 0) do break
    }
}
