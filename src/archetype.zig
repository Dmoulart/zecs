const std = @import("std");
const Component = @import("./component.zig").Component;
const ComponentId = @import("./component.zig").ComponentId;
const SparseSet = @import("./sparse-set.zig").SparseSet;
const SparseMap = @import("./sparse-map.zig").SparseMap;
const SparseArray = @import("./sparse-array.zig").SparseArray;
const RawBitset = @import("./raw-bitset.zig").RawBitset;
const Entity = @import("./entity-storage.zig").Entity;

const DEFAULT_WORLD_CAPACITY = @import("./world.zig").DEFAULT_WORLD_CAPACITY;

pub const ArchetypeMask = RawBitset;

const ARCHETYPE_EDGE_CAPACITY: u32 = 10_000;

const ARCHETYPE_BITSET_CAPACITY: u32 = 50;

pub const Archetype = struct {
    const Self = @This();

    mask: ArchetypeMask,

    entities: SparseSet(Entity),

    edge: SparseArray(ComponentId, *Archetype),

    capacity: u32,

    pub fn deinit(self: *Self) void {
        self.mask.deinit();
        self.edge.deinit();
        self.entities.deinit();
    }

    pub fn build(comps: anytype, allocator: std.mem.Allocator, capacity: u32) Archetype {
        var mask = generateComponentsMask(comps, allocator);

        return Archetype{
            .mask = mask,
            .entities = SparseSet(Entity).init(.{
                .allocator = allocator,
                .capacity = capacity,
            }),
            .edge = SparseArray(ComponentId, *Archetype).init(.{
                .allocator = allocator,
                .capacity = capacity,
            }),
            .capacity = capacity,
        };
    }

    pub fn derive(self: *Self, id: ComponentId, allocator: std.mem.Allocator, capacity: u32) Archetype {
        var mask: ArchetypeMask = self.mask.clone();

        if (mask.has(id)) {
            mask.unset(id);
        } else {
            mask.set(id);
        }

        return Archetype{
            .mask = mask,
            .entities = SparseSet(Entity).init(.{
                .allocator = allocator,
                .capacity = capacity,
            }),
            .edge = SparseArray(ComponentId, *Archetype).init(.{
                .allocator = allocator,
                .capacity = capacity,
            }),
            .capacity = capacity,
        };
    }

    pub fn has(self: *Self, id: ComponentId) bool {
        return self.mask.has(id);
    }
};

fn generateComponentsMask(comps: anytype, alloc: std.mem.Allocator) RawBitset {
    _ = alloc;
    const fields = std.meta.fields(@TypeOf(comps));

    var mask: RawBitset = RawBitset.init(.{});

    inline for (fields) |field| {
        var comp = @field(comps, field.name);
        mask.set(@as(usize, comp.id));
    }

    return mask;
}

// const HASH_BASE: ArchetypeMask = 133562;
// const HASH_ENTROPY: ArchetypeMask = 423052;

// pub fn hash(ids: []u64) ArchetypeMask {
//     var hash_value: ArchetypeMask = HASH_BASE;
//     for (ids) |id| {
//         hash_value = (hash_value ^ id) * HASH_ENTROPY;
//     }
//     return hash_value;
// }

// pub fn hashComponentsIds(comps: anytype) ArchetypeMask {
//     const fields = std.meta.fields(@TypeOf(comps));
//     var ids: [100]u64 = undefined;

//     inline for (fields) |field, i| {
//         var comp = @field(comps, field.name);
//         ids[i] = comp.id;
//     }

//     return hash(ids[0..fields.len]);
// }
