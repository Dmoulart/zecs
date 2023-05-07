const std = @import("std");
const assert = @import("std").debug.assert;

const Component = @import("./component.zig").Component;
const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;
const ArchetypeStorage = @import("./archetype-storage.zig").ArchetypeStorage;
const SparseSet = @import("./sparse-set.zig").SparseSet;
const QueryBuilder = @import("./query.zig").QueryBuilder;
const Query = @import("./query.zig").Query;
const Entity = @import("./entity-storage.zig").Entity;
const EntityStorage = @import("./entity-storage.zig").EntityStorage;

const DEFAULT_ARCHETYPES_STORAGE_CAPACITY = @import("./archetype-storage.zig").DEFAULT_ARCHETYPES_STORAGE_CAPACITY;
const DEFAULT_WORLD_CAPACITY = 10_000;

pub fn Prefab(comptime definition: anytype, comptime world: World) type {
    const components = std.meta.fields(@TypeOf(definition));
    return struct {
        pub fn create() Entity {
            var entity = world.createEntity();
            inline for (components) |field| {
                var component = @field(definition, field.name);
                world.toggleComponent(entity, component);
            }
            return entity;
        }
    };
    // const WorldComponents = comptime blk: {
    //     var fields: []const StructField = &[0]StructField{};
    //     const ComponentsTypesFields = std.meta.fields(@TypeOf(ComponentsTypes));
    //     var component_counter: u32 = 0;

    //     inline for (ComponentsTypesFields) |field| {
    //         component_counter += 1;
    //         var ComponentType = @field(ComponentsTypes, field.name);

    //         var component_instance = ComponentType{
    //             .id = component_counter,
    //         };

    //         fields = fields ++ [_]std.builtin.Type.StructField{.{
    //             .name = ComponentType.name[0..],
    //             .field_type = ComponentType,
    //             .is_comptime = true,
    //             .alignment = @alignOf(ComponentType),
    //             .default_value = &component_instance,
    //         }};
    //     }
    //     break :blk @Type(.{
    //         .Struct = .{
    //             .layout = .Auto,
    //             .is_tuple = false,
    //             .fields = fields,
    //             .decls = &[_]std.builtin.Type.Declaration{},
    //         },
    //     });
    // };
}

pub const World = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    archetypes: ArchetypeStorage,

    entities: EntityStorage,

    queryBuilder: QueryBuilder,

    root: *Archetype,

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
            .root = archetypes.getRoot(),
        };

        var queryBuilder = try QueryBuilder.init(options.allocator);

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
        // assert(self.contains(entity));

        var archetype = self.entities.getArchetype(entity) orelse unreachable;
        return archetype.has(component.id);
    }

    pub fn contains(self: *Self, entity: Entity) bool {
        return self.entities.contains(entity);
    }

    pub fn attach(self: *Self, entity: Entity, component: anytype) void {
        // assert(!self.has(entity, component));

        self.toggleComponent(entity, component);
    }

    pub fn detach(self: *Self, entity: Entity, component: anytype) void {
        // assert(self.has(entity, component));

        self.toggleComponent(entity, component);
    }

    pub fn query(self: *Self) *QueryBuilder {
        // Errrk ugly stuff
        self.queryBuilder.world = self;
        return &self.queryBuilder;
    }

    pub fn Prefab(self: *Self, comptime definition: anytype) Entity {
        var entity = self.createEntity();
        for (std.meta.fields(@TypeOf(definition))) |field| {
            var component = @field(definition, field.name);
            self.toggleComponent(entity, component);
        }
        return entity;
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

        old.entities.removeUnsafe(entity);
        new.entities.add(entity);
    }
};
