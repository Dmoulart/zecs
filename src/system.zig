const std = @import("std");
const Entity = @import("entity-storage.zig").Entity;
const World = @import("world.zig").World;

pub fn System(comptime world: type) type {
    return *const fn (world) void;
}
