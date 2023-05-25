const std = @import("std");
const expect = std.testing.expect;
const mem = @import("std").mem;

const Component = @import("./component.zig").Component;
const defineComponent = @import("./component.zig").defineComponent;
const Archetype = @import("./archetype.zig").Archetype;
const Context = @import("./context.zig").Context;
const Entity = @import("./context.zig").Entity;
const SparseSet = @import("./sparse-set.zig").SparseSet;
const Query = @import("./query.zig").Query;
const QueryBuilder = @import("./query.zig").QueryBuilder;
const RawBitset = @import("./raw-bitset.zig").RawBitset;

test "Can create Entity" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 1);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();

    try expect(ent == 1);
}

test "Can remove Entity" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 1);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.deleteEntity(ent);

    try expect(!ecs.contains(ent));
}

test "Can resize" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 4);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    _ = ecs.createEmpty();
    _ = ecs.createEmpty();
    _ = ecs.createEmpty();
    _ = ecs.createEmpty();

    try expect(ecs.entities.capacity == 4);

    _ = ecs.createEmpty();

    try expect(ecs.entities.capacity == 4 * 2); // grow factor of 2?
}

test "Can recycle Entity" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    try expect(ecs.contains(ent));

    ecs.deleteEntity(ent);
    try expect(!ecs.contains(ent));

    var ent2 = ecs.createEmpty();
    try expect(ent2 == ent);
}

test "Can attach component" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();

    ecs.attach(ent, .Position);
    try expect(ecs.has(ent, .Position));
    try expect(!ecs.has(ent, .Velocity));

    ecs.attach(ent, .Velocity);
    try expect(ecs.has(ent, .Position));
    try expect(ecs.has(ent, .Velocity));
}

test "Can detach component" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    try expect(ecs.has(ent, .Position));
    try expect(ecs.has(ent, .Velocity));

    ecs.detach(ent, .Position);
    try expect(!ecs.has(ent, .Position));
    try expect(ecs.has(ent, .Velocity));

    ecs.detach(ent, .Velocity);
    try expect(!ecs.has(ent, .Velocity));
}

test "Can generate archetype" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();

    ecs.attach(ent, .Position);
    var mask: RawBitset = ecs.archetypes.all.items[1].mask;

    try expect(mask.has(Ecs.components.Position.id));
    try expect(!mask.has(Ecs.components.Velocity.id));
}

test "Query can target argetype" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();

    ecs.attach(ent, .Position);

    var query = ecs.query().any(.{.Position}).execute();

    try expect(query.archetypes.items[0] == &ecs.archetypes.all.items[1]);
}

test "Query update reactively" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Velocity);

    var query = ecs.query().all(.{.Position}).execute();

    try expect(query.contains(ent));
    try expect(!query.contains(ent2));

    var query2 = ecs.query().all(.{.Velocity}).execute();
    defer query2.deinit();

    try expect(!query2.contains(ent));
    try expect(query2.contains(ent2));

    ecs.detach(ent, .Position);
    ecs.attach(ent, .Velocity);

    try expect(query2.contains(ent));
    try expect(!query.contains(ent));
}

test "Can query multiple components" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    var ent2 = ecs.createEmpty();

    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    ecs.attach(ent2, .Position);

    var query = ecs.query().all(.{ .Position, .Velocity }).execute();

    try expect(query.contains(ent));
    try expect(!query.contains(ent2));

    var query2 = ecs.query().all(.{.Position}).execute();
    defer query2.deinit();

    try expect(query2.contains(ent));
    try expect(query2.contains(ent2));

    ecs.attach(ent2, .Velocity);

    try expect(query.contains(ent2));
    try expect(query2.contains(ent2));
}

test "Can iterate over query using iterator " {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Position);
    ecs.attach(ent2, .Velocity);

    var query = ecs.query().all(.{ .Position, .Velocity }).execute();

    var iterator = query.iterator();
    var counter: i32 = 0;

    while (iterator.next()) |_| {
        counter += 1;
    }

    try expect(counter == 2);
}

test "Can use the all query operator" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Position);
    ecs.attach(ent2, .Velocity);

    var ent3 = ecs.createEmpty();
    ecs.attach(ent3, .Position);

    var ent4 = ecs.createEmpty();
    ecs.attach(ent4, .Velocity);

    var query = ecs.query().all(.{ .Position, .Velocity }).execute();

    try expect(query.contains(ent));
    try expect(query.contains(ent2));
}

test "Can use the any query operator" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Position);

    var ent3 = ecs.createEmpty();
    ecs.attach(ent3, .Velocity);

    var result = ecs.query().any(.{ .Position, .Velocity }).execute();
    defer result.deinit();

    try expect(result.archetypes.items.len == 3);
}

test "Can use the not operator" {
    const Ecs = Context(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
        Component(
            "Health",
            struct { points: u32 },
        ),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Health);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Velocity);

    var ent3 = ecs.createEmpty();
    ecs.attach(ent3, .Position);

    var query = ecs.query().not(.{ .Velocity, .Health }).execute();

    // Take into account the root archetype
    try expect(query.archetypes.items.len == 2);
    try expect(query.archetypes.items[1].entities.has(ent3));
}

test "Can use the none operator" {
    const Ecs = Context(.{
        Component("Comp1", struct {
            x: f32,
            y: f32,
        }),
        Component("Comp2", struct {
            x: f32,
            y: f32,
        }),
        Component(
            "Comp3",
            struct {
                points: u32,
            },
        ),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Comp1);
    ecs.attach(ent, .Comp2);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Comp3);

    var query = ecs.query().none(.{ .Comp1, .Comp2 }).execute();

    try expect(!query.contains(ent));
}

test "Can combine query operators" {
    const Ecs = Context(.{
        Component("Comp1", struct {
            x: f32,
            y: f32,
        }),
        Component("Comp2", struct {
            x: f32,
            y: f32,
        }),
        Component(
            "Comp3",
            struct {
                points: u32,
            },
        ),
        Component(
            "Comp4",
            struct {
                points: u32,
            },
        ),
    }, 10);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Comp1);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Comp1);
    ecs.attach(ent2, .Comp2);
    ecs.attach(ent2, .Comp3);

    var ent3 = ecs.createEmpty();
    ecs.attach(ent3, .Comp3);
    ecs.attach(ent3, .Comp4);

    var ent4 = ecs.createEmpty();
    ecs.attach(ent4, .Comp1);
    ecs.attach(ent4, .Comp4);

    var query = ecs.query()
        .not(.{.Comp2})
        .any(.{ .Comp3, .Comp4, .Comp1 })
        .none(.{ .Comp1, .Comp4 })
        .execute();

    try expect(query.contains(ent));
    try expect(!query.contains(ent2));
    try expect(query.contains(ent3));
    try expect(!query.contains(ent4));
}
