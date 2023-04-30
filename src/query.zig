const std = @import("std");
const print = @import("std").debug.print;
const Archetype = @import("./archetype.zig").Archetype;
const World = @import("./world.zig").World;
const Entity = @import("./world.zig").Entity;

fn numMasks(bit_length: usize) usize {
    return (bit_length + (@bitSizeOf(std.bit_set.DynamicBitSet.MaskInt) - 1)) / @bitSizeOf(std.bit_set.DynamicBitSet.MaskInt);
}
fn intersects(bitset: *std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
    const num_masks = numMasks(bitset.unmanaged.bit_length);

    for (bitset.unmanaged.masks[0..num_masks]) |*mask, i| {
        if (mask.* & other.unmanaged.masks[i] == 0) return false;
    }
    return true;
}

pub const Query = struct {
    const Self = @This();

    mask: std.bit_set.DynamicBitSet,

    archetypes: std.ArrayList(*Archetype),

    pub fn each(self: *Self, function: fn (entity: Entity) void) void {
        for (self.archetypes) |arch| {
            for (arch.values) |entity| {
                function(entity);
            }
        }
    }

    pub fn deinit(self: *Self) void {
        self.archetypes.deinit();
    }

    fn execute(self: *Self, world: *World) void {
        for (world.archetypes.items) |*arch| {
            if (intersects(&arch.mask, &self.mask)) {
                _ = self.archetypes.append(arch) catch null;
            }
        }
    }
};

pub const QueryBuilder = struct {
    const Self = @This();

    mask: std.bit_set.DynamicBitSet,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !QueryBuilder {
        return QueryBuilder{
            .mask = try std.bit_set.DynamicBitSet.initEmpty(allocator, 40),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.mask.deinit();
    }

    pub fn with(self: *Self, component: anytype) *Self {
        self.mask.set(component.id);

        return self;
    }

    pub fn query(self: *Self, world: *World) !Query {
        var created_query = Query{ .mask = self.mask, .archetypes = std.ArrayList(*Archetype).init(world.allocator) };
        created_query.execute(world);
        return created_query;
    }
};
