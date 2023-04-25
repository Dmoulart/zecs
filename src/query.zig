const std = @import("std");
const Archetype = @import("./archetype.zig").Archetype;
const World = @import("./world.zig").World;

pub const Query = struct {
    const Self = @This();

    mask: std.bit_set.DynamicBitSet,
    archetypes: []*Archetype,
};
pub const QueryBuilder = struct {
    const Self = @This();

    mask: std.bit_set.DynamicBitSet,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !QueryBuilder {
        var mask = try std.bit_set.DynamicBitSet.initEmpty(allocator, 1000);

        return QueryBuilder{
            .mask = mask,
            .allocator = allocator,
        };
    }

    pub fn with(self: *Self, component: anytype) *Self {
        self.mask.set(component.id);
        return self;
    }

    pub fn query(self: *Self, world: *World) Query {
        _ = world;
        return Query{ .mask = self.mask, .archetypes = undefined };
    }

    fn execute(world: *World) []*Archetype {
        var buffer: [100]Archetype = undefined;
        var archetypes = buffer[0..];
        _ = archetypes;
        var iterator = world.archetypes.iterator();
        var archetype = iterator.next();
        while (archetype != null) {
            if (archetype.?.key_ptr.*)
                archetype = iterator.next();
        }
    }
};
