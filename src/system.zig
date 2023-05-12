const std = @import("std");
const Entity = @import("entity-storage.zig").Entity;
const World = @import("world.zig").World;

pub const System = fn (anytype) void;
