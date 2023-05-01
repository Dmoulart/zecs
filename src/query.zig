const std = @import("std");
const print = @import("std").debug.print;
const Archetype = @import("./archetype.zig").Archetype;
const World = @import("./world.zig").World;
const Entity = @import("./entity-storage.zig").Entity;

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

pub const QueryIterator = struct {
    const Self = @This();
    archetypes: *std.ArrayList(*Archetype),

    current_archetype_index: usize = 0,
    current_entity_index: usize = 0,

    pub fn next(self: *Self) ?Entity {
        if (self.current_archetype_index < self.archetypes.items.len) {
            var archetype_entities = self.archetypes.items[self.current_archetype_index].entities;
            if (self.current_entity_index < archetype_entities.count) {
                self.current_entity_index += 1;
                return archetype_entities.values[self.current_entity_index - 1]; // entities start at 1
            } else {
                self.current_entity_index = 0;
                self.current_archetype_index += 1;
                return self.next();
            }
        } else {
            return null;
        }
    }

    pub fn count(self: *Self) u64 {
        var len: u64 = 0;
        for (self.archetypes.items) |arch| {
            len += arch.entities.count;
        }
        return len;
    }
};

pub const Query = struct {
    const Self = @This();

    mask: std.bit_set.DynamicBitSet,

    archetypes: std.ArrayList(*Archetype),

    // pub fn each(self: *Self, function: fn (entity: Entity) void) void {
    //     for (self.archetypes) |arch| {
    //         for (arch.values) |entity| {
    //             function(entity);
    //         }
    //     }
    // }

    pub fn iterator(self: *Self) QueryIterator {
        return QueryIterator{
            .archetypes = &self.archetypes,
        };
    }

    pub fn deinit(self: *Self) void {
        self.archetypes.deinit();
        self.mask.deinit();
    }

    fn execute(self: *Self, world: *World) void {
        for (world.archetypes.all.items) |*archetype| {
            if (intersects(&self.mask, &archetype.mask)) {
                _ = self.archetypes.append(archetype) catch null;
            }
        }
    }
};

pub const MAX_COMPONENTS_PER_QUERY = 100;

pub const QueryBuilder = struct {
    const Self = @This();

    mask: std.bit_set.DynamicBitSet,

    allocator: std.mem.Allocator,

    world: *World,

    pub fn init(allocator: std.mem.Allocator, world: *World) !QueryBuilder {
        return QueryBuilder{
            .mask = try std.bit_set.DynamicBitSet.initEmpty(allocator, MAX_COMPONENTS_PER_QUERY),
            .allocator = allocator,
            .world = world,
        };
    }

    pub fn deinit(self: *Self) void {
        self.mask.deinit();
    }

    pub fn with(self: *Self, component: anytype) *Self {
        self.mask.set(component.id);
        return self;
    }

    pub fn query(self: *Self) Query {
        var created_query = Query{
            .mask = self.mask.clone(self.allocator) catch unreachable,
            .archetypes = std.ArrayList(*Archetype).init(self.allocator),
        };

        self.mask.deinit();
        self.mask = std.bit_set.DynamicBitSet.initEmpty(self.world.allocator, MAX_COMPONENTS_PER_QUERY) catch unreachable;

        created_query.execute(self.world);

        return created_query;
    }
};
