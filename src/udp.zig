const std = @import("std");
const uv = @cImport(@cInclude("uv.h"));
const utils = @import("utils.zig");

// Server

// Client
pub const Client = struct { 
    // Public
    address: []const u8, 
    port: u16,
    send_cb: ?*const fn ([*c]uv.uv_udp_send_t, c_int) callconv(.c) void,
    recv_cb: ?*const fn ([*c]uv.uv_udp_t, isize, [*c]const uv.uv_buf_t, [*c]const uv.struct_sockaddr, c_uint) callconv(.c) void,
    // Private
    p_recv_socket: uv.uv_udp_t,
    p_recv_addr: uv.sockaddr_in,

    pub fn connect(self: *Client, uv_loop: [*c]uv.uv_loop_t) i32 {
        // Init client recv socket
        var code = uv.uv_udp_init(uv_loop, &self.*.p_recv_socket);
        if (code != 0) { return code; }
        // Set client ipv4 address and random port
        code = uv.uv_ip4_addr("0.0.0.0", 0, &self.*.p_recv_addr);
        if (code != 0) { return code; }
        // Bind udp settings
        code = uv.uv_udp_bind(&self.*.p_recv_socket, @ptrCast(&self.*.p_recv_addr), uv.UV_UDP_REUSEADDR);
        if (code != 0) { return code; }
        // Start listening
        code = uv.uv_udp_recv_start(&self.*.p_recv_socket, utils.alloc_buffer, self.*.recv_cb);
        if (code != 0) { return code; }

        return code;
    }

    pub fn sendStr(self: *Client, message: []const u8) i32 {
        // Convert to C buffer
        const buf = utils.strToCBuffer(message);
        // Init uv buffer
        var uv_buf = uv.uv_buf_init(buf, @intCast(message.len));
        // UV handler and address
        var send_req: uv.uv_udp_send_t = undefined;
        var send_addr: uv.sockaddr_in = undefined;
        // Set server address to send message
        const cstr_address = utils.strToCString(self.address);
        var code = uv.uv_ip4_addr(cstr_address, self.port, &send_addr);
        if (code != 0) { return code; }
        // Send message
        code = uv.uv_udp_send(
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
        // Convert to C buffer
        const c_buf = utils.bufToCBuffer(buf);
        // Init uv buffer
        var uv_buf = uv.uv_buf_init(c_buf, buf.len);
        // UV handler and address
        var send_req: uv.uv_udp_send_t = undefined;
        var send_addr: uv.sockaddr_in = undefined;
        // Set server address to send message
        const cstr_address = utils.strToCString(self.address);
        var code = uv.uv_ip4_addr(cstr_address, self.port, &send_addr);
        if (code != 0) { return code; }
        // Send message
        code = uv.uv_udp_send(
            &send_req,
            &self.*.p_recv_socket,
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
        .send_cb = undefined,
        .recv_cb = undefined,
        .p_recv_socket = undefined,
        .p_recv_addr = undefined,
    };
    return client;
}
