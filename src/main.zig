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

const Vector = struct { x: f64 = 0, y: f64 = 0 };
const Position = Component("Position", struct {
    x: f32,
    y: f32,
});
const Velocity = Component("Velocity", struct {
    x: f32,
    y: f32,
});

const Ecs = World(.{
    Position,
    Velocity,
});

pub fn main() !void {
    try bench();
}
// Benchmarks
pub fn bench() !void {
    const thresholds: [5]u32 = [_]u32{ 16_000, 65_000, 262_000, 1_000_000, 2_000_000 };

    for (thresholds[0..thresholds.len]) |n| {
        try createEntitiesWithTwoComponents(n);
    }

    for (thresholds[0..thresholds.len]) |n| {
        try createEntitiesWithTwoComponentsPrefab(n);
    }

    for (thresholds[0..thresholds.len]) |n| {
        try removeAndAddAComponent(n);
    }

    for (thresholds[0..thresholds.len]) |n| {
        try deleteEntities(n);
    }
}
fn createEntitiesWithTwoComponentsPrefab(n: u32) !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{
        .allocator = arena.child_allocator,
        .capacity = n,
    });
    defer world.deinit();

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nCreate {} entities with 2 comps with Prefab", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});
    var before = std.time.milliTimestamp();

    var actor = Ecs.Prefab(.{ Position, Velocity }){};

    while (i < n) : (i += 1) {
        _ = actor.create(&world);
    }

    var now = std.time.milliTimestamp();
    std.debug.print("\n", .{});
    std.debug.print("\nResults : {}ms", .{now - before});
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}

fn createEntitiesWithTwoComponents(n: u32) !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = n });
    defer world.deinit();

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nCreate {} entities with 2 comps", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});
    var before = std.time.milliTimestamp();

    while (i < n) : (i += 1) {
        var ent = world.createEntity();

        world.attach(ent, &Position);
        world.attach(ent, &Velocity);
    }

    var now = std.time.milliTimestamp();
    std.debug.print("\n", .{});
    std.debug.print("\nResults : {}ms", .{now - before});
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}

fn removeAndAddAComponent(n: u32) !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = n });
    defer world.deinit();

    var i: u32 = 0;

    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nRemove and Add a Component in {} entities", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = world.createEntity();

        world.attach(ent, &Position);
        world.attach(ent, &Velocity);
    }

    i = 1;
    var before = std.time.milliTimestamp();
    while (i < n) : (i += 1) {
        world.detach(i, Position);
        world.attach(i, Position);
    }

    var now = std.time.milliTimestamp();
    std.debug.print("\n", .{});
    std.debug.print("\nResults : {}ms", .{now - before});
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}

fn deleteEntities(n: u32) !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator, .capacity = n });
    defer world.deinit();

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nDelete {} Entity", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = world.createEntity();

        world.attach(ent, &Position);
        world.attach(ent, &Velocity);
    }

    i = 1;
    var before = std.time.milliTimestamp();
    while (i < n) : (i += 1) {
        _ = world.deleteEntity(i);
    }

    var now = std.time.milliTimestamp();
    std.debug.print("\n", .{});
    std.debug.print("\nResults : {}ms", .{now - before});
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}
