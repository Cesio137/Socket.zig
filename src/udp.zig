const std = @import("std");
const c = @cImport(@cInclude("uv.h"));
const utils = @import("utils.zig");

// Client
pub const Client = struct { 
    // Public
    address: []const u8, 
    port: u16,
    split_send_buf: bool,
    send_buf_size: u32, 
    recv_buf_size: u32,
    send_cb: ?*const fn ([*c]c.uv_udp_send_t, c_int) callconv(.c) void,
    recv_cb: ?*const fn ([*c]c.uv_udp_t, isize, [*c]const c.uv_buf_t, [*c]const c.struct_sockaddr, c_uint) callconv(.c) void,
    // Private
    p_send_socket: c.uv_udp_t,
    p_broadcast_addr: c.sockaddr_in,
    p_recv_socket: c.uv_udp_t,
    p_recv_addr: c.sockaddr_in,

    pub fn connect(self: *Client, uv_loop: [*c]c.uv_loop_t) i32 {
        var code = c.uv_udp_init(uv_loop, &self.*.p_send_socket);
        if (code != 0) { return code; }
        code = c.uv_ip4_addr("0.0.0.0", 0, &self.*.p_broadcast_addr);
        if (code != 0) { return code; }
        code = c.uv_udp_bind(&self.*.p_send_socket, @ptrCast(&self.*.p_broadcast_addr), c.UV_UDP_REUSEADDR);
        if (code != 0) { return code; }
        code = c.uv_udp_set_broadcast(&self.*.p_send_socket, 1);
        if (code != 0) { return code; }
        
        code = c.uv_udp_init(uv_loop, &self.*.p_recv_socket);
        if (code != 0) { return code; }
        code = c.uv_ip4_addr("0.0.0.0", 0, &self.*.p_recv_addr);
        if (code != 0) { return code; }
        code = c.uv_udp_bind(&self.*.p_recv_socket, @ptrCast(&self.*.p_recv_addr), c.UV_UDP_REUSEADDR);
        if (code != 0) { return code; }
        code = c.uv_udp_recv_start(&self.*.p_recv_socket, utils.alloc_buffer, self.*.recv_cb);
        if (code != 0) { return code; }

        return code;
    }

    pub fn sendStr(self: *Client, message: []const u8) i32 {
        const data: []u8 = @constCast(message);
        const c_data: [*c]u8 = @ptrCast(data);
        var uv_buf = c.uv_buf_init(c_data, @intCast(message.len));
        var send_req: c.uv_udp_send_t = undefined;
        var send_addr: c.sockaddr_in = undefined;
        var code = c.uv_ip4_addr("127.0.0.1", 3000, &send_addr);
        if (code != 0) { return code; }
        code = c.uv_udp_send(
            &send_req,
            &self.*.p_recv_socket,
            &uv_buf,
            1,
            @ptrCast(&send_addr),
            self.*.send_cb,
        );
        return code;
    }

    pub fn sendBuffer(self: *Client, buf: []u8) i32 {
        var uv_buf = c.uv_buf_init(@ptrCast(buf), buf.len);
        var send_req: c.uv_udp_send_t = undefined;
        var send_addr: c.sockaddr_in = undefined;
        _ = c.uv_ip4_addr("127.0.0.1", 3000, &send_addr);
        const code = c.uv_udp_send(
            &send_req,
            &self.*.p_send_socket,
            &uv_buf,
            1,
            @ptrCast(&send_addr),
            self.*.on_send,
        );
        return code;
    }
};

pub fn createDefaultClient() Client {
    const client = Client{ 
        .address = "127.0.0.1", 
        .port = 80,
        .split_send_buf = true,
        .send_buf_size = 1024,
        .recv_buf_size = 1024,
        .send_cb = undefined,
        .recv_cb = undefined,
        .p_send_socket = undefined,
        .p_broadcast_addr = undefined,
        .p_recv_socket = undefined,
        .p_recv_addr = undefined,
    };
    return client;
}
