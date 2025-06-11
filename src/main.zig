//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const stdlib = @cImport(@cInclude("stdlib.h"));
const lib = @import("Socket_zig_lib");
const udp = @import("udp.zig");
const utils = @import("utils.zig");

const uv = lib.uv;

var loop: [*c]uv.uv_loop_t = undefined;
var uv_async: uv.uv_async_t = undefined;
var thread: uv.uv_thread_t = undefined;
var udp_client: udp.Client = undefined;

pub fn main() !void {
    loop = uv.uv_default_loop();

    udp_client = udp.createDefaultClient();
    udp_client.port = 3000;
    udp_client.send_cb = on_send;
    udp_client.recv_cb = on_recv;
    
    var code = udp_client.connect(loop);
    if (code != 0) {
        std.debug.print("Error trying connect: {d}", .{code});
        return;
    }
    code = udp_client.sendStr("login");
    if (code != 0) {
        std.debug.print("Error trying send: {d}", .{code});
        return;
    }
    
    code = uv.uv_async_init(loop, &uv_async, async_cb);
    if (code != 0) {
        std.debug.print("Error trying to init async: {d}", .{code});
        return;
    }
    code = uv.uv_thread_create(&thread, loop_thread, null);
    if (code != 0) {
        std.debug.print("Error trying to create thread: {d}", .{code});
        return;
    }

    const in = std.io.getStdIn();
    var buf_reader = std.io.bufferedReader(in.reader());
    var reader = buf_reader.reader();

    while (true) {
        std.debug.print("Type something ('quit' to exit): ", .{});

        var buffer: [1024]u8 = undefined;
        var line: []u8 = undefined;
        if ( (try reader.readUntilDelimiterOrEof(&buffer, '\n')) ) |raw_line| {
            line = raw_line;
        } else {
            continue;
        }

        if (line.len == 0) continue;

        var message: []u8 = undefined;
        if (line[line.len - 1] == '\r') { 
            message = line[0..line.len - 1]; 
        } else { message = line; }

        if (std.mem.eql(u8, message, "quit")) {
            std.debug.print("Bye...\n", .{});
            uv.uv_stop(loop);
            _ = uv.uv_thread_join(&thread);
            uv.uv_close(@ptrCast(&uv_async), null);
            _ = uv.uv_run(loop, uv.UV_RUN_NOWAIT); // Processa o fechamento do async
            _ = uv.uv_loop_close(loop);
            stdlib.free(loop);
            break;
        }

        std.debug.print("You typed: {s}\n", .{message});
    }
}

fn async_cb(_: [*c]uv.uv_async_t) callconv(.c) void {
    std.debug.print("Async signal received!\n", .{});
}

fn loop_thread(_: ?*anyopaque) callconv(.c) void {
    std.debug.print("[loop thread] Starting uv_run...\n", .{});
    _ = uv.uv_run(loop, uv.UV_RUN_DEFAULT);
    std.debug.print("[loop thread] uv_run finished.\n", .{});
}

fn on_send(req: [*c]uv.uv_udp_send_t, status: c_int) callconv(.C) void {
    _ = req;
    if (status == 0) {
        std.debug.print("Mensagem enviada com sucesso!\n", .{});
    } else {
        std.debug.print("Erro ao enviar: {d}\n", .{status});
    }
}

fn on_recv(req: [*c]uv.uv_udp_t, nread: isize, buf: [*c]const uv.uv_buf_t, _: [*c]const uv.struct_sockaddr, _: c_uint) callconv(.c) void {
    if (nread == 0) {
        std.debug.print("EOF\n", .{});
        return;
    }
    if (nread < 0) {
        std.debug.print("Erro ao receber mensagem: {d}\n", .{nread});
        return;
    }
    
    const msg = utils.uvbufToBuffer(buf, nread);
    std.debug.print("Mensagem recebida: {s}\n", .{msg});
    utils.freeUVBuffer(buf);
    _ = uv.uv_udp_recv_stop(req);
}
