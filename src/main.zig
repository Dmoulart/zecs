const std = @import("std");
const expect = std.testing.expect;
const Component = @import("./component.zig").Component;
const archetype = @import("./archetype.zig").archetype;
const World = @import("./world.zig").World;
const Entity = @import("./world.zig").Entity;
const SparseSet = @import("./sparse-set.zig").SparseSet;

const Vector = struct { x: f64 = 0, y: f64 = 0 };
const Position = Component(Vector){ .id = 1 };
const Velocity = Component(Vector){ .id = 2 };

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var transform = archetype(.{ Position, Velocity });
    _ = transform;

    var world = World.init(arena.child_allocator);
    var ent = world.createEntity();
    world.attach(ent, Position);

    std.debug.print("ent {}", .{ent});
    // std.debug.print("hash transform {}", .{transform});
}
