package editor

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:strconv"
import "core:encoding/json"
import "base:runtime"
import "core:os"

BYTE_BUFFER_DEFAULT_CAP :: 1024

ByteBuffer :: struct {
    position, size, capacity: int,
    data: rawptr,
}

byte_buffer_new :: proc(init_data: bool = true) -> (buffer: ByteBuffer)
{
    if init_data do buffer.data, _ = mem.alloc(BYTE_BUFFER_DEFAULT_CAP * size_of(u8))
    buffer.capacity = BYTE_BUFFER_DEFAULT_CAP
    buffer.position = 0
    buffer.size = 0
    return buffer
}

byte_buffer_resize :: proc(using buffer: ^ByteBuffer, new_capacity: int)
{
    temp, _ := mem.alloc(new_capacity * size_of(u8))
    mem.copy(temp, data, size)
    free(data)
    data = temp
}

byte_buffer_write :: proc(using buffer: ^ByteBuffer, $T: typeid, value_ptr: ^T)
{
    total_write_size := position + size_of(T)

    if total_write_size >= capacity {
        capacity := capacity * 2 if capacity != 0 else BYTE_BUFFER_DEFAULT_CAP
        for capacity < total_write_size do capacity *= 2
        byte_buffer_resize(buffer, capacity)
    }
    dest := uintptr(data) + uintptr(position)
    mem.copy(rawptr(dest), value_ptr, size_of(T))
    position += size_of(T)
    size += size_of(T)
}

byte_buffer_read :: proc(using buffer: ^ByteBuffer, $T: typeid, value_ptr: ^T)
{
    ptr := cast(^T)(uintptr(data) + uintptr(position))
    value_ptr^ = ptr^
    position += size_of(T)
}

byte_buffer_write_to_file :: proc(using buffer: ^ByteBuffer, filename: string)
{
    file, err := os.open(filename, os.O_WRONLY)
    os.seek(file, 0, os.SEEK_SET)
    os.write_ptr(file, data, size)
    os.ftruncate(file, i64(size))
    os.close(file)
}

byte_buffer_read_from_file :: proc(using buffer: ^ByteBuffer, filename: string) -> (success: bool)
{
    file_data, ok := os.read_entire_file(filename)
    if !ok do return false

    data = raw_data(file_data)
    size = len(file_data)
    capacity = len(file_data)
    return true
}

SaveFileFormat :: struct {
    spritesheet_names: []string,
    tile_layers: [dynamic]SaveTileLayer,
}

serialize_save :: proc(save_file_name: string) -> (bytes_saved: int)
{
    format: SaveFileFormat
    _, format.spritesheet_names = soa_unzip(editor.spritesheets[:])

    for &tile_layer, layer_index in editor.tile_layers {
        if len(tile_layer) != 0 {
            builders := make_slice([]strings.Builder, len(tile_layer))
            defer delete(builders)

            append(&format.tile_layers, SaveTileLayer{})

            builder_index: int
            for pos, info in tile_layer {
                strings.write_int(&builders[builder_index], pos.x)
                strings.write_byte(&builders[builder_index], ';')
                strings.write_int(&builders[builder_index], pos.y)
                key := strings.to_string(builders[builder_index])
                format.tile_layers[layer_index][key] = info
                builder_index += 1
            }
        }
    }

    data, marshal_err := json.marshal(format, {pretty = true})
    assert(marshal_err == nil)
    defer delete(data)

    success := os.write_entire_file(save_file_name, data)
    assert(success)

    return len(data)
}

LoadResult :: enum {
    CREATED_SAVE_FILE,
    SKIPPED_SAVE_FILE,
    SUCCESS,
}

serialize_load :: proc(save_file_name: string) -> (load_result: LoadResult, bytes_loaded: int)
{
    data, read_success := os.read_entire_file(save_file_name)
    defer delete(data)

    // Create the file in case it doesn't exist.
    if !read_success {
        file, err := os.open(save_file_name, os.O_CREATE)
        assert(err == os.ERROR_NONE)
        os.close(file)
        return .CREATED_SAVE_FILE, 0
    }

    // Check that the file isn't empty.
    if len(data) == 0 {
        return .SKIPPED_SAVE_FILE, 0
    }

    get_texture_index :: proc(name: string) -> int
    {
        for &sheet, i in editor.spritesheets {
            if strings.compare(name, sheet.name) == 0 {
                return i
            }
        }
        return -1
    }

    get_pos_from_string :: proc(pos_string: string) -> [2]int
    {
        result, err := strings.split(pos_string, ";")
        assert(err == runtime.Allocator_Error.None)
        defer delete(result)
        x, _ := strconv.parse_int(result[0])
        y, _ := strconv.parse_int(result[1])
        return {x, y}
    }

    format: SaveFileFormat
    err := json.unmarshal(data, &format)
    assert(err == nil)

    for &tile_layer, index in format.tile_layers {
        if len(tile_layer) != 0 {
            append(&editor.tile_layers, TileLayer{})

            for key, value in tile_layer {
                pos_string, info := key, value
                info.texture_index = get_texture_index(format.spritesheet_names[info.texture_index])
                pos := get_pos_from_string(pos_string)

                when ODIN_DEBUG {
                    if info.texture_index == -1 {
                        fmt.printf("[EDITOR:INFO:%s] Couldn't find tile at (%v, %v)", format.spritesheet_names[info.texture_index], pos.x, pos.y)
                    }
                }
                // Default to 0 when not found.
                if info.texture_index == -1 do info.texture_index = 0

                editor.tile_layers[index][pos] = info
                update_level_boundaries(&editor.x_boundary, &editor.y_boundary, pos)
            }
        }
    }

    return .SUCCESS, len(data)
}

AUTO_SAVE :: #config(AUTO_SAVE, false)

when ODIN_DEBUG {

    serialize_load_and_log :: proc(save_file_name: string)
    {
        load_result, bytes_loaded := serialize_load(save_file_name)
        switch load_result {
        case .SUCCESS: 
            fmt.printf("[EDITOR:INFO:%s] Loading was sucessfull with %v bytes loaded.\n", save_file_name, bytes_loaded)
        case .CREATED_SAVE_FILE:
            fmt.printf("[EDITOR:INFO:%s] Loading was not sucessfull, created a new file.\n", save_file_name)
        case .SKIPPED_SAVE_FILE:
            fmt.printf("[EDITOR:INFO:%s] Loading was not sucessfull, skipped the file as it was empty.\n", save_file_name)
        }
    }

    serialize_save_and_log :: proc(save_file_name: string)
    {
        bytes_saved := serialize_save(save_file_name)
        fmt.printf("[EDITOR:INFO:%s] Saving was sucessfull with %v bytes saved.\n", save_file_name, bytes_saved)
    }

} else {
    serialize_load_and_log :: serialize_load
    serialize_save_and_log :: serialize_save
}