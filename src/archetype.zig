const std = @import("std");
const Component = @import("./component.zig").Component;
const ComponentId = @import("./component.zig").ComponentId;
const SparseSet = @import("./sparse-set.zig").SparseSet;
const Entity = @import("./world.zig").Entity;
const DEFAULT_WORLD_CAPACITY = @import("./world.zig").DEFAULT_WORLD_CAPACITY;

pub const ArchetypeMask = u128;
pub const ArchetypeMask2 = std.bit_set.DynamicBitSet;

const HASH_BASE: ArchetypeMask = 133562;
const HASH_ENTROPY: ArchetypeMask = 423052;

pub const ArchetypeEdge = std.AutoArrayHashMap(ComponentId, *Archetype);

pub const Archetype = struct {
    const Self = @This();

    mask: ArchetypeMask2,
    entities: SparseSet(Entity),
    edge: ArchetypeEdge,

    pub fn deinit(self: *Self) void {
        self.mask.deinit();
        self.edge.deinit();
        self.entities.deinit();
    }
};

pub fn buildArchetype(comps: anytype, alloc: std.mem.Allocator) !Archetype {
    var mask = try generateComponentsMask(comps, alloc);
    // var edge = ArchetypeEdge.init(alloc);
    // _ = edge;
    // try edge.ensureTotalCapacity(DEFAULT_WORLD_CAPACITY);

    return Archetype{ .mask = mask, .entities = SparseSet(Entity).init(alloc), .edge = ArchetypeEdge.init(alloc) };
}

pub fn deriveArchetype(archetype: *Archetype, id: ComponentId, allocator: std.mem.Allocator) Archetype {
    _ = id;
    var mask: ArchetypeMask2 = archetype.mask.clone(allocator) catch null orelse unreachable;

    var newArchetype = Archetype{
        .mask = mask,
        .entities = SparseSet(Entity).init(allocator),
        .edge = ArchetypeEdge.init(allocator),
    };

    // try newArchetype.edge.ensureTotalCapacity(DEFAULT_WORLD_CAPACITY);
    // try archetype.edge.ensureTotalCapacity(DEFAULT_WORLD_CAPACITY);

    // _ = archetype.edge.put(id, &newArchetype) catch null;
    // _ = newArchetype.edge.put(id, archetype) catch null;

    return newArchetype;
}

pub fn generateComponentsMask(comps: anytype, alloc: std.mem.Allocator) !std.bit_set.DynamicBitSet {
    const fields = std.meta.fields(@TypeOf(comps));

    var mask: std.bit_set.DynamicBitSet = try std.bit_set.DynamicBitSet.initEmpty(alloc, 500);

    inline for (fields) |field| {
        var comp = @field(comps, field.name);
        mask.set(@as(usize, comp.id));
    }

    return mask;
}

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
