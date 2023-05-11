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
const RawBitset = @import("./raw-bitset.zig").RawBitset;
const QueryBuilder = @import("./query.zig").QueryBuilder;

const Position = Component("Position", struct {
    x: f32,
    y: f32,
});
const Velocity = Component("Velocity", struct {
    x: f32,
    y: f32,
});

pub fn main() !void {
    try bench();
}

pub fn bench() !void {
    run(createEntitiesWithTwoComponents);

    run(createEntitiesWithTwoComponentsPrefab);

    run(removeAndAddAComponent);

    run(deleteEntities);

    run(unpackTwoComponents);

    run(unpackTwoComponentsPacked);
}

fn run(comptime function: anytype) void {
    function(16_000) catch unreachable;
    function(65_000) catch unreachable;
    function(262_000) catch unreachable;
    function(1_000_000) catch unreachable;
    function(2_000_000) catch unreachable;
}

fn createEntitiesWithTwoComponentsPrefab(comptime n: u32) !void {
    const Ecs = World(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{
        .allocator = arena.child_allocator,
    });
    defer world.deinit();
    defer Ecs.contextDeinit(world.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nCreate {} entities with 2 comps with Prefab", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});
    var before = std.time.milliTimestamp();

    const Actor = Ecs.Type(.{ Position, Velocity });
    world.registerType(Actor);

    while (i < n) : (i += 1) {
        _ = world.create(Actor);
    }

    var now = std.time.milliTimestamp();
    std.debug.print("\n", .{});
    std.debug.print("\nResults : {}ms", .{now - before});
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}

fn createEntitiesWithTwoComponents(comptime n: u32) !void {
    const Ecs = World(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer world.deinit();
    defer Ecs.contextDeinit(world.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nCreate {} entities with 2 comps", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});
    var before = std.time.milliTimestamp();

    while (i < n) : (i += 1) {
        var ent = world.createEmpty();

        world.attach(ent, &Position);
        world.attach(ent, &Velocity);
    }

    var now = std.time.milliTimestamp();
    std.debug.print("\n", .{});
    std.debug.print("\nResults : {}ms", .{now - before});
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}

fn removeAndAddAComponent(comptime n: u32) !void {
    const Ecs = World(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer world.deinit();
    defer Ecs.contextDeinit(world.allocator);

    var i: u32 = 0;

    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nRemove and Add a Component in {} entities", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = world.createEmpty();

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

fn deleteEntities(comptime n: u32) !void {
    const Ecs = World(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer world.deinit();
    defer Ecs.contextDeinit(world.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nDelete {} Entity", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = world.createEmpty();

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

fn unpackTwoComponents(comptime n: u32) !void {
    const Ecs = World(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer world.deinit();
    defer Ecs.contextDeinit(world.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nUnpack {} Entity Two Components", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = world.createEmpty();

        world.attach(ent, Position);
        world.attach(ent, Velocity);
    }

    var e: usize = 1;
    var before = std.time.milliTimestamp();

    while (e < n) : (e += 1) {
        _ = world.unpack(e, Position);
        _ = world.unpack(e, Velocity);
    }

    var now = std.time.milliTimestamp();
    std.debug.print("\n", .{});
    std.debug.print("\nResults : {}ms", .{now - before});
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}

fn unpackTwoComponentsPacked(comptime n: u32) !void {
    const Pos = Component("Pos", struct {
        x: f32,
        y: f32,
    });
    const Vel = Component("Vel", struct {
        x: f32,
        y: f32,
    });

    const Ecs = World(.{
        Pos,
        Vel,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer world.deinit();
    defer Ecs.contextDeinit(world.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nUnpack {} Entity Two Packed Components", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = world.createEmpty();

        world.attach(ent, Pos);
        world.attach(ent, Vel);
    }

    var e: usize = 1;
    var before = std.time.milliTimestamp();

    while (e < n) : (e += 1) {
        _ = world.get(e, Pos, "x");
        _ = world.get(e, Vel, "x");
    }

    var now = std.time.milliTimestamp();
    std.debug.print("\n", .{});
    std.debug.print("\nResults : {}ms", .{now - before});
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}
