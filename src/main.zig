const std = @import("std");
const expect = std.testing.expect;
const mem = @import("std").mem;

pub const Context = @import("./context.zig").Context;
pub const Entity = @import("./entity-storage.zig").Entity;
pub const Component = @import("./component.zig").Component;
pub const System = @import("./system.zig").System;
pub const Tag = @import("./component.zig").Tag;
pub const Archetype = @import("./archetype.zig").Archetype;
pub const SparseSet = @import("./sparse-set.zig").SparseSet;
pub const Query = @import("./query.zig").Query;
pub const FixedSizeBitset = @import("./fixed-size-bitset.zig").FixedSizeBitset;
pub const QueryBuilder = @import("./query.zig").QueryBuilder;

pub fn main() !void {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: i32,
                y: i32,
            }),
            Component("Velocity", struct {
                x: i32,
                y: i32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var query = ecs.query().all(.{ .Position, .Velocity }).execute();

    const setPos = (struct {
        pub fn setPos(context: *Ecs, entity: Entity) void {
            var x = context.get(entity, .Position, .x);
            x.* += 10;
        }
    }).setPos;

    query.onEnter(setPos);

    var entity = ecs.createEmpty();
    ecs.attach(entity, .Position);
    //init pos
    ecs.set(entity, .Position, .x, 0);
    ecs.attach(entity, .Velocity);

    var x = ecs.get(entity, .Position, .x);

    std.debug.print("x {}", .{x.*});
}

pub fn bench() !void {
    run(createEntitiesWithTwoComponents);

    run(createEntitiesWithTwoComponentsPrefab);

    run(removeAndAddAComponent);

    run(deleteEntities);

    run(readTwoComponents);

    run(readTwoComponentsProp);

    run(updateWith1System);
}

fn run(comptime function: anytype) void {
    function(16_000) catch unreachable;
    function(65_000) catch unreachable;
    function(262_000) catch unreachable;
    function(1_000_000) catch unreachable;
    function(2_000_000) catch unreachable;
}

fn createEntitiesWithTwoComponents(comptime n: u32) !void {
    const Ecs = Context(
        .{
            .components = .{
                Component("Position", struct {
                    x: f32,
                    y: f32,
                }),
                Component("Velocity", struct {
                    x: f32,
                    y: f32,
                }),
            },
            .Resources = struct {},
            .capacity = n,
        },
    );

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nCreate {} entities with 2 comps", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});
    Timer.start();

    while (i < n) : (i += 1) {
        var ent = ecs.createEmpty();

        ecs.attach(ent, .Position);
        ecs.attach(ent, .Velocity);
    }

    Timer.end();
}

fn createEntitiesWithTwoComponentsPrefab(comptime n: u32) !void {
    const Ecs = Context(
        .{
            .components = .{
                Component("Position", struct {
                    x: f32,
                    y: f32,
                }),
                Component("Velocity", struct {
                    x: f32,
                    y: f32,
                }),
            },
            .Resources = struct {},
            .capacity = n,
        },
    );

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    const Actor = Ecs.Type(.{ .Position, .Velocity });
    ecs.registerType(Actor);

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nCreate {} entities with 2 comps with Prefab", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    Timer.start();

    while (i < n) : (i += 1) {
        _ = ecs.create(Actor);
    }

    Timer.end();
}

fn removeAndAddAComponent(comptime n: u32) !void {
    const Ecs = Context(
        .{
            .components = .{
                Component("Position", struct {
                    x: f32,
                    y: f32,
                }),
                Component("Velocity", struct {
                    x: f32,
                    y: f32,
                }),
            },
            .Resources = struct {},
            .capacity = n,
        },
    );

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var i: u32 = 0;

    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nRemove and Add a Component in {} entities", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = ecs.createEmpty();

        ecs.attach(ent, .Position);
        ecs.attach(ent, .Velocity);
    }

    i = 1;

    Timer.start();
    while (i < n) : (i += 1) {
        ecs.detach(i, .Position);
        ecs.attach(i, .Position);
    }
    Timer.end();
}

