const std = @import("std");
const Component = @import("./component.zig").Component;

const HASH_BASE: u128 = 133562;
const HASH_ENTROPY: u128 = 423052;

pub fn hash(ids: []u64) u128 {
    var hash_value: u128 = HASH_BASE;
    for (ids) |id| {
        hash_value = (hash_value ^ id) * HASH_ENTROPY;
    }
    return hash_value;
}

// pub const Type = struct {
//     components: *Component(type),
// };

const Archetype = struct {
    components: []type,
};

pub fn Type(comps: anytype) type {
    var components: []type = undefined;
    _ = components;
    for (std.meta.fields(@TypeOf(comps))) |field| {
        var comp = @field(comps, field.name);
        _ = comp;
    }
}
