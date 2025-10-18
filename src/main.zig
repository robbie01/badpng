const std = @import("std");
const builtin = @import("builtin");
const badpng = @import("badpng");
const png = badpng.png;
const sdl = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
});

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next();

    defer sdl.SDL_Quit();

    if (!sdl.SDL_InitSubSystem(sdl.SDL_INIT_VIDEO)) {
        std.debug.print("failed to init sdl: {s}\n", .{sdl.SDL_GetError()});
        return error.Error;
    }
    defer sdl.SDL_QuitSubSystem(sdl.SDL_INIT_VIDEO);

    const png_name = args.next();
    if (png_name == null) {
        std.debug.print("png file not provided\n", .{});
        return error.Error;
    }

    const png_file = std.c.fopen(png_name.?, "rb");
    if (png_file == null) {
        std.debug.print("failed to open file\n", .{});
        return error.Error;
    }
    defer _ = std.c.fclose(png_file.?);

    var png_data = png.png_create_read_struct(png.PNG_LIBPNG_VER_STRING, null, null, null);
    if (png_data == null) {
        std.debug.print("failed to create png read struct\n", .{});
        return error.Error;
    }

    var png_info = png.png_create_info_struct(png_data);
    if (png_info == null) {
        std.debug.print("failed to create png info struct\n", .{});
        png.png_destroy_read_struct(&png_data, null, null);
        return error.Error;
    }

    var png_end_info = png.png_create_info_struct(png_data);
    if (png_end_info == null) {
        std.debug.print("failed to create png end info struct\n", .{});
        png.png_destroy_read_struct(&png_data, &png_info, null);
        return error.Error;
    }
    defer png.png_destroy_read_struct(&png_data, &png_info, &png_end_info);

    png.png_init_io(png_data, @ptrCast(@alignCast(png_file)));

    png.png_read_png(
        png_data,
        png_info,
        png.PNG_TRANSFORM_EXPAND | png.PNG_TRANSFORM_STRIP_16 | png.PNG_TRANSFORM_STRIP_ALPHA | (if (builtin.target.cpu.arch.endian() == .big) png.PNG_TRANSFORM_BGR else 0),
        null,
    );

    const height = png.png_get_image_height(png_data, png_info);
    const width = png.png_get_image_width(png_data, png_info);

    const win = sdl.SDL_CreateWindow(
        "png viewer",
        @intCast(width),
        @intCast(height),
        0,
    );
    if (win == null) {
        std.debug.print("failed to create window: {s}\n", .{sdl.SDL_GetError()});
        return error.Error;
    }
    defer sdl.SDL_DestroyWindow(win);

    const sfc = sdl.SDL_CreateSurface(
        @intCast(width),
        @intCast(height),
        sdl.SDL_PIXELFORMAT_RGB24,
    );
    if (sfc == null) {
        std.debug.print("failed to create surface: {s}\n", .{sdl.SDL_GetError()});
        return error.Error;
    }
    defer sdl.SDL_DestroySurface(sfc);

    const row_pointers = png.png_get_rows(png_data, png_info);
    for (0.., row_pointers[0..height]) |y, row| {
        const dest = @as([*]u8, @ptrCast(sfc.*.pixels)) + y * @as(usize, @intCast(sfc.*.pitch));
        @memcpy(dest[0 .. 3 * width], row);
    }

    const winsfc = sdl.SDL_GetWindowSurface(win.?);
    if (winsfc == null) {
        std.debug.print("failed to get window surface: {s}\n", .{sdl.SDL_GetError()});
        return error.Error;
    }

    if (!sdl.SDL_BlitSurface(sfc, null, winsfc, null)) {
        std.debug.print("failed to blit surface: {s}\n", .{sdl.SDL_GetError()});
        return error.Error;
    }

    if (!sdl.SDL_UpdateWindowSurface(win)) {
        std.debug.print("failed to update window surface: {s}\n", .{sdl.SDL_GetError()});
        return error.Error;
    }

    // Event loop to keep window open and responsive
    var running = true;
    while (running) {
        var event: sdl.SDL_Event = undefined;
        if (!sdl.SDL_WaitEvent(&event)) {
            std.debug.print("failed to get event: {s}\n", .{sdl.SDL_GetError()});
            return error.Error;
        }
        if (event.type == sdl.SDL_EVENT_QUIT) {
            running = false;
        }
    }
}
