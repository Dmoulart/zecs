const std = @import("std");
const print = @import("std").debug.print;
const Archetype = @import("./archetype.zig").Archetype;
const World = @import("./world.zig").World;
const Entity = @import("./entity-storage.zig").Entity;

fn numMasks(bit_length: usize) usize {
    return (bit_length + (@bitSizeOf(std.bit_set.DynamicBitSet.MaskInt) - 1)) / @bitSizeOf(std.bit_set.DynamicBitSet.MaskInt);
}
fn contains(bitset: *const std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
    const len = @min(numMasks(bitset.unmanaged.bit_length), numMasks(other.unmanaged.bit_length));

    for (bitset.unmanaged.masks[0..len]) |*mask, i| {
        if (mask.* & other.unmanaged.masks[i] != mask.*) {
            return false;
        }
    }

    return true;
}
fn intersects(bitset: *const std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
    const len = @min(numMasks(bitset.unmanaged.bit_length), numMasks(other.unmanaged.bit_length));

    for (bitset.unmanaged.masks[0..len]) |*mask, i| {
        if (mask.* & other.unmanaged.masks[i] > 0) {
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

    archetypes: std.ArrayList(*Archetype),

    matchers: std.ArrayList(QueryMatcher),

    allocator: std.mem.Allocator,

    pub fn init(matchers: std.ArrayList(QueryMatcher), allocator: std.mem.Allocator) Query {
        // var operations_buffer: [10]QueryMatcher = undefined;
        // _ = operations_buffer;
        var query = Query{
            .allocator = allocator,
            .matchers = matchers,
            .archetypes = std.ArrayList(*Archetype).init(allocator),
        };

        return query;
    }

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
        for (self.matchers.items) |*matcher| {
            matcher.deinit();
        }
    }

    fn execute(self: *Self, world: *World) void {
        for (world.archetypes.all.items) |*archetype| {
            for (self.matchers.items) |*matcher| {
                const mask = &matcher.mask;

                if (matcher.match(mask, &archetype.mask)) {
                    _ = self.archetypes.append(archetype) catch null;
                    continue;
                }
            }
        }
    }

    pub fn has(self: *Self, entity: Entity) bool {
        for (self.archetypes.items) |arch| {
            if (arch.entities.has(entity)) return true;
        }
        return false;
    }
};

pub const MAX_COMPONENTS_PER_QUERY_MATCHER = 100;

pub const QueryMatcherType = enum { any, all, not, none };

pub const QueryMatcher = struct {
    const Self = @This();
    op_type: QueryMatcherType,
    mask: std.bit_set.DynamicBitSet,

    pub fn deinit(self: *Self) void {
        self.mask.deinit();
    }
    pub fn match(self: *Self, bitset: *const std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
        return switch (self.op_type) {
            .any => intersects(bitset, other),
            .all => contains(bitset, other),
            .not => !intersects(bitset, other),
            .none => !contains(bitset, other),
        };
    }
};

// pub fn QueryOperation(config: type) type {
//     _ = config;
//     return struct {
//         const Self = @This();
//     };
// }

// pub const QueryOperationTag = enum { any, all };

// pub const QueryOperation = union(QueryOperationTag) {
//     const Self = @This();
//     any: std.bit_set.DynamicBitSet,
//     all: std.bit_set.DynamicBitSet,

//     pub fn match(self: Self, archetype: *Archetype) bool {
//         return switch (self) {
//             .any => |*mask| intersects(mask, &archetype.mask),
//             .all => |*mask| contains(mask, &archetype.mask),
//         };
//     }

//     pub fn clone(self: Self, allocator: std.mem.Allocator) Self {
//         return switch (self) {
//             .any => |*mask| QueryOperation{ .any = mask.clone(allocator) catch unreachable },
//             .all => |*mask| QueryOperation{ .all = mask.clone(allocator) catch unreachable },
//         };
//     }
// };

const QUERY_MATCHERS_LIST_CAPACITY = 20;
pub const QueryBuilder = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    matchers: std.ArrayList(QueryMatcher),

    pub fn init(allocator: std.mem.Allocator) !QueryBuilder {
        var matchers = std.ArrayList(QueryMatcher).init(allocator);
        matchers.ensureTotalCapacity(QUERY_MATCHERS_LIST_CAPACITY) catch unreachable;
        return QueryBuilder{ .allocator = allocator, .matchers = matchers };
    }

    pub fn deinit(self: *Self) void {
        self.matchers.deinit();
    }

    pub fn any(self: *Self, data: anytype) *Self {
        self.createMatcher(data, .any);
        return self;
    }

    pub fn all(self: *Self, data: anytype) *Self {
        self.createMatcher(data, .all);
        return self;
    }
    //
    // Select the archetypes which does not posess at least one of the components.
    //
    pub fn not(self: *Self, data: anytype) *Self {
        self.createMatcher(data, .not);
        return self;
    }
    //
    // Select the archetypes which does not posess the entire set of component.
    //
    pub fn none(self: *Self, data: anytype) *Self {
        self.createMatcher(data, .none);
        return self;
    }

    fn createMatcher(self: *Self, data: anytype, matcher_type: QueryMatcherType) void {
        const components = std.meta.fields(@TypeOf(data));

        var mask = std.bit_set.DynamicBitSet.initEmpty(self.allocator, MAX_COMPONENTS_PER_QUERY_MATCHER) catch unreachable;

        inline for (components) |field| {
            var component = @field(data, field.name);
            mask.set(component.id);
        }

        self.matchers.appendAssumeCapacity(QueryMatcher{ .op_type = matcher_type, .mask = mask });
    }

    pub fn from(self: *Self, world: *World) Query {
        var created_query = Query.init(self.matchers.clone() catch unreachable, self.allocator);

        self.matchers.clearAndFree();

        self.matchers.ensureTotalCapacity(QUERY_MATCHERS_LIST_CAPACITY) catch unreachable;

        created_query.execute(world);

        return created_query;
    }
};
