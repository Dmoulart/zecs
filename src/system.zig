const std = @import("std");
const Entity = @import("entity-storage.zig").Entity;
const Context = @import("context.zig").Context;

pub fn System(comptime ContextType: type) type {
    return *const fn (ContextType) void;
}

pub fn OnEnterQuery(comptime ContextType: type) type {
    return *const fn (*ContextType, Entity) void;
}
