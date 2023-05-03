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

    all_mask: ?std.bit_set.DynamicBitSet,
    any_mask: ?std.bit_set.DynamicBitSet,
    not_mask: ?std.bit_set.DynamicBitSet,
    none_mask: ?std.bit_set.DynamicBitSet,

    archetypes: std.ArrayList(*Archetype),

    // operations: [2]?QueryOperation = .{ null, null },

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
        if (self.not_mask) |*mask| {
            mask.deinit();
        }
        if (self.none_mask) |*mask| {
            mask.deinit();
        }
    }

    // fn execute2(self: *Self, world: *World) void {
    //     archloop: for (world.archetypes.all.items) |*archetype| {
    //         for (self.operations) |operation| {
    //             if (operation) |*op| {
    //                 if (op.match(archetype)) {
    //                     _ = self.archetypes.append(archetype) catch null;
    //                     continue :archloop;
    //                 }
    //             }
    //         }
    //     }
    // }

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
                    continue;
                }
            }
            if (self.not_mask) |*mask| {
                if (!intersects(mask, &archetype.mask)) {
                    _ = self.archetypes.append(archetype) catch null;
                    continue;
                }
            }
            if (self.none_mask) |*mask| {
                std.debug.print("\nnone", .{});
                if (!contains(mask, &archetype.mask)) {
                    _ = self.archetypes.append(archetype) catch null;
                    continue;
                }
            }
        }
    }
};

pub const MAX_COMPONENTS_PER_QUERY_MATCHER = 100;

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

pub const QueryBuilder = struct {
    const Self = @This();

    all_mask: ?std.bit_set.DynamicBitSet = null,
    any_mask: ?std.bit_set.DynamicBitSet = null,
    not_mask: ?std.bit_set.DynamicBitSet = null,
    none_mask: ?std.bit_set.DynamicBitSet = null,

    // operations: [2]?QueryOperation = .{ null, null },

    // prepared_query: Query,

    allocator: std.mem.Allocator,
    // query(.{.all= {Position, Velocity}, .any={}})
    pub fn init(allocator: std.mem.Allocator) !QueryBuilder {
        // var operations = try allocator.alloc(QueryOperation, @typeInfo(QueryOperationTag).Enum.fields.len);
        // errdefer allocator.free(operations);

        return QueryBuilder{
            .all_mask = null,
            .any_mask = null,
            .not_mask = null,
            .none_mask = null,
            .allocator = allocator,
            // .operations = undefined,
            // .prepared_query = Query{
            //     .all_mask = null,
            //     .any_mask = null,
            //     // .operations = [2]?QueryOperation{ null, null },
            //     .archetypes = std.ArrayList(*Archetype).init(allocator),
            // },
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.all_mask) |*mask| {
            mask.deinit();
        }
        if (self.any_mask) |*mask| {
            mask.deinit();
        }
        if (self.not_mask) |*mask| {
            mask.deinit();
        }
        if (self.none_mask) |*mask| {
            mask.deinit();
        }
        // self.allocator.free(self.operations);
    }

    // pub fn any2(self: *Self, data: anytype) *Self {
    //     const components = std.meta.fields(@TypeOf(data));

    //     var op_index = @enumToInt(QueryOperationTag.any);

    //     if (self.prepared_query.operations[op_index] == null) |_| {
    //         self.prepared_query.operations[op_index] = QueryOperation{
    //             .any = std.bit_set.DynamicBitSet.initEmpty(self.allocator, MAX_COMPONENTS_PER_QUERY_MATCHER) catch unreachable,
    //         };
    //     }

    //     var op = if (self.prepared_query.operations[op_index]) |*op| op else unreachable;

    //     inline for (components) |field| {
    //         var component = @field(data, field.name);
    //         op.any.set(component.id);
    //     }

    //     return self;
    // }

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

    pub fn not(self: *Self, data: anytype) *Self {
        const components = std.meta.fields(@TypeOf(data));

        if (self.not_mask == null) {
            self.not_mask = std.bit_set.DynamicBitSet.initEmpty(self.allocator, MAX_COMPONENTS_PER_QUERY_MATCHER) catch null;
        }

        inline for (components) |field| {
            var component = @field(data, field.name);
            self.not_mask.?.set(component.id);
        }

        return self;
    }

    pub fn none(self: *Self, data: anytype) *Self {
        const components = std.meta.fields(@TypeOf(data));

        if (self.none_mask == null) {
            self.none_mask = std.bit_set.DynamicBitSet.initEmpty(self.allocator, MAX_COMPONENTS_PER_QUERY_MATCHER) catch null;
        }

        inline for (components) |field| {
            var component = @field(data, field.name);
            self.none_mask.?.set(component.id);
        }

        return self;
    }

    // pub fn from2(self: *Self, world: *World) Query {
    //     var query_any_op = if (self.operations[0]) |*op| QueryOperation{
    //         .any = op.any.clone(self.allocator) catch std.bit_set.DynamicBitSet,
    //     } else null;

    //     var query_all_op = if (self.operations[1]) |*op| QueryOperation{
    //         .all = op.all.clone(self.allocator) catch null,
    //     } else null;

    //     var created_query = Query{
    //         .all_mask = if (self.all_mask) |mask| mask.clone(self.allocator) catch unreachable else null,
    //         .any_mask = if (self.any_mask) |mask| mask.clone(self.allocator) catch unreachable else null,
    //         .archetypes = std.ArrayList(*Archetype).init(self.allocator),
    //         .operations = [2]?QueryOperation{
    //             query_any_op,
    //             query_all_op,
    //         },
    //     };
    //     _ = created_query;

    //     // if (self.all_mask) |*mask| {
    //     //     mask.deinit();
    //     //     self.all_mask = null;
    //     // }
    //     // if (self.any_mask) |*mask| {
    //     //     mask.deinit();
    //     //     self.any_mask = null;
    //     // }

    //     self.prepared_query.execute2(world);

    //     return self.prepared_query;
    // }

    pub fn from(self: *Self, world: *World) Query {
        var created_query = Query{
            .all_mask = if (self.all_mask) |mask| mask.clone(self.allocator) catch unreachable else null,
            .any_mask = if (self.any_mask) |mask| mask.clone(self.allocator) catch unreachable else null,
            .not_mask = if (self.not_mask) |mask| mask.clone(self.allocator) catch unreachable else null,
            .none_mask = if (self.none_mask) |mask| mask.clone(self.allocator) catch unreachable else null,
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
        if (self.not_mask) |*mask| {
            mask.deinit();
            self.not_mask = null;
        }
        if (self.none_mask) |*mask| {
            mask.deinit();
            self.none_mask = null;
        }

        created_query.execute(world);

        return created_query;
    }
};
