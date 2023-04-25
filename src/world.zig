const std = @import("std");
const assert = @import("std").debug.assert;
const Component = @import("./component.zig").Component;
const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;
const ArchetypeEdge = @import("./archetype.zig").ArchetypeEdge;
const SparseSet = @import("./sparse-set.zig").SparseSet;
const QueryBuilder = @import("./query.zig").QueryBuilder;
const Query = @import("./query.zig").Query;
const buildArchetype = @import("./archetype.zig").buildArchetype;
const deriveArchetype = @import("./archetype.zig").deriveArchetype;

var global_entity_counter: Entity = 0;

pub const Entity = u64;

const ArchetypeMap = std.AutoHashMap(ArchetypeMask, Archetype);

pub const DEFAULT_WORLD_CAPACITY = 10_000;

pub const World = struct {
    const Self = @This();
    capacity: u128,
    // entities: [DEFAULT_WORLD_CAPACITY]Entity = undefined,
    cursor: usize,
    allocator: std.mem.Allocator,
    archetypes: ArchetypeMap,
    entitiesArchetypes: std.AutoHashMap(Entity, Archetype),
    root: Archetype,
    queryBuilder: QueryBuilder,

    pub fn init(alloc: std.mem.Allocator) !Self {
        var rootArchetype = try buildArchetype(.{}, alloc);

        var entitiesArchetypes = std.AutoHashMap(Entity, Archetype).init(alloc);
        try entitiesArchetypes.ensureTotalCapacity(DEFAULT_WORLD_CAPACITY);

        var queryBuilder = try QueryBuilder.init(alloc);

        var world = Self{ .allocator = alloc, .capacity = 0, .cursor = 0, .archetypes = ArchetypeMap.init(alloc), .root = rootArchetype, .entitiesArchetypes = entitiesArchetypes, .queryBuilder = queryBuilder };
        // world.queryBuilder.world = world;
        return world;
    }

    pub fn createEntity(self: *Self) Entity {
        global_entity_counter += 1;
        var created_entity = global_entity_counter;

        self.cursor += 1;
        // self.entities[self.cursor] = created_entity;

        self.root.entities.add(created_entity);
        self.entitiesArchetypes.putAssumeCapacity(created_entity, self.root);

        return created_entity;
    }

    pub fn has(self: *Self, entity: Entity, component: anytype) bool {
        assert(self.exists(entity));

        var arch: Archetype = self.entitiesArchetypes.get(entity) orelse unreachable;
        return arch.mask.isSet(component.id);
    }

    pub fn exists(self: *Self, entity: Entity) bool {
        return self.entitiesArchetypes.contains(entity);
    }

    pub fn attach(self: *Self, entity: Entity, component: anytype) !void {
        assert(self.exists(entity));
        assert(!self.has(entity, component));

        try self.toggleComponent(entity, component);
    }

    pub fn detach(self: *Self, entity: Entity, component: anytype) !void {
        assert(self.exists(entity));
        assert(self.has(entity, component));

        try self.toggleComponent(entity, component);
    }

    pub fn entities(self: *Self) *QueryBuilder {
        return &self.queryBuilder;
    }

    fn toggleComponent(self: *Self, entity: Entity, component: anytype) !void {
        var archetype = self.entitiesArchetypes.get(entity) orelse unreachable;

        var newArchetype = if (archetype.edge.contains(component.id))
            archetype.edge.get(component.id) orelse unreachable
        else
            try deriveArchetype(&archetype, component.id, self.allocator);

        self.swapArchetypes(entity, &archetype, &newArchetype);
    }

    fn swapArchetypes(self: *Self, entity: Entity, old: *Archetype, new: *Archetype) void {
        self.entitiesArchetypes.putAssumeCapacity(entity, new.*);

        _ = old.*.entities.remove(entity);
        new.*.entities.add(entity);
    }
};
