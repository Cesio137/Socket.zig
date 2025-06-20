const stdlib = @cImport( @cInclude("stdlib.h") );
const uv = @cImport( @cInclude("uv.h") );

pub fn alloc_buffer(_: [*c]uv.uv_handle_t, suggested_size: usize, buf: [*c]uv.uv_buf_t) callconv(.C) void {
    const malloc = stdlib.malloc(@intCast(suggested_size));
    if (malloc == null) {
        buf.*.base = null;
        buf.*.len = 0;
        return;
    }
    buf.*.base = @ptrCast(malloc);
    buf.*.len = @intCast(suggested_size);
    //const malloc = std.heap.c_allocator.alloc([*c]u8, suggested_size) catch |err| {
    //    std.debug.print("Failed to alloc: {}", .{err});
    //    buf.*.base = null;
    //    buf.*.len = 0;
    //    return;
    //};
    //buf.*.base = malloc[0];
    //buf.*.len = @intCast(suggested_size);
}

pub fn strToCString(str: []const u8) [*c]const u8 {
    const c_buf: [*c]const u8 = @ptrCast(str);
    return c_buf;
}

pub fn strToCBuffer(str: []const u8) [*c]u8 {
    const data: []u8 = @constCast(str);
    const c_buf: [*c]u8 = @ptrCast(data);
    return c_buf;
}

pub fn bufToCBuffer(buf: []u8) [*c]u8 {
    const c_buf: [*c]u8 = @ptrCast(buf);
    return c_buf;
}

pub fn uvbufToBuffer(uvbuf: [*c]const uv.uv_buf_t, len: isize) []u8 {
    const buf: []u8 = uvbuf[0].base[0..@intCast(len)];
    return buf;
}

pub fn freeUVBuffer(uvbuf: [*c]const uv.uv_buf_t) void {
    stdlib.free(uvbuf.*.base);
}

