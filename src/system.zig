const std = @import("std");
const Entity = @import("entity-storage.zig").Entity;
const World = @import("world.zig").World;

// pub const System = *const fn (anytype) void;
pub fn System(comptime world: type) type {
    return *const fn (world) void;
}

// pub const System = std.meta.Tuple(&[_]type{*const fn (anytype) void});

// pub const System = struct {
//     pub fn update(self: @This(), world: anytype) void {
//         _ = self;
//         _ = world;
//     }
// };
// pub const System = *const fn (anytype) void;
