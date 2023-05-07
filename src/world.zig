const std = @import("std");
const assert = @import("std").debug.assert;
const expect = @import("std").testing.expect;

const Component = @import("./component.zig").Component;
const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;
const ArchetypeStorage = @import("./archetype-storage.zig").ArchetypeStorage;
const SparseSet = @import("./sparse-set.zig").SparseSet;
// const QueryBuilder = @import("./query.zig").QueryBuilder;
// const Query = @import("./query.zig").Query;
const Entity = @import("./entity-storage.zig").Entity;
const EntityStorage = @import("./entity-storage.zig").EntityStorage;

const DEFAULT_ARCHETYPES_STORAGE_CAPACITY = @import("./archetype-storage.zig").DEFAULT_ARCHETYPES_STORAGE_CAPACITY;
const DEFAULT_WORLD_CAPACITY = 10_000;

// pub fn Prefab(comptime definition: anytype, comptime world: anytype) type {
//     const components = std.meta.fields(@TypeOf(definition));
//     return (struct {
//         pub fn create() Entity {
//             var entity = world.createEntity();
//             inline for (components) |field| {
//                 var component = @field(definition, field.name);
//                 world.toggleComponent(entity, component);
//             }
//             return entity;
//         }
//     }).create;
// }

pub fn World(comptime ComponentsTypes: anytype) type {
    const WorldComponents = comptime blk: {
        var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
        const ComponentsTypesFields = std.meta.fields(@TypeOf(ComponentsTypes));
        var component_counter: u32 = 0;

        inline for (ComponentsTypesFields) |field| {
            component_counter += 1;
            var ComponentType = @field(ComponentsTypes, field.name);

            var component_instance = ComponentType{
                .id = component_counter,
            };

            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = ComponentType.name[0..],
                .field_type = ComponentType,
                .is_comptime = true,
                .alignment = @alignOf(ComponentType),
                .default_value = &component_instance,
            }};
        }
        break :blk @Type(.{
            .Struct = .{
                .layout = .Auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &[_]std.builtin.Type.Declaration{},
            },
        });
    };

    return struct {
        const Self = @This();

        const components: WorldComponents = WorldComponents{};

        allocator: std.mem.Allocator,

        archetypes: ArchetypeStorage,

        entities: EntityStorage,

        // queryBuilder: QueryBuilder(Self),

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
                // .queryBuilder = undefined,
                .root = archetypes.getRoot(),
            };

            // var queryBuilder = try QueryBuilder(World(ComponentsTypes)).init(options.allocator);

            // world.queryBuilder = queryBuilder;

            return world;
        }

        pub fn deinit(self: *Self) void {
            self.archetypes.deinit();
            self.entities.deinit();
            // self.queryBuilder.deinit();
        }

        pub fn createEntity(self: *Self) Entity {
            return self.entities.create(self.archetypes.getRoot());
        }

        pub fn create(self: *Self, entity_type: anytype) Entity {
            if (!entity_type.ready) {
                entity_type.precalcArchetype(self);
            }
            return self.entities.create(entity_type.type_archetype orelse unreachable);
        }

        pub fn deleteEntity(self: *Self, entity: Entity) void {
            self.entities.delete(entity);
        }

        pub fn has(self: *Self, entity: Entity, comptime component: anytype) bool {
            var archetype = self.entities.getArchetype(entity) orelse unreachable;
            return archetype.has(comptime Self.getRegisteredComponent(component).id);
        }

        pub fn contains(self: *Self, entity: Entity) bool {
            return self.entities.contains(entity);
        }

        pub fn attach(self: *Self, entity: Entity, comptime component: anytype) void {
            // assert(!self.has(entity, component));

            self.toggleComponent(entity, comptime Self.getRegisteredComponent(component));
        }

        pub fn detach(self: *Self, entity: Entity, comptime component: anytype) void {
            // assert(self.has(entity, component));

            self.toggleComponent(entity, comptime Self.getRegisteredComponent(component));
        }

        // pub fn query(self: *Self) *QueryBuilder {
        //     // Errrk ugly stuff
        //     self.queryBuilder.world = self;
        //     return &self.queryBuilder;
        // }

        fn getRegisteredComponent(comptime component: anytype) @TypeOf(@field(components, component.name)) {
            return comptime @field(components, component.name);
        }

        pub fn Type(comptime definition: anytype) type {
            const definition_fields = comptime std.meta.fields(@TypeOf(definition));

            return struct {
                type_archetype: ?*Archetype = null,

                ready: bool = false,

                fn precalcArchetype(self: *@This(), world: *Self) void {
                    var archetype = world.archetypes.getRoot();

                    inline for (definition_fields) |*field| {
                        const ComponentType = @field(definition, field.name);
                        const component = @field(components, ComponentType.name);

                        if (archetype.edge.get(component.id)) |derived| {
                            archetype = derived;
                        } else {
                            archetype = world.archetypes.derive(archetype, component.id);
                        }
                    }

                    self.type_archetype = archetype;
                    self.ready = true;
                }

                fn create(self: *@This(), world: *Self) Entity {
                    if (!self.ready) self.precalcArchetype(world);

                    const entity = world.entities.create(self.type_archetype orelse unreachable);

                    return entity;
                }
            };
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
}

test "Create World type with comptime components" {
    const Game = World(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    });

    try expect(Game.components.Position.id == 1);
    try expect(Game.components.Velocity.id == 2);
}

test "Create attach and detach components" {
    const Position = Component("Position", struct {
        x: f32,
        y: f32,
    });
    const Velocity = Component("Velocity", struct {
        x: f32,
        y: f32,
    });
    const Rotation = Component("Rotation", struct {
        degrees: i8,
    });

    const Game = World(.{
        Position,
        Velocity,
        Rotation,
    });

    var game = try Game.init(.{ .allocator = std.testing.allocator, .capacity = 10 });
    defer game.deinit();

    var ent = game.createEntity();

    game.attach(ent, Position);
    try expect(game.has(ent, Position));
    try expect(!game.has(ent, Rotation));

    game.attach(ent, Rotation);
    try expect(game.has(ent, Rotation));

    game.detach(ent, Position);
    try expect(!game.has(ent, Position));
    try expect(game.has(ent, Rotation));

    game.detach(ent, Rotation);
    try expect(!game.has(ent, Position));
    try expect(!game.has(ent, Rotation));
}

test "Create type" {
    const Position = Component("Position", struct {
        x: f32,
        y: f32,
    });
    const Velocity = Component("Velocity", struct {
        x: f32,
        y: f32,
    });
    const Rotation = Component("Rotation", struct {
        degrees: i8,
    });

    const Game = World(.{
        Position,
        Velocity,
        Rotation,
    });

    var actor = Game.Type(.{
        Position,
        Velocity,
    }){};

    var game = try Game.init(.{ .allocator = std.testing.allocator, .capacity = 10 });
    defer game.deinit();

    const ent = game.create(&actor);

    try expect(ent == 1);
    try expect(game.has(ent, Position));
    try expect(game.has(ent, Velocity));
    try expect(!game.has(ent, Rotation));
}
