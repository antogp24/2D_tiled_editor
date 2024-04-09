package editor

import rl "vendor:raylib"

FontImage :: struct {
    texture: rl.Texture2D,
    start, size: int,
    w, h: f32,
}

font_image_load :: proc($path: cstring, w, h: int, start := 0) -> (font: FontImage)
{
    font.texture = bake_texture(path)
    font.start = start
    font.w = cast(f32)w
    font.h = cast(f32)h
    return font
}

font_image_unload :: proc(font: ^FontImage)
{
    rl.UnloadTexture(font.texture)
}

font_image_draw :: proc(font: ^FontImage, fontsize: f32, text: string, x, y: f32, color: rl.Color)
{
    for i in 0..<len(text) {
        char_index := f32(int(text[i]) - font.start)
        src := rl.Rectangle{char_index * font.w, 0, font.w, font.h}
        dst := rl.Rectangle{x + f32(i) * font.w * fontsize, y, font.w * fontsize, font.h * fontsize}
        rl.DrawTexturePro(font.texture, src, dst, {0, 0}, 0, color)
    }
}