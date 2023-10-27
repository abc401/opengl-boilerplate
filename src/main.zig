const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));
const gl = @cImport(@cInclude("glad/glad.h"));

const initial_width = 500;
const initial_height = 500;
const fps = 60;

fn hsdle(err_code: c_int) void {
    if (err_code < 0) {
        sdl_die();
    }
}
fn sdl_die() noreturn {
    std.debug.print("SDL error: {s}", .{sdl.SDL_GetError()});
    std.process.exit(1);
}

fn compile_shader(shader_source: []const u8, shader_type: gl.GLenum) !gl.GLuint {
    const shader_ID = gl.glCreateShader(shader_type);
    std.log.info("Created shader of type: {any}, with id: {any}", .{ shader_type, shader_ID });
    gl.glShaderSource(shader_ID, 1, &shader_source.ptr, null);
    gl.glCompileShader(shader_ID);

    var success: gl.GLint = undefined;
    gl.glGetShaderiv(shader_ID, gl.GL_COMPILE_STATUS, &success);
    if (success != gl.GL_TRUE) {
        var info_log: [512]u8 = undefined;
        var info_log_len: gl.GLsizei = undefined;
        gl.glGetShaderInfoLog(shader_ID, 512, &info_log_len, &info_log);
        std.debug.print("Shader compilation failure: {s}", .{info_log[0..@intCast(info_log_len)]});
        return error.CompilationFalure;
    }
    std.log.info("Shader compilation success!", .{});
    return shader_ID;
}

fn link_program(program: gl.GLuint, shaders: []const gl.GLuint) !void {
    for (shaders) |shader| {
        gl.glAttachShader(program, shader);
        std.log.info("Attached shader: {any}, to program: {}", .{ shader, program });
    }

    gl.glLinkProgram(program);

    var success: gl.GLint = undefined;
    gl.glGetProgramiv(program, gl.GL_LINK_STATUS, &success);
    if (success != gl.GL_TRUE) {
        var info_log: [512]u8 = undefined;
        var info_log_len: gl.GLsizei = undefined;
        gl.glGetProgramInfoLog(program, 512, &info_log_len, &info_log);
        std.debug.print("Program linking failure: {s}", .{info_log[0..@intCast(info_log_len)]});
        return error.CompilationFalure;
    }
    std.log.info("Program linking success!", .{});
}

pub fn main() !void {
    std.log.info("\n\n", .{});
    defer std.log.info("\n\n", .{});

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
    std.log.info("Glad initialized.", .{});

    // Compile GLSL
    const shader_program = gl.glCreateProgram();
    defer gl.glDeleteProgram(shader_program);

    {
        const vert_shader_source: []const u8 = @embedFile("shader.vert");
        const vert_shader = try compile_shader(vert_shader_source, gl.GL_VERTEX_SHADER);
        defer gl.glDeleteShader(vert_shader);

        const frag_shader_source: []const u8 = @embedFile("shader.frag");
        const frag_shader = try compile_shader(frag_shader_source, gl.GL_FRAGMENT_SHADER);
        defer gl.glDeleteShader(frag_shader);

        try link_program(shader_program, &[_]gl.GLuint{ vert_shader, frag_shader });
    }

    const vertices = [_]gl.GLfloat{
        -1, -1, //
        1, -1, //
        1,  1, //
        -1, 1,
    };
    const indices = [_]c_ushort{
        0, 1, 2, //
        0, 2, 3,
    };

    var vao: gl.GLuint = undefined;
    var vbo: gl.GLuint = undefined;
    var ebo: gl.GLuint = undefined;

    gl.glGenVertexArrays(1, &vao);
    defer gl.glDeleteVertexArrays(1, &vao);

    gl.glGenBuffers(1, &vbo);
    defer gl.glDeleteBuffers(1, &vbo);

    gl.glGenBuffers(1, &ebo);
    defer gl.glDeleteBuffers(1, &ebo);

    gl.glBindVertexArray(vao);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);
    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ebo);

    gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.GL_STATIC_DRAW);
    gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.GL_STATIC_DRAW);
    gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, 2 * @sizeOf(gl.GLfloat), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);

    gl.glBindVertexArray(0);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);

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
                            // gl.glViewport(0, 0, event.window.data1, event.window.data2);
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        gl.glClearColor(0, 0, 0, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        gl.glUseProgram(shader_program);

        const time = @as(f32, @floatFromInt(sdl.SDL_GetTicks())) / 10000.0;
        const color_location = gl.glGetUniformLocation(shader_program, "color");
        const blue = std.math.sin(time + 0.1) / 2.0 + 0.5;
        const green = std.math.sin(time + 0.4) / 2.0 + 0.5;
        const red = std.math.sin(time + 0.7) / 2.0 + 0.5;
        gl.glUniform4f(color_location, red, green, blue, 1.0);

        gl.glBindVertexArray(vao);
        gl.glDrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_SHORT, @ptrFromInt(0));

        sdl.SDL_GL_SwapWindow(window);
        sdl.SDL_Delay(1000 / fps);
    }
}
