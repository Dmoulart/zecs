const std = @import("std");
const assert = @import("std").debug.assert;

const Component = @import("./component.zig").Component;
const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;
const ArchetypeEdge = @import("./archetype.zig").ArchetypeEdge;
const ArchetypeStorage = @import("./archetype-storage.zig").ArchetypeStorage;
const SparseSet = @import("./sparse-set.zig").SparseSet;
const QueryBuilder = @import("./query.zig").QueryBuilder;
const Query = @import("./query.zig").Query;
const Entity = @import("./entity-storage.zig").Entity;
const EntityStorage = @import("./entity-storage.zig").EntityStorage;

const DEFAULT_ARCHETYPES_STORAGE_CAPACITY = @import("./archetype-storage.zig").DEFAULT_ARCHETYPES_STORAGE_CAPACITY;
const DEFAULT_WORLD_CAPACITY = 10_000;

pub const World = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    archetypes: ArchetypeStorage,

    entities: EntityStorage,

    queryBuilder: QueryBuilder,

    const WorldOptions = struct {
        allocator: std.mem.Allocator,
        capacity: ?u32 = DEFAULT_WORLD_CAPACITY,
        archetypes_capacity: ?u32 = DEFAULT_ARCHETYPES_STORAGE_CAPACITY,
    };

    pub fn init(options: WorldOptions) !Self {
        var capacity = options.capacity orelse DEFAULT_WORLD_CAPACITY;
        var archetypes_storage_capacity = options.archetypes_capacity;

        var archetypes = try ArchetypeStorage.init(.{
            .capacity = archetypes_storage_capacity,
            .archetype_capacity = capacity,
        }, options.allocator);

        var entities = try EntityStorage.init(.{
            .allocator = options.allocator,
            .capacity = capacity,
        });

        var world = Self{
            .allocator = options.allocator,
            .archetypes = archetypes,
            .entities = entities,
            .queryBuilder = undefined,
        };

        var queryBuilder = try QueryBuilder.init(options.allocator, &world);

        world.queryBuilder = queryBuilder;

        return world;
    }

    pub fn deinit(self: *Self) void {
        self.archetypes.deinit();
        self.entities.deinit();
        self.queryBuilder.deinit();
    }

    pub fn createEntity(self: *Self) Entity {
        return self.entities.create(self.archetypes.getRoot());
    }

    pub fn deleteEntity(self: *Self, entity: Entity) void {
        self.entities.delete(entity);
    }

    pub fn has(self: *Self, entity: Entity, component: anytype) bool {
        assert(self.contains(entity));

        var archetype = self.entities.getArchetype(entity) orelse unreachable;
        return archetype.has(component.id);
    }

    pub fn contains(self: *Self, entity: Entity) bool {
        return self.entities.contains(entity);
    }

    pub fn attach(self: *Self, entity: Entity, component: anytype) void {
        assert(!self.has(entity, component));

        self.toggleComponent(entity, component);
    }

    pub fn detach(self: *Self, entity: Entity, component: anytype) void {
        assert(self.has(entity, component));

        self.toggleComponent(entity, component);
    }

    pub fn query(self: *Self) *QueryBuilder {
        // oh man thats craap
        self.queryBuilder.world = self;
        return &self.queryBuilder;
    }

    fn toggleComponent(self: *Self, entity: Entity, component: anytype) void {
        var archetype: *Archetype = self.entities.getArchetype(entity) orelse unreachable;

        if (archetype.edge.get(component.id)) |edge| {
            self.swapArchetypes(entity, archetype, edge);
        } else {
            var new_archetype = self.archetypes.derive(archetype, component.id);
            self.swapArchetypes(entity, archetype, new_archetype);
        }
    }

    fn swapArchetypes(self: *Self, entity: Entity, old: *Archetype, new: *Archetype) void {
        self.entities.setArchetype(entity, new);

        old.entities.remove(entity);
        new.entities.add(entity);
    }
};
