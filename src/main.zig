const std = @import("std");
const expect = std.testing.expect;
const Component = @import("./component.zig").Component;
const defineComponent = @import("./component.zig").defineComponent;

const createArchetype = @import("./archetype.zig").createArchetype;
const World = @import("./world.zig").World;
const Entity = @import("./world.zig").Entity;
const SparseSet = @import("./sparse-set.zig").SparseSet;

const Vector = struct { x: f64 = 0, y: f64 = 0 };

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const Position = defineComponent(Component(Vector));
    const Velocity = defineComponent(Component(Vector));

    var transform = createArchetype(.{ Position, Velocity });
    _ = transform;

    var world = try World.init(arena.child_allocator);
    var ent = world.createEntity();
    world.attach(ent, Position);

    std.debug.print("ent {}", .{ent});
}
