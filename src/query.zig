const std = @import("std");
const print = @import("std").debug.print;
const Archetype = @import("./archetype.zig").Archetype;
const World = @import("./world.zig").World;
const Entity = @import("./world.zig").Entity;

fn numMasks(bit_length: usize) usize {
    return (bit_length + (@bitSizeOf(std.bit_set.DynamicBitSet.MaskInt) - 1)) / @bitSizeOf(std.bit_set.DynamicBitSet.MaskInt);
}
fn intersects(query: *std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
    const num_masks = numMasks(query.unmanaged.bit_length);

    for (query.unmanaged.masks[0..num_masks]) |*mask, i| {
        if (mask.* & other.unmanaged.masks[i] != mask.*) {
            return false;
        }
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
        self.mask.deinit();
    }

    fn execute(self: *Self, world: *World) void {
        for (world.archetypes.items) |*arch| {
            if (intersects(&self.mask, &arch.mask)) {
                _ = self.archetypes.append(arch) catch null;
            }
        }
    }
};

pub const QueryBuilder = struct {
    const Self = @This();

    mask: std.bit_set.DynamicBitSet,
    allocator: std.mem.Allocator,
    world: *World,

    pub fn init(allocator: std.mem.Allocator) !QueryBuilder {
        return QueryBuilder{ .mask = try std.bit_set.DynamicBitSet.initEmpty(allocator, 150), .allocator = allocator, .world = undefined };
    }

    pub fn deinit(self: *Self) void {
        self.mask.deinit();
    }

    pub fn with(self: *Self, component: anytype) *Self {
        self.mask.set(component.id);
        return self;
    }

    pub fn query(self: *Self) !Query {
        var created_query = Query{ .mask = try self.mask.clone(self.world.allocator), .archetypes = std.ArrayList(*Archetype).init(self.world.allocator) };
        self.mask.deinit();
        self.mask = try std.bit_set.DynamicBitSet.initEmpty(self.world.allocator, 500);
        created_query.execute(self.world);
        return created_query;
    }
};
