const std = @import("std");
const Component = @import("./component.zig").Component;
const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;
const createArchetype = @import("./archetype.zig").createArchetype;

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
    entitiesArchetypes: std.AutoHashMap(Entity, Archetype),
    root: Archetype,

    pub fn createEntity(self: *Self) Entity {
        global_entity_counter += 1;
        var created_entity = global_entity_counter;

        self.cursor += 1;
        self.entities[self.cursor] = created_entity;

        self.root.entities.add(created_entity);
        self.entitiesArchetypes.putAssumeCapacity(created_entity, self.root);

        return created_entity;
    }

    pub fn attach(self: *Self, entity: Entity, component: anytype) void {
        var archetype = self.entitiesArchetypes.get(entity);
        if (archetype == null) return;
        // archetype

        _ = component;
    }

    pub fn init(alloc: std.mem.Allocator) !Self {
        var rootArchetype = createArchetype(.{});

        var entitiesArchetypes = std.AutoHashMap(Entity, Archetype).init(alloc);
        try entitiesArchetypes.ensureTotalCapacity(DEFAULT_WORLD_CAPACITY);

        var world = Self{ .allocator = alloc, .entities = undefined, .capacity = 0, .cursor = 0, .archetypes = ArchetypeMap.init(alloc), .root = rootArchetype, .entitiesArchetypes = entitiesArchetypes };
        try world.archetypes.put(rootArchetype.mask, rootArchetype);

        return world;
    }
};
