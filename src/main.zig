const std = @import("std");
const expect = std.testing.expect;
const mem = @import("std").mem;

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

    var world = try World.init(arena.child_allocator);
    defer world.deinit();

    var ent = world.createEntity();
    var ent2 = world.createEntity();

    try world.attach(ent, Position);
    try world.attach(ent2, Velocity);

    var query = try world.entities().with(Position).query();
    defer query.deinit();

    var query2 = try world.entities().with(Velocity).query();
    defer query2.deinit();
}

test "Can attach component" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(arena.child_allocator);
    defer world.deinit();

    var ent = world.createEntity();

    try world.attach(ent, Position);

    try expect(world.has(ent, Position));
    try expect(!world.has(ent, Velocity));

    try world.attach(ent, Velocity);
    try expect(world.has(ent, Position));
    try expect(world.has(ent, Velocity));
}

test "Can detach component" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(arena.child_allocator);
    defer world.deinit();

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

test "Can generate archetype" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(arena.child_allocator);
    defer world.deinit();

    var ent = world.createEntity();

    try world.attach(ent, Position);
    var mask: std.bit_set.DynamicBitSet = world.archetypes.items[1].mask;

    try expect(mask.isSet(Position.id));
    try expect(!mask.isSet(Velocity.id));
}

test "Query can target argetype" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);

    var world = try World.init(arena.child_allocator);
    defer world.deinit();

    var ent = world.createEntity();

    try world.attach(ent, Position);

    var query = try world.entities().with(Position).query();
    defer query.deinit();

    try expect(query.archetypes.items[0] == &world.archetypes.items[1]);
}

test "Can update query reactively" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(arena.child_allocator);
    defer world.deinit();

    var ent = world.createEntity();
    var ent2 = world.createEntity();

    try world.attach(ent, Position);
    try world.attach(ent2, Velocity);

    var query = try world.entities().with(Position).query();
    defer query.deinit();

    try expect(query.archetypes.items[0].entities.has(ent));
    try expect(!query.archetypes.items[0].entities.has(ent2));

    var query2 = try world.entities().with(Velocity).query();
    defer query2.deinit();

    try expect(!query2.archetypes.items[0].entities.has(ent));
    try expect(query2.archetypes.items[0].entities.has(ent2));

    try world.detach(ent, Position);
    try world.attach(ent, Velocity);

    try expect(query2.archetypes.items[0].entities.has(ent));
    try expect(!query.archetypes.items[0].entities.has(ent));
}

test "Can query multiple components" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(arena.child_allocator);
    defer world.deinit();

    var ent = world.createEntity();
    var ent2 = world.createEntity();

    try world.attach(ent, Position);
    try world.attach(ent, Velocity);

    try world.attach(ent2, Position);

    var query = try world.entities().with(Position).with(Velocity).query();
    defer query.deinit();

    try expect(query.archetypes.items[0].entities.has(ent));
    try expect(!query.archetypes.items[0].entities.has(ent2));

    var query2 = try world.entities().with(Position).query();
    defer query2.deinit();

    try expect(!query2.archetypes.items[0].entities.has(ent));
    try expect(query2.archetypes.items[0].entities.has(ent2));

    try world.attach(ent2, Velocity);

    try expect(query.archetypes.items[0].entities.has(ent2));
    try expect(!query2.archetypes.items[0].entities.has(ent2));
}
