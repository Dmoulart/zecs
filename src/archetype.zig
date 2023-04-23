const std = @import("std");
const Component = @import("./component.zig").Component;
const SparseSet = @import("./sparse-set.zig").SparseSet;
const Entity = @import("./world.zig").Entity;

pub const ArchetypeMask = u128;

const HASH_BASE: ArchetypeMask = 133562;
const HASH_ENTROPY: ArchetypeMask = 423052;

pub const Archetype = struct { mask: ArchetypeMask, entities: SparseSet(Entity) };

pub fn hash(ids: []u64) ArchetypeMask {
    var hash_value: ArchetypeMask = HASH_BASE;
    for (ids) |id| {
        hash_value = (hash_value ^ id) * HASH_ENTROPY;
    }
    return hash_value;
}

pub fn hashComponentsIds(comptime comps: anytype) ArchetypeMask {
    const fields = std.meta.fields(@TypeOf(comps));
    var ids: [100]u64 = undefined;

    inline for (fields) |field, i| {
        var comp = @field(comps, field.name);
        ids[i] = comp.id;
    }

    return hash(ids[0..fields.len]);
}

pub fn archetype(comptime comps: anytype) Archetype {
    return Archetype{ .mask = hashComponentsIds(comps), .entities = SparseSet(Entity){} };
}
