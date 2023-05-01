const std = @import("std");
const assert = @import("std").debug.assert;
const Component = @import("./component.zig").Component;
const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;
const ArchetypeEdge = @import("./archetype.zig").ArchetypeEdge;
const ArchetypesStorage = @import("./archetypes-storage.zig").ArchetypesStorage;
const SparseSet = @import("./sparse-set.zig").SparseSet;
const QueryBuilder = @import("./query.zig").QueryBuilder;
const Query = @import("./query.zig").Query;

var global_entity_counter: Entity = 0;

pub const Entity = u64;

const ArchetypeMap = std.AutoHashMap(ArchetypeMask, Archetype);

pub const DEFAULT_WORLD_CAPACITY = 10_000;
pub const WORLD_CAPACITY_GROW_FACTOR = 10_000;

pub const World = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    archetypes: ArchetypesStorage,

    entitiesArchetypes: std.AutoHashMap(Entity, *Archetype),

    deletedEntities: std.ArrayList(Entity),

    capacity: u32 = DEFAULT_WORLD_CAPACITY,

    count: u32 = 0,

    queryBuilder: QueryBuilder,

    const WorldOptions = struct { allocator: std.mem.Allocator, capacity: ?u32 = DEFAULT_WORLD_CAPACITY };

    pub fn init(options: WorldOptions) !Self {
        var capacity = options.capacity orelse DEFAULT_WORLD_CAPACITY;

        var entitiesArchetypes = std.AutoHashMap(Entity, *Archetype).init(options.allocator);
        try entitiesArchetypes.ensureTotalCapacity(capacity);

        var archetypes = try ArchetypesStorage.init(.{ .capacity = capacity }, options.allocator);

        var queryBuilder = try QueryBuilder.init(options.allocator);

        var deletedEntities = std.ArrayList(Entity).init(options.allocator);
        try deletedEntities.ensureTotalCapacity(capacity);

        var world = Self{ .allocator = options.allocator, .capacity = capacity, .count = 0, .archetypes = archetypes, .entitiesArchetypes = entitiesArchetypes, .queryBuilder = queryBuilder, .deletedEntities = deletedEntities };

        return world;
    }

    pub fn deinit(self: *Self) void {
        self.archetypes.deinit();
        self.entitiesArchetypes.deinit();
        self.queryBuilder.deinit();
        self.deletedEntities.deinit();
    }

    pub fn resetEntityCursor() void {
        global_entity_counter = 0;
    }

    pub fn createEntity(self: *Self) Entity {
        if (self.count == self.capacity) {
            self.entitiesArchetypes.ensureTotalCapacity(self.capacity + WORLD_CAPACITY_GROW_FACTOR) catch unreachable;
            self.capacity += WORLD_CAPACITY_GROW_FACTOR;
        }

        var created_entity: Entity = undefined;

        if (self.deletedEntities.popOrNull()) |ent| {
            created_entity = ent;
        } else {
            global_entity_counter += 1;
            created_entity = global_entity_counter;
        }

        var root = self.archetypes.getRoot();

        root.entities.add(created_entity);

        self.entitiesArchetypes.putAssumeCapacity(created_entity, root);

        self.count += 1;

        return created_entity;
    }

    pub fn deleteEntity(self: *Self, entity: Entity) void {
        assert(self.exists(entity));

        var archetype = self.entitiesArchetypes.get(entity) orelse unreachable;

        archetype.entities.remove(entity);
        _ = self.entitiesArchetypes.remove(entity);

        self.deletedEntities.appendAssumeCapacity(entity);

        self.count -= 1;
    }

    pub fn has(self: *Self, entity: Entity, component: anytype) bool {
        assert(self.exists(entity));

        var arch = self.entitiesArchetypes.get(entity) orelse unreachable;

        return arch.mask.isSet(component.id);
    }

    pub fn exists(self: *Self, entity: Entity) bool {
        return self.entitiesArchetypes.contains(entity);
    }

    pub fn attach(self: *Self, entity: Entity, component: anytype) void {
        assert(!self.has(entity, component));

        self.toggleComponent(entity, component);
    }

    pub fn detach(self: *Self, entity: Entity, component: anytype) void {
        assert(self.has(entity, component));

        self.toggleComponent(entity, component);
    }

    pub fn entities(self: *Self) *QueryBuilder {
        // oh man thats craap
        self.queryBuilder.world = self;
        return &self.queryBuilder;
    }

    fn toggleComponent(self: *Self, entity: Entity, component: anytype) void {
        var archetype: *Archetype = self.entitiesArchetypes.get(entity) orelse unreachable;

        if (archetype.edge.get(component.id)) |edge| {
            self.swapArchetypes(entity, archetype, edge);
        } else {
            var new_archetype = self.archetypes.derive(archetype, component.id);

            self.swapArchetypes(entity, archetype, new_archetype);
        }
    }

    fn swapArchetypes(self: *Self, entity: Entity, old: *Archetype, new: *Archetype) void {
        self.entitiesArchetypes.putAssumeCapacity(entity, new);

        old.entities.remove(entity);

        new.entities.add(entity);
    }
};
