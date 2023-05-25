const std = @import("std");
const Entity = @import("entity-storage.zig").Entity;
const Context = @import("context.zig").Context;

pub fn System(comptime context: type) type {
    return *const fn (context) void;
}
