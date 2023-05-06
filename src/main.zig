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

// Benchmarks
pub fn main() !void {
    {
        var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const Position = defineComponent(Vector);
        const Velocity = defineComponent(Vector);

        const n: u32 = 262_000;
        var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = n });
        defer world.deinit();

        var i: u32 = 0;

        std.debug.print("\nCreate {} entities with 2 comps", .{n});
        var before = std.time.milliTimestamp();

        while (i < n) : (i += 1) {
            var ent = world.createEntity();

            world.attach(ent, &Position);
            world.attach(ent, &Velocity);
        }

        var now = std.time.milliTimestamp();
        std.debug.print("\n{}ms", .{now - before});

        var query = world.query().any(.{Position}).execute();
        defer query.deinit();
    }
    {
        var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const Position = defineComponent(Vector);
        const Velocity = defineComponent(Vector);

        const n: u32 = 262_000;
        var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = n });
        defer world.deinit();

        var i: u32 = 0;

        std.debug.print("\nRemove and Add a Component in {} entities", .{n});

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
        std.debug.print("\n{}ms", .{now - before});

        var query = world.query().any(.{Position}).execute();
        defer query.deinit();
    }
    {
        var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const Position = defineComponent(Vector);
        const Velocity = defineComponent(Vector);

        const n: u32 = 100_000;
        var world = try World.init(.{ .allocator = arena.child_allocator, .capacity = n });
        defer world.deinit();

        var i: u32 = 0;

        std.debug.print("\nDelete {} Entity", .{n});

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
        std.debug.print("\n{}ms", .{now - before});

        var query = world.query().any(.{Position}).execute();
        defer query.deinit();
    }
}
