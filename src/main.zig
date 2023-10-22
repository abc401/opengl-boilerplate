const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));
const gl = @cImport(@cInclude("glad/glad.h"));

fn hsdle(err_code: c_int) void {
    if (err_code < 0) {
        std.debug.print("SDL error: {s}", .{sdl.SDL_GetError()});
        std.process.exit(1);
    }
}
fn sdl_die() noreturn {
    std.debug.print("SDL error: {s}", .{sdl.SDL_GetError()});
    std.process.exit(1);
}

const initial_width = 500;
const initial_height = 500;

pub fn main() !void {
    hsdle(sdl.SDL_Init(sdl.SDL_INIT_VIDEO));
    defer sdl.SDL_Quit();

    hsdle(sdl.SDL_GL_SetAttribute(sdl.SDL_GL_RED_SIZE, 8));
    hsdle(sdl.SDL_GL_SetAttribute(sdl.SDL_GL_GREEN_SIZE, 8));
    hsdle(sdl.SDL_GL_SetAttribute(sdl.SDL_GL_BLUE_SIZE, 8));
    hsdle(sdl.SDL_GL_SetAttribute(sdl.SDL_GL_ALPHA_SIZE, 8));

    hsdle(sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, 3));
    hsdle(sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, 3));
    hsdle(sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, sdl.SDL_GL_CONTEXT_PROFILE_CORE));

    hsdle(sdl.SDL_GL_SetAttribute(sdl.SDL_GL_DOUBLEBUFFER, 1));

    const window = sdl.SDL_CreateWindow("Hello", sdl.SDL_WINDOWPOS_UNDEFINED, sdl.SDL_WINDOWPOS_UNDEFINED, initial_width, initial_height, sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_OPENGL) orelse sdl_die();
    defer sdl.SDL_DestroyWindow(window);

    var context = sdl.SDL_GL_CreateContext(window) orelse sdl_die();
    defer sdl.SDL_GL_DeleteContext(context);

    if (gl.gladLoadGLLoader(sdl.SDL_GL_GetProcAddress) == 0) {
        std.debug.print("\n\nCould not initialize GLAD\n\n", .{});
        std.process.exit(1);
    }

    gl.glViewport(0, 0, initial_width, initial_height);

    var quit = false;
    while (!quit) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) == 1) {
            switch (event.type) {
                sdl.SDL_QUIT => quit = true,
                sdl.SDL_WINDOWEVENT => {
                    switch (event.window.event) {
                        sdl.SDL_WINDOWEVENT_RESIZED => {
                            std.log.info("Window resized", .{});
                            gl.glViewport(0, 0, event.window.data1, event.window.data2);
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        gl.glClearColor(1, 0.5, 0.5, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        sdl.SDL_GL_SwapWindow(window);
    }
}