fn deleteEntities(comptime n: u32) !void {
    const Ecs = Context(
        .{
            .components = .{
                Component("Position", struct {
                    x: f32,
                    y: f32,
                }),
                Component("Velocity", struct {
                    x: f32,
                    y: f32,
                }),
            },
            .Resources = struct {},
            .capacity = n,
        },
    );

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nDelete {} Entity", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = ecs.createEmpty();

        ecs.attach(ent, .Position);
        ecs.attach(ent, .Velocity);
    }

    i = 1;
    Timer.start();
    while (i < n) : (i += 1) {
        _ = ecs.deleteEntity(i);
    }
    Timer.end();
}

fn readTwoComponents(comptime n: u32) !void {
    const Ecs = Context(
        .{
            .components = .{
                Component("Position", struct {
                    x: f32,
                    y: f32,
                }),
                Component("Velocity", struct {
                    x: f32,
                    y: f32,
                }),
            },
            .Resources = struct {},
            .capacity = n,
        },
    );

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nRead {} Entity Two Components", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = ecs.createEmpty();

        ecs.attach(ent, .Position);
        ecs.attach(ent, .Velocity);
    }

    var e: Entity = 1;

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    var result: f128 = 0;

    Timer.start();
    while (e < n) : (e += 1) {
        var pos = ecs.pack(e, .Position);

        var vel = ecs.pack(e, .Velocity);
        _ = vel;
        // If we are not doing this the compiler will remove the loop in releas fast builds
        result += pos.x.*;
    }
    Timer.end();
}

fn readTwoComponentsProp(comptime n: u32) !void {
    const Ecs = Context(
        .{
            .components = .{
                Component("Position", struct {
                    x: f32,
                    y: f32,
                }),
                Component("Velocity", struct {
                    x: f32,
                    y: f32,
                }),
            },
            .Resources = struct {},
            .capacity = n,
        },
    );
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var i: u32 = 0;
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\nread {} Entity Two Components Prop", .{n});
    std.debug.print("\n-------------------------------", .{});
    std.debug.print("\n", .{});

    while (i < n) : (i += 1) {
        var ent = ecs.createEmpty();

        ecs.attach(ent, .Position);
        ecs.write(
            ent,
            .Position,
            .{
                .x = @intToFloat(f32, i),
                .y = @intToFloat(f32, i + 1),
            },
        );

        ecs.attach(ent, .Velocity);
        ecs.write(
            ent,
            .Velocity,
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
        var posX = ecs.get(e, .Position, .x);
        result += posX.*;
        var vel = ecs.get(e, .Velocity, .x);
        _ = vel;
    }

    Timer.end();
}

fn updateWith1System(comptime n: u32) !void {
    const Ecs = Context(
        .{
            .components = .{
                Component("Position", struct {
                    x: f32,
                    y: f32,
                }),
                Component("Velocity", struct {
                    x: f32,
                    y: f32,
                }),
            },
            .Resources = struct {},
            .capacity = n,
        },
    );

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    const Sys = struct {
        fn move(ctx: *Ecs, entity: Entity) void {
            var pos = ctx.pack(entity, .Position);
            var vel = ctx.pack(entity, .Velocity);
            pos.x.* += vel.x.*;
            pos.y.* += vel.y.*;
        }

        fn moveSystem(ctx: *Ecs) void {
            var query = ctx.query().all(.{ .Position, .Velocity }).execute();
            query.each(@This().move);

            // var iterator = ctx.query().all(.{ .Position, .Velocity }).execute().iterator();
            // var pos: Position.Schema = undefined;
            // var vel: Velocity.Schema = undefined;

            // while (iterator.next()) |entity| {
            //     ctx.copy(entity, .Position, &pos);
            //     ctx.copy(entity, .Velocity, &vel);

            //     ctx.write(entity, .Position, .{
            //         .x = pos.x + vel.x,
            //         .y = pos.y + vel.y,
            //     });
            // }
        }
    };

    const Actor = Ecs.Type(.{ .Position, .Velocity });
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
