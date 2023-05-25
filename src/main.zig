const std = @import("std");
const expect = std.testing.expect;
const mem = @import("std").mem;

pub const Component = @import("./component.zig").Component;
pub const Archetype = @import("./archetype.zig").Archetype;
pub const Context = @import("./context.zig").Context;
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
    const Ecs = Context(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var context = try Ecs.init(.{
        .allocator = arena.child_allocator,
    });
    defer context.deinit();
    defer Ecs.contextDeinit(context.allocator);

    const Actor = Ecs.Type(.{ .Position, .Velocity });
    context.registerType(Actor);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nCreate {} entities with 2 comps with Prefab", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    Timer.start();

    while (i < n) : (i += 1) {
        _ = context.create(Actor);
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
    const Ecs = Context(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var context = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer context.deinit();
    defer Ecs.contextDeinit(context.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nCreate {} entities with 2 comps", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});
    Timer.start();

    while (i < n) : (i += 1) {
        var ent = context.createEmpty();

        context.attach(ent, .Position);
        context.attach(ent, .Velocity);
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
    const Ecs = Context(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var context = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer context.deinit();
    defer Ecs.contextDeinit(context.allocator);

    var i: u32 = 0;

    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nRemove and Add a Component in {} entities", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = context.createEmpty();

        context.attach(ent, .Position);
        context.attach(ent, .Velocity);
    }

    i = 1;

    Timer.start();
    while (i < n) : (i += 1) {
        context.detach(i, .Position);
        context.attach(i, .Position);
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
    const Ecs = Context(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var context = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer context.deinit();
    defer Ecs.contextDeinit(context.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nDelete {} Entity", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = context.createEmpty();

        context.attach(ent, .Position);
        context.attach(ent, .Velocity);
    }

    i = 1;
    Timer.start();
    while (i < n) : (i += 1) {
        _ = context.deleteEntity(i);
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
    const Ecs = Context(.{
        Position,
        Velocity,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var context = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer context.deinit();
    defer Ecs.contextDeinit(context.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nRead {} Entity Two Components", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = context.createEmpty();

        context.attach(ent, .Position);
        context.attach(ent, .Velocity);
    }

    var e: Entity = 1;

    var ent = context.createEmpty();
    context.attach(ent, .Position);
    context.attach(ent, .Velocity);

    var result: f128 = 0;

    Timer.start();
    while (e < n) : (e += 1) {
        var pos = context.read(e, .Position);

        var vel = context.read(e, .Velocity);
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

    const Ecs = Context(.{
        Pos,
        Vel,
    }, n);

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var context = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer context.deinit();
    defer Ecs.contextDeinit(context.allocator);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nread {} Entity Two Components Prop", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = context.createEmpty();

        context.attach(ent, .Pos);
        context.write(
            ent,
            .Pos,
            .{
                .x = @intToFloat(f32, i),
                .y = @intToFloat(f32, i + 1),
            },
        );

        context.attach(ent, .Vel);
        context.write(
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
        var posX = context.get(e, .Pos, .x);
        result += posX.*;
        var vel = context.get(e, .Vel, .x);
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
    const MyEcs = Context(.{ Position, Velocity }, n);

    var ecs = try MyEcs.init(.{ .allocator = std.heap.page_allocator });

    defer ecs.deinit();
    defer MyEcs.contextDeinit(ecs.allocator);

    const Sys = struct {
        fn move(context: *MyEcs, entity: Entity) void {
            var pos = context.pack(entity, .Position);
            var vel = context.read(entity, .Velocity);
            pos.x.* += vel.x;
            pos.y.* += vel.y;
        }
        fn moveSystem(context: *MyEcs) void {
            var query = context.query().all(.{ .Position, .Velocity }).execute();
            query.each(@This().move);

            // var iterator = context.query().all(.{ Position, Velocity }).execute().iterator();
            // while (iterator.next()) |entity| {
            //     var pos = context.read(entity, Position);
            //     var vel = context.read(entity, Velocity);

            //     context.write(entity, Position, .{
            //         .x = pos.x + vel.x,
            //         .y = pos.y + vel.y,
            //     });
            // }
        }
    };

    const Actor = MyEcs.Type(.{ .Position, .Velocity });
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
