const std = @import("std");
const expect = std.testing.expect;
const mem = @import("std").mem;

pub const Component = @import("./component.zig").Component;
pub const Archetype = @import("./archetype.zig").Archetype;
pub const World = @import("./world.zig").World;
pub const Entity = @import("./entity-storage.zig").Entity;
pub const System = @import("./system.zig").System;
pub const SparseSet = @import("./sparse-set.zig").SparseSet;
pub const Query = @import("./query.zig").Query;
pub const RawBitset = @import("./raw-bitset.zig").RawBitset;
pub const QueryBuilder = @import("./query.zig").QueryBuilder;

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

    run(updateWith3Systems);
}

fn run(comptime function: anytype) void {
    function(16_000) catch unreachable;
    function(65_000) catch unreachable;
    function(262_000) catch unreachable;
    function(1_000_000) catch unreachable;
    function(2_000_000) catch unreachable;
}

fn createEntitiesWithTwoComponentsPrefab(comptime n: u32) !void {
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

        world.attach(ent, .Position);
        world.attach(ent, .Velocity);
    }

    Timer.end();
}

fn removeAndAddAComponent(comptime n: u32) !void {
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

        world.attach(ent, .Position);
        world.attach(ent, .Velocity);
    }

    i = 1;

    Timer.start();
    while (i < n) : (i += 1) {
        world.detach(i, .Position);
        world.attach(i, .Position);
    }
    Timer.end();
}

fn deleteEntities(comptime n: u32) !void {
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

        world.attach(ent, .Position);
        world.attach(ent, .Velocity);
    }

    i = 1;
    Timer.start();
    while (i < n) : (i += 1) {
        _ = world.deleteEntity(i);
    }
    Timer.end();
}

fn readTwoComponents(comptime n: u32) !void {
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
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var world = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer world.deinit();
    defer Ecs.contextDeinit(world.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nRead {} Entity Two Components", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = world.createEmpty();

        world.attach(ent, .Position);
        world.attach(ent, .Velocity);
    }

    var e: Entity = 1;

    var ent = world.createEmpty();
    world.attach(ent, .Position);
    world.attach(ent, .Velocity);

    var result: f128 = 0;

    Timer.start();
    while (e < n) : (e += 1) {
        var pos = world.read(e, .Position);

        var vel = world.read(e, .Velocity);
        _ = vel;
        // If we are not doing this the compiler will remove the loop in releas fast builds
        result += pos.x;
    }
    Timer.end();
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

        world.attach(ent, .Pos);
        world.write(
            ent,
            .Pos,
            .{
                .x = @intToFloat(f32, i),
                .y = @intToFloat(f32, i + 1),
            },
        );

        world.attach(ent, .Vel);
        world.write(
            ent,
            .Vel,
            .{
                .x = @intToFloat(f32, i),
                .y = @intToFloat(f32, i + 1),
            },
        );
    }

    var e: Entity = 1;
    var result: f128 = 0;
    Timer.start();

    while (e < n) : (e += 1) {
        var posX = world.get(e, .Pos, .x);
        result += posX.*;
        var vel = world.get(e, .Vel, .x);
        _ = vel;
    }

    Timer.end();
}

fn updateWith3Systems(comptime n: u32) !void {
    const Position = Component("Position", struct {
        x: f32,
        y: f32,
    });
    const Velocity = Component("Velocity", struct {
        x: f32,
        y: f32,
    });
    const MyEcs = World(.{ Position, Velocity }, n);

    var ecs = try MyEcs.init(.{ .allocator = std.heap.page_allocator });

    defer ecs.deinit();
    defer MyEcs.contextDeinit(ecs.allocator);

    const Sys = struct {
        fn move(world: *MyEcs, entity: Entity) void {
            var pos = world.pack(entity, .Position);
            var vel = world.read(entity, .Velocity);
            pos.x.* += vel.x;
            pos.y.* += vel.y;
        }
        fn moveSystem(world: *MyEcs) void {
            var query = world.query().all(.{ .Position, .Velocity }).execute();
            query.each(@This().move);

            // var iterator = world.query().all(.{ Position, Velocity }).execute().iterator();
            // while (iterator.next()) |entity| {
            //     var pos = world.read(entity, Position);
            //     var vel = world.read(entity, Velocity);

            //     world.write(entity, Position, .{
            //         .x = pos.x + vel.x,
            //         .y = pos.y + vel.y,
            //     });
            // }
        }
    };

    const Actor = MyEcs.Type(.{ Position, Velocity });
    ecs.registerType(Actor);

    var i: u32 = 0;

    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nUpdate {} entities with one system", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    ecs.addSystem(Sys.moveSystem);

    while (i < n) : (i += 1) {
        _ = ecs.create(Actor);
    }

    i = 0;

    Timer.start();

    ecs.step();

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
