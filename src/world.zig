const std = @import("std");
const Component = @import("./component.zig").Component;
const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;

var global_entity_counter: Entity = 0;

pub const Entity = u64;

const ArchetypeMap = std.AutoHashMap(ArchetypeMask, Archetype);

pub const DEFAULT_WORLD_CAPACITY = 10_000;

pub const World = struct {
    const Self = @This();
    capacity: u128,
    entities: [DEFAULT_WORLD_CAPACITY]Entity = undefined,
    cursor: usize,
    allocator: std.mem.Allocator,
    archetypes: ArchetypeMap,

    pub fn createEntity(self: *Self) Entity {
        global_entity_counter += 1;
        var created_entity = global_entity_counter;

        self.cursor += 1;
        self.entities[self.cursor] = created_entity;

        return created_entity;
    }

    pub fn attach(self: *Self, entity: Entity, comptime component: anytype) void {
        _ = component;
        _ = entity;
        _ = self;
    }

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{ .allocator = alloc, .entities = undefined, .capacity = 0, .cursor = 0, .archetypes = ArchetypeMap.init(alloc) };
    }
};
