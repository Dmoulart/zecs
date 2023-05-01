const std = @import("std");
const expect = std.testing.expect;
const mem = @import("std").mem;

const Component = @import("./component.zig").Component;
const defineComponent = @import("./component.zig").defineComponent;

const Archetype = @import("./archetype.zig").Archetype;

const World = @import("./world.zig").World;
const Entity = @import("./world.zig").Entity;
const SparseSet = @import("./sparse-set.zig").SparseSet;

const Vector = struct { x: f64 = 0, y: f64 = 0 };

pub fn main() !void {

    // _ = world.createEntity();

    // try expect(world.capacity == 8);
    // try expect(world.entitiesArchetypes.capacity() > 8);

    // var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();

    // const Position = defineComponent(Vector);
    // const Velocity = defineComponent(Vector);

    // var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    // defer world.deinit();
    // var i: u64 = 0;

    // while (i < 1_000_000) {
    //     var ent = world.createEntity();
    //     world.attach(ent, Position);
    //     world.attach(ent, Velocity);
    //     i += 1;
    // }

    // var query = world.query().with(Position).with(Velocity).query();
    // defer query.deinit();

    // var iterator = query.iterator();
    // var counter: u128 = 0;
    // var ts = std.time.milliTimestamp();
    // std.debug.print("\n iterator.count {}", .{iterator.count()});
    // while (iterator.next()) |_| {
    //     counter += 1;
    //     // world.detach(ent, Position);
    // }
    // std.debug.print("\n counter {}", .{counter});
    // std.debug.print("\nduration {}", .{std.time.milliTimestamp() - ts});
}

test "Can create Entity" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();

    try expect(ent == 1);
}

test "Can remove Entity" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();
    world.deleteEntity(ent);

    try expect(!world.contains(ent));
}

test "Can resize" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try World.init(.{
        .allocator = arena.child_allocator,
        .capacity = 4,
    });
    defer world.deinit();

    _ = world.createEntity();
    _ = world.createEntity();
    _ = world.createEntity();
    _ = world.createEntity();

    try expect(world.entities.capacity == 4);

    _ = world.createEntity();

    try expect(world.entities.capacity == 4 * 2);
}

test "Can reuse Entity" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();
    world.deleteEntity(ent);

    var ent2 = world.createEntity();

    try expect(ent2 == 1);
}

test "Can attach component" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();

    world.attach(ent, Position);

    try expect(world.has(ent, Position));
    try expect(!world.has(ent, Velocity));

    world.attach(ent, Velocity);
    try expect(world.has(ent, Position));
    try expect(world.has(ent, Velocity));
}

test "Can detach component" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();

    world.attach(ent, Position);
    world.attach(ent, Velocity);
    try expect(world.has(ent, Position));
    try expect(world.has(ent, Velocity));

    world.detach(ent, Position);
    try expect(!world.has(ent, Position));
    try expect(world.has(ent, Velocity));

    world.detach(ent, Velocity);
    try expect(!world.has(ent, Velocity));
}

test "Can generate archetype" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();

    world.attach(ent, Position);
    var mask: std.bit_set.DynamicBitSet = world.archetypes.all.items[1].mask;

    try expect(mask.isSet(Position.id));
    try expect(!mask.isSet(Velocity.id));
}

test "Query can target argetype" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();

    world.attach(ent, Position);

    var query = world.query().with(Position).from(&world);
    defer query.deinit();

    try expect(query.archetypes.items[0] == &world.archetypes.all.items[1]);
}

test "Can update query reactively" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();
    var ent2 = world.createEntity();

    world.attach(ent, Position);
    world.attach(ent2, Velocity);

    var query = world.query().with(Position).from(&world);
    defer query.deinit();

    try expect(query.archetypes.items[0].entities.has(ent));
    try expect(!query.archetypes.items[0].entities.has(ent2));

    var query2 = world.query().with(Velocity).from(&world);
    defer query2.deinit();

    try expect(!query2.archetypes.items[0].entities.has(ent));
    try expect(query2.archetypes.items[0].entities.has(ent2));

    world.detach(ent, Position);
    world.attach(ent, Velocity);

    try expect(query2.archetypes.items[0].entities.has(ent));
    try expect(!query.archetypes.items[0].entities.has(ent));
}

test "Can query multiple components" {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();
    var ent2 = world.createEntity();

    world.attach(ent, Position);
    world.attach(ent, Velocity);

    world.attach(ent2, Position);

    var query = world.query().with(Position).with(Velocity).from(&world);
    defer query.deinit();

    try expect(query.archetypes.items[0].entities.has(ent));
    try expect(!query.archetypes.items[0].entities.has(ent2));

    var query2 = world.query().with(Position).from(&world);
    defer query2.deinit();

    try expect(!query2.archetypes.items[0].entities.has(ent));
    try expect(query2.archetypes.items[0].entities.has(ent2));

    world.attach(ent2, Velocity);

    try expect(query.archetypes.items[0].entities.has(ent2));
    try expect(!query2.archetypes.items[0].entities.has(ent2));
}

test "Can iterate over query " {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();
    var ent2 = world.createEntity();

    world.attach(ent, Position);
    world.attach(ent, Velocity);

    world.attach(ent2, Position);
    world.attach(ent2, Velocity);

    var query = world.query().with(Position).with(Velocity).from(&world);
    defer query.deinit();
}

test "Can iterate over query using iterator " {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Position = defineComponent(Vector);
    const Velocity = defineComponent(Vector);

    var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = 10_000 });
    defer world.deinit();

    var ent = world.createEntity();
    var ent2 = world.createEntity();

    world.attach(ent, Position);
    world.attach(ent, Velocity);

    world.attach(ent2, Position);
    world.attach(ent2, Velocity);

    var query = world.query().with(Position).with(Velocity).from(&world);
    defer query.deinit();

    var iterator = query.iterator();
    var counter: i32 = 0;

    while (iterator.next()) |_| {
        counter += 1;
    }

    try expect(counter == 2);
}
