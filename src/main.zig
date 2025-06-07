//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const uv = @cImport( @cInclude("uv.h") );

fn alloc_buffer(handle: ?*uv.uv_handle_t, suggested_size: usize, buf: *uv.uv_buf_t) callconv(.C) void {
    _ = handle;
    buf.* = uv.uv_buf_init(std.heap.c_allocator.alloc(u8, suggested_size) catch null, suggested_size);
}

fn on_send(req: [*c]uv.uv_udp_send_t, status: c_int) callconv(.C) void {
    _ = req;
    if (status == 0) {
        std.debug.print("Mensagem enviada com sucesso!\n", .{});
    } else {
        std.debug.print("Erro ao enviar: {d}\n", .{status});
    }
}

fn convert(slice: []const u8) [*c]u8 {
    return slice.ptr;
}


pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!

    const loop = uv.uv_default_loop();

    var udp_handle: uv.uv_udp_t = undefined;
    if (uv.uv_udp_init(loop, &udp_handle) != 0) {
        std.debug.print("Erro ao inicializar UDP\n", .{});
        return;
    }

    // Mensagem a ser enviada
    const msg = "login";
    var buf = uv.uv_buf_init(@constCast(msg), msg.len);

    // Endereço de destino (broadcast na porta 12345)
    var addr: uv.sockaddr_in = undefined;
    _ = uv.uv_ip4_addr("127.0.0.1", 3000, &addr);

    // Habilita broadcast
    _ = uv.uv_udp_set_broadcast(&udp_handle, 1);

    var send_req: uv.uv_udp_send_t = undefined;
    _ = uv.uv_udp_send(
        &send_req,
        &udp_handle,
        &buf,
        1,
        @ptrCast(&addr),
        on_send,
    );

    _ = uv.uv_run(loop, uv.UV_RUN_DEFAULT);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("Socket_zig_lib");
