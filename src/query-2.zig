const std = @import("std");
const print = @import("std").debug.print;
const Archetype = @import("./archetype.zig").Archetype;
const World = @import("./world.zig").World;
const Entity = @import("./entity-storage.zig").Entity;

fn numMasks(bit_length: usize) usize {
    return (bit_length + (@bitSizeOf(std.bit_set.DynamicBitSet.MaskInt) - 1)) / @bitSizeOf(std.bit_set.DynamicBitSet.MaskInt);
}
fn contains(bitset: *std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
    const num_masks = numMasks(bitset.unmanaged.bit_length);

    for (bitset.unmanaged.masks[0..num_masks]) |*mask, i| {
        if (mask.* & other.unmanaged.masks[i] != mask.*) {
            return false;
        }
    }

    return true;
}
fn intersects(bitset: *std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
    const num_masks = numMasks(bitset.unmanaged.bit_length);

    for (bitset.unmanaged.masks[0..num_masks]) |*mask, i| {
        if (mask.* & other.unmanaged.masks[i] > 0) {
            std.debug.print("\n{} & {}", .{ mask.*, other.unmanaged.masks[i] });
            return true;
        }
    }

    return false;
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

    all_mask: ?std.bit_set.DynamicBitSet,
    any_mask: ?std.bit_set.DynamicBitSet,

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
        if (self.all_mask) |*mask| {
            mask.deinit();
        }
        if (self.any_mask) |*mask| {
            mask.deinit();
        }
    }

    fn execute(self: *Self, world: *World) void {
        for (world.archetypes.all.items) |*archetype| {
            if (self.any_mask) |*mask| {
                if (intersects(mask, &archetype.mask)) {
                    _ = self.archetypes.append(archetype) catch null;
                    continue;
                }
            }
            if (self.all_mask) |*mask| {
                if (contains(mask, &archetype.mask)) {
                    _ = self.archetypes.append(archetype) catch null;
                }
            }
            // if (self.any_mask != null and intersects(&self.any_mask, &archetype.mask) or self.all_mask != null and contains(&self.all_mask, &archetype.mask)) {
            //     _ = self.archetypes.append(archetype) catch null;
            // }
        }
    }
};

pub const MAX_COMPONENTS_PER_QUERY_MATCHER = 100;

pub const QueryBuilder = struct {
    const Self = @This();

    all_mask: ?std.bit_set.DynamicBitSet = null,
    any_mask: ?std.bit_set.DynamicBitSet = null,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !QueryBuilder {
        return QueryBuilder{
            .all_mask = null,
            .any_mask = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.all_mask) |*mask| {
            mask.deinit();
        }
        if (self.any_mask) |*mask| {
            mask.deinit();
        }
    }

    pub fn any(self: *Self, data: anytype) *Self {
        const components = std.meta.fields(@TypeOf(data));

        if (self.any_mask == null) {
            self.any_mask = std.bit_set.DynamicBitSet.initEmpty(self.allocator, MAX_COMPONENTS_PER_QUERY_MATCHER) catch null;
        }

        inline for (components) |field| {
            var component = @field(data, field.name);
            self.any_mask.?.set(component.id);
        }

        return self;
    }

    pub fn all(self: *Self, data: anytype) *Self {
        const components = std.meta.fields(@TypeOf(data));

        if (self.all_mask == null) {
            self.all_mask = std.bit_set.DynamicBitSet.initEmpty(self.allocator, MAX_COMPONENTS_PER_QUERY_MATCHER) catch null;
        }

        inline for (components) |field| {
            var component = @field(data, field.name);
            self.all_mask.?.set(component.id);
        }

        return self;
    }

    pub fn from(self: *Self, world: *World) Query {
        var created_query = Query{
            .all_mask = if (self.all_mask) |mask| mask.clone(self.allocator) catch unreachable else null,
            .any_mask = if (self.any_mask) |mask| mask.clone(self.allocator) catch unreachable else null,
            .archetypes = std.ArrayList(*Archetype).init(self.allocator),
        };

        if (self.all_mask) |*mask| {
            mask.deinit();
            self.all_mask = null;
        }
        if (self.any_mask) |*mask| {
            mask.deinit();
            self.any_mask = null;
        }

        created_query.execute(world);

        return created_query;
    }
};
