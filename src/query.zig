const std = @import("std");
const print = @import("std").debug.print;
const Archetype = @import("./archetype.zig").Archetype;
const World = @import("./world.zig").World;
const Entity = @import("./entity-storage.zig").Entity;
const RawBitset = @import("./raw-bitset.zig").RawBitset;

pub const MAX_COMPONENTS_PER_QUERY_MATCHER = 100;

pub const QueryMatcherType = enum { any, all, not, none };

pub const Query = struct {
    const Self = @This();

    archetypes: std.ArrayList(*Archetype),

    matchers: std.ArrayList(QueryMatcher),

    allocator: std.mem.Allocator,

    pub fn init(matchers: std.ArrayList(QueryMatcher), allocator: std.mem.Allocator) Query {
        return Query{
            .allocator = allocator,
            .matchers = matchers,
            .archetypes = std.ArrayList(*Archetype).init(allocator),
        };
    }

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
        self.matchers.deinit();
    }

    fn execute(self: *Self, world: anytype) void {
        archetypes_loop: for (world.archetypes.all.items) |*archetype| {
            for (self.matchers.items) |*matcher| {
                const mask = &matcher.mask;

                if (!matcher.match(mask, &archetype.mask))
                    continue :archetypes_loop;
            }

            _ = self.archetypes.append(archetype) catch null;
        }
    }

    pub fn has(self: *Self, entity: Entity) bool {
        for (self.archetypes.items) |arch| {
            if (arch.entities.has(entity)) return true;
        }
        return false;
    }
};

pub const QueryMatcher = struct {
    const Self = @This();
    op_type: QueryMatcherType,
    mask: RawBitset,

    pub fn deinit(self: *Self) void {
        self.mask.deinit();
    }
    pub fn match(self: *Self, bitset: *RawBitset, other: *RawBitset) bool {
        return switch (self.op_type) {
            .any => bitset.intersects(other),
            .all => other.contains(bitset),
            .not => !bitset.intersects(other),
            .none => !other.contains(bitset),
        };
    }
};
pub fn QueryBuilder(comptime WorldComponents: anytype) type {
    _ = WorldComponents;
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        matchers: std.ArrayList(QueryMatcher),

        pub fn init(allocator: std.mem.Allocator) !Self {
            return Self{
                .allocator = allocator,
                .matchers = std.ArrayList(QueryMatcher).init(allocator),
            };
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

            var mask = RawBitset.init(.{});

            inline for (components) |field| {
                const component = @field(data, field.name);
                mask.set(component.id);
            }

            self.matchers.append(QueryMatcher{
                .op_type = matcher_type,
                .mask = mask,
            }) catch unreachable;
        }

        pub fn from(self: *Self, world: anytype) Query {
            var created_query = Query.init(
                self.matchers.clone() catch unreachable,
                self.allocator,
            );

            self.matchers.clearAndFree();

            created_query.execute(world);

            return created_query;
        }
    };
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

// fn numMasks(bit_length: usize) usize {
//     return (bit_length + (@bitSizeOf(std.bit_set.DynamicBitSet.MaskInt) - 1)) / @bitSizeOf(std.bit_set.DynamicBitSet.MaskInt);
// }

// fn contains(bitset: *const std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
//     const len = @min(numMasks(bitset.unmanaged.bit_length), numMasks(other.unmanaged.bit_length));

//     for (bitset.unmanaged.masks[0..len], 0..) |*mask, i| {
//         if (mask.* & other.unmanaged.masks[i] != mask.*) {
//             return false;
//         }
//     }

//     return true;
// }

// fn intersects(bitset: *const std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
//     const len = @min(numMasks(bitset.unmanaged.bit_length), numMasks(other.unmanaged.bit_length));

//     for (bitset.unmanaged.masks[0..len], 0..) |*mask, i| {
//         if (mask.* & other.unmanaged.masks[i] > 0) {
//             return true;
//         }
//     }

//     return false;
// }
