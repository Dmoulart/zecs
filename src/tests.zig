const std = @import("std");
const expect = std.testing.expect;
const mem = @import("std").mem;

const Component = @import("./component.zig").Component;
const defineComponent = @import("./component.zig").defineComponent;
const Archetype = @import("./archetype.zig").Archetype;
const World = @import("./world.zig").World;
const Entity = @import("./world.zig").Entity;
const SparseSet = @import("./sparse-set.zig").SparseSet;
const Query = @import("./query.zig").Query;
const QueryBuilder = @import("./query.zig").QueryBuilder;
const RawBitset = @import("./raw-bitset.zig").RawBitset;

const Vector = struct { x: f64 = 0, y: f64 = 0 };

test "Can create Entity" {
    const Ecs = World(.{});

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();

    try expect(ent == 1);
}

test "Can remove Entity" {
    const Ecs = World(.{});

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    world.deleteEntity(ent);

    try expect(!world.contains(ent));
}

test "Can resize" {
    const Ecs = World(.{});

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{
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

    try expect(world.entities.capacity == 4 * 2); // grow factor of 2?
}

test "Can recycle Entity" {
    const Ecs = World(.{});

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    try expect(world.contains(ent));

    world.deleteEntity(ent);
    try expect(!world.contains(ent));

    var ent2 = world.createEntity();
    try expect(ent2 == ent);
}

test "Can attach component" {
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);

    const Ecs = World(.{
        Position,
        Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
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
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);

    const Ecs = World(.{
        Position,
        Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
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
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);

    const Ecs = World(.{
        Position,
        Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();

    world.attach(ent, Position);
    var mask: RawBitset = world.archetypes.all.items[1].mask;

    try expect(mask.has(Ecs.components.Position.id));
    try expect(!mask.has(Ecs.components.Velocity.id));
}

test "Query can target argetype" {
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);

    const Ecs = World(.{
        Position,
        Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{
        .allocator = arena.child_allocator,
        .capacity = 100,
    });
    defer world.deinit();

    var ent = world.createEntity();

    world.attach(ent, Position);

    var query = world.query().any(.{Position}).execute();
    defer query.deinit();

    try expect(query.archetypes.items[0] == &world.archetypes.all.items[1]);
}

test "Query update reactively" {
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);

    const Ecs = World(.{
        Position,
        Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    world.attach(ent, Position);

    var ent2 = world.createEntity();
    world.attach(ent2, Velocity);

    var query = world.query().all(.{Position}).execute();
    defer query.deinit();

    try expect(query.has(ent));
    try expect(!query.has(ent2));

    var query2 = world.query().all(.{Velocity}).execute();
    defer query2.deinit();

    try expect(!query2.has(ent));
    try expect(query2.has(ent2));

    world.detach(ent, Position);
    world.attach(ent, Velocity);

    try expect(query2.has(ent));
    try expect(!query.has(ent));
}

test "Can query multiple components" {
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);

    const Ecs = World(.{
        Position,
        Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    var ent2 = world.createEntity();

    world.attach(ent, Position);
    world.attach(ent, Velocity);

    world.attach(ent2, Position);

    var query = world.query().all(.{ Position, Velocity }).execute();
    defer query.deinit();

    try expect(query.has(ent));
    try expect(!query.has(ent2));

    var query2 = world.query().all(.{Position}).execute();
    defer query2.deinit();

    try expect(query2.has(ent));
    try expect(query2.has(ent2));

    world.attach(ent2, Velocity);

    try expect(query.has(ent2));
    try expect(query2.has(ent2));
}

test "Can iterate over query using iterator " {
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);

    const Ecs = World(.{
        Position,
        Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    world.attach(ent, Position);
    world.attach(ent, Velocity);

    var ent2 = world.createEntity();
    world.attach(ent2, Position);
    world.attach(ent2, Velocity);

    var query = world.query().all(.{ Position, Velocity }).execute();
    defer query.deinit();

    var iterator = query.iterator();
    var counter: i32 = 0;

    while (iterator.next()) |_| {
        counter += 1;
    }

    try expect(counter == 2);
}

test "Can use the all query operator" {
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);

    const Ecs = World(.{
        Position,
        Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    world.attach(ent, Position);
    world.attach(ent, Velocity);

    var ent2 = world.createEntity();
    world.attach(ent2, Position);
    world.attach(ent2, Velocity);

    var ent3 = world.createEntity();
    world.attach(ent3, Position);

    var ent4 = world.createEntity();
    world.attach(ent4, Velocity);

    var query = world.query().all(.{ Position, Velocity }).execute();
    defer query.deinit();

    // try expect(query.archetypes.items.len == 1);
    try expect(query.has(ent));
    try expect(query.has(ent2));
}

test "Can use the any query operator" {
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);

    const Ecs = World(.{
        Position,
        Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    world.attach(ent, Position);
    world.attach(ent, Velocity);

    var ent2 = world.createEntity();
    world.attach(ent2, Position);

    var ent3 = world.createEntity();
    world.attach(ent3, Velocity);

    var result = world.query().any(.{ Position, Velocity }).execute();
    defer result.deinit();

    try expect(result.archetypes.items.len == 3);
}

test "Can use the not operator" {
    const Position = Component("Position", Vector);
    const Velocity = Component("Velocity", Vector);
    const Health = Component("Health", struct { points: u32 });

    const Ecs = World(.{ Position, Velocity, Health });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    world.attach(ent, Position);
    world.attach(ent, Health);

    var ent2 = world.createEntity();
    world.attach(ent2, Velocity);

    var ent3 = world.createEntity();
    world.attach(ent3, Position);

    var query = world.query().not(.{ Velocity, Health }).execute();
    defer query.deinit();

    // Take into account the root archetype
    try expect(query.archetypes.items.len == 2);
    try expect(query.archetypes.items[1].entities.has(ent3));
}

test "Can use the none operator" {
    const Comp1 = Component("Comp1", Vector);
    const Comp2 = Component("Comp2", Vector);
    const Comp3 = Component("Comp3", struct { points: u32 });

    const Ecs = World(.{ Comp1, Comp2, Comp3 });
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    world.attach(ent, Comp1);
    world.attach(ent, Comp2);

    var ent2 = world.createEntity();
    world.attach(ent2, Comp3);

    var query = world.query().none(.{ Comp1, Comp2 }).execute();
    defer query.deinit();

    try expect(!query.has(ent));
}

test "Can combine query operators" {
    const Comp1 = Component("Comp1", Vector);
    const Comp2 = Component("Comp2", Vector);
    const Comp3 = Component("Comp3", struct { points: u32 });
    const Comp4 = Component("Comp4", struct { points: u32 });

    const Ecs = World(.{
        Comp1,
        Comp2,
        Comp3,
        Comp4,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = 100 });
    defer world.deinit();

    var ent = world.createEntity();
    world.attach(ent, Comp1);

    var ent2 = world.createEntity();
    world.attach(ent2, Comp1);
    world.attach(ent2, Comp2);
    world.attach(ent2, Comp3);

    var ent3 = world.createEntity();
    world.attach(ent3, Comp3);
    world.attach(ent3, Comp4);

    var ent4 = world.createEntity();
    world.attach(ent4, Comp1);
    world.attach(ent4, Comp4);

    var query = world.query()
        .not(.{Comp2})
        .any(.{ Comp3, Comp4, Comp1 })
        .none(.{ Comp1, Comp4 })
        .execute();

    defer query.deinit();

    try expect(query.has(ent));
    try expect(!query.has(ent2));
    try expect(query.has(ent3));
    try expect(!query.has(ent4));
}
