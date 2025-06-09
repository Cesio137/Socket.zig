const stdlib = @cImport( @cInclude("stdlib.h") );
const c = @cImport( @cInclude("uv.h") );

pub fn alloc_buffer(handle: [*c]c.uv_handle_t, suggested_size: usize, buf: [*c]c.uv_buf_t) callconv(.C) void {
    _ = handle;
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