//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("Socket_zig_lib");
const uv = @cImport( @cInclude("uv.h") );
const udp = @import("udp.zig");

fn on_send(req: [*c]uv.uv_udp_send_t, status: c_int) callconv(.C) void {
    _ = req;
    if (status == 0) {
        std.debug.print("Mensagem enviada com sucesso!\n", .{});
    } else {
        std.debug.print("Erro ao enviar: {d}\n", .{status});
    }
}

fn on_recv(req: [*c]uv.uv_udp_t, nread: isize, buf: [*c]const uv.uv_buf_t, addr: [*c]const uv.struct_sockaddr, flags: c_uint) callconv(.c) void {
    _ = req; _ = addr; _ = flags;
    if (nread == 0) {
        std.debug.print("EOF\n", .{});
        return;
    }
    if (nread < 0) {
        std.debug.print("Erro ao receber mensagem: {d}\n", .{nread});
        return;
    }
    
    const msg = buf[0].base[0..@intCast(nread)];
    std.debug.print("Mensagem recebida: {s}\n", .{msg});
}

pub fn main() !void {
    const loop = uv.uv_default_loop();
    var udp_client = udp.createDefaultClient();
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

    code = uv.uv_run(loop, uv.UV_RUN_DEFAULT);
    if (code != 0) {
        std.debug.print("Error trying run loop: {d}", .{code});
        return;
    }
}
