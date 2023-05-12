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

    run(readTwoComponents);

    run(readTwoComponentsProp);
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

    const Actor = Ecs.Type(.{ Position, Velocity });
    world.registerType(Actor);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nCreate {} entities with 2 comps with Prefab", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    Timer.start();

    while (i < n) : (i += 1) {
        _ = world.create(Actor);
    }

    Timer.end();
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
    Timer.start();

    while (i < n) : (i += 1) {
        var ent = world.createEmpty();

        world.attach(ent, &Position);
        world.attach(ent, &Velocity);
    }

    Timer.end();
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

    Timer.start();
    while (i < n) : (i += 1) {
        world.detach(i, Position);
        world.attach(i, Position);
    }
    Timer.end();
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
    Timer.start();
    while (i < n) : (i += 1) {
        _ = world.deleteEntity(i);
    }
    Timer.end();
}

fn readTwoComponents(comptime n: u32) !void {
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
    std.debug.print("\nread {} Entity Two Components", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = world.createEmpty();

        world.attach(ent, Position);
        world.attach(ent, Velocity);
    }

    var e: usize = 1;

    var ent = world.createEmpty();
    world.attach(ent, Position);
    world.attach(ent, Velocity);

    var result: f128 = 0;

    Timer.start();
    while (e < n) : (e += 1) {
        var pos = world.read(e, Position);

        var vel = world.read(e, Velocity);
        _ = vel;
        // If we are not doing this the compiler will remove the loop in releas fast builds
        result += pos.x;
    }
    Timer.end();

    std.debug.print("res {}", .{result});
}

fn readTwoComponentsProp(comptime n: u32) !void {
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
    std.debug.print("\nread {} Entity Two Components Prop", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = world.createEmpty();

        world.attach(ent, Pos);
        world.write(
            ent,
            Pos,
            .{ .x = @intToFloat(f32, i), .y = @intToFloat(f32, i + 1) },
        );

        world.attach(ent, Vel);
        world.write(
            ent,
            Vel,
            .{ .x = @intToFloat(f32, i), .y = @intToFloat(f32, i + 1) },
        );
    }

    var e: usize = 1;
    var result: f128 = 0;
    Timer.start();

    while (e < n) : (e += 1) {
        var pos = world.get(e, Pos, "x");
        result += pos.*;
        var vel = world.get(e, Vel, "x");
        _ = vel;
    }

    Timer.end();
}

const Timer = struct {
    pub var before: i64 = 0;
    pub var after: i64 = 0;

    pub var nano_before: i128 = 0;
    pub var nano_after: i128 = 0;

    pub fn start() void {
        before = std.time.milliTimestamp();
    }

    pub fn nanoStart() void {
        nano_before = std.time.nanoTimestamp();
    }

    pub fn end() void {
        after = std.time.milliTimestamp();

        std.debug.print("\n", .{});
        std.debug.print("\nResults : {} ms", .{after - before});
        std.debug.print("\n", .{});
        std.debug.print("\n", .{});
    }

    pub fn nanoEnd() void {
        nano_after = std.time.nanoTimestamp();

        std.debug.print("\n", .{});
        std.debug.print("\nResults : {} ns", .{nano_after - nano_before});
        std.debug.print("\n", .{});
        std.debug.print("\n", .{});
    }
};
