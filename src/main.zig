const std = @import("std");
const expect = std.testing.expect;
const Component = @import("./component.zig").Component;
const defineComponent = @import("./component.zig").defineComponent;

const buildArchetype = @import("./archetype.zig").buildArchetype;
const generateComponentsMask = @import("./archetype.zig").generateComponentsMask;

const World = @import("./world.zig").World;
const Entity = @import("./world.zig").Entity;
const SparseSet = @import("./sparse-set.zig").SparseSet;

const Vector = struct { x: f64 = 0, y: f64 = 0 };

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);
    var transform = try buildArchetype(.{ Position, Velocity }, arena.child_allocator);
    _ = transform;

    var world = try World.init(arena.child_allocator);
    var ent = world.createEntity();
    try world.attach(ent, Position);

    std.debug.print("ent {}", .{ent});
}

test "Can attach component" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(arena.child_allocator);
    var ent = world.createEntity();

    try world.attach(ent, Position);

    try expect(world.has(ent, Position));
    try expect(!world.has(ent, Velocity));

    try world.attach(ent, Velocity);
    try expect(world.has(ent, Position));
    try expect(world.has(ent, Velocity));
}

test "Can detach component" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(arena.child_allocator);
    var ent = world.createEntity();

    try world.attach(ent, Position);
    try world.attach(ent, Velocity);
    try expect(world.has(ent, Position));
    try expect(world.has(ent, Velocity));

    try world.detach(ent, Position);
    try expect(!world.has(ent, Position));
    try expect(world.has(ent, Velocity));

    try world.detach(ent, Velocity);
    try expect(!world.has(ent, Velocity));
}
