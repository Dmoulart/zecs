const std = @import("std");
const meta = @import("std").meta;
const assert = @import("std").debug.assert;
const expect = @import("std").testing.expect;

const Component = @import("./component.zig").Component;
const ComponentId = @import("./component.zig").ComponentId;
const ComponentStorage = @import("./component.zig").ComponentStorage;
const Tag = @import("./component.zig").Tag;
const Packed = @import("./component.zig").Packed;

const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;
const ArchetypeStorage = @import("./archetype-storage.zig").ArchetypeStorage;

const SparseSet = @import("./sparse-set.zig").SparseSet;
const SparseArray = @import("./sparse-array.zig").SparseArray;
const QueryBuilder = @import("./query.zig").QueryBuilder;
const Query = @import("./query.zig").Query;
const Entity = @import("./entity-storage.zig").Entity;
const EntityStorage = @import("./entity-storage.zig").EntityStorage;
const System = @import("./system.zig").System;
const OnEnterQuery = @import("./system.zig").OnEnterQuery;

const DEFAULT_ARCHETYPES_STORAGE_CAPACITY = @import("./archetype-storage.zig").DEFAULT_ARCHETYPES_STORAGE_CAPACITY;
const DEFAULT_WORLD_CAPACITY = 10_000;

const ContextError = error{
    NotReady,
    AlreadyReady,
};

pub fn Context(comptime config: anytype) type {
    const ContextComponents = comptime blk: {
        var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
        const ComponentsTypesFields = std.meta.fields(@TypeOf(config.components));

        var component_counter: u32 = 0;

        inline for (ComponentsTypesFields) |field| {
            var ComponentType = @field(config.components, field.name);

            component_counter += 1;
            var component_instance = ComponentType{
                .id = component_counter,
            };

            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = ComponentType.name[0..],
                .field_type = ComponentType,
                .is_comptime = false,
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

        // The allocator used to allocate the components storage
        pub var context_allocator: std.mem.Allocator = undefined;

        // Comptime immutable components definitions
        // @todo: create a whole other objects ? components identifiers ?
        pub const components_definitions: ContextComponents = ContextComponents{};

        // Runtime mutable components
        pub var components: ContextComponents = ContextComponents{};

        // States the runtime components have been initialized
        pub var components_are_ready = false;

        // The context resources type
        pub const Resources = config.Resources;

        // The component storage capacity
        const capacity: u32 = config.capacity;

        var entity_counter: Entity = 0;

        allocator: std.mem.Allocator,

        archetypes: ArchetypeStorage,

        entities: EntityStorage,

        systems: std.ArrayList(System(Self)),

        // on_add: SparseArray(usize, OnEnterQuery(*Self)),

        query_builder: QueryBuilder(Self),

        resources: Resources,

        root: *Archetype,

        const ContextOptions = struct {
            allocator: std.mem.Allocator,
            archetypes_capacity: ?u32 = DEFAULT_ARCHETYPES_STORAGE_CAPACITY,
        };

        pub fn setup(allocator: std.mem.Allocator) !void {
            // Init context component
            if (components_are_ready) {
                return ContextError.AlreadyReady;
            }

            context_allocator = allocator;

            components = ContextComponents{};

            // Ensure components capacity
            const components_fields = std.meta.fields(ContextComponents);

            inline for (components_fields) |component_field| {
                var component = &@field(components, component_field.name);

                component.storage = ComponentStorage(@TypeOf(component.*)){};

                try component.storage.setup(context_allocator, capacity);
            }

            components_are_ready = true;
        }

        pub fn unsetup() void {
            const context_components = std.meta.fields(@TypeOf(components));

            inline for (context_components) |*component_field| {
                var component = @field(components, component_field.name);

                component.deinit(context_allocator);
            }

            components_are_ready = false;
        }

        pub fn init(options: ContextOptions) !Self {
            if (!components_are_ready) {
                return ContextError.NotReady;
            }

            var archetypes_storage_capacity = options.archetypes_capacity;

            var archetypes = try ArchetypeStorage.init(.{
                .capacity = archetypes_storage_capacity,
                .archetype_capacity = capacity,
            }, options.allocator);

            var entities = try EntityStorage.init(.{
                .allocator = options.allocator,
                .capacity = capacity,
            });

            var context = Self{
                .allocator = options.allocator,
                .archetypes = archetypes,
                .entities = entities,
                .query_builder = try QueryBuilder(Self).init(
                    options.allocator,
                ),
                .root = archetypes.getRoot(),
                .systems = std.ArrayList(System(Self)).init(options.allocator),
                // .on_add = SparseArray(usize, OnEnterQuery(*Self)).init(.{
                //     .allocator = options.allocator,
                //     .capacity = archetypes.capacity,
                // }),
                .resources = Resources{},
            };

            return context;
        }

        pub fn deinit(self: *Self) void {
            self.query_builder.deinit();
            self.archetypes.deinit();
            self.entities.deinit();
            self.systems.deinit();
        }

        pub fn createEmpty(self: *Self) Entity {
            return self.entities.create(self.archetypes.getRoot(), &entity_counter);
        }

        pub fn create(self: *Self, comptime entity_type: anytype) Entity {
            assert(entity_type.type_archetype != null);

            return self.entities.create(
                entity_type.type_archetype orelse unreachable,
                &entity_counter,
            );
        }

        pub fn deleteEntity(self: *Self, entity: Entity) void {
            self.entities.delete(entity);
        }

        pub fn has(self: *Self, entity: Entity, comptime component_name: ComponentName) bool {
            var archetype = self.entities.getArchetype(entity) orelse unreachable;
            var component = comptime getComponentDefinition(component_name);

            return archetype.has(component.id);
        }

        pub fn contains(self: *Self, entity: Entity) bool {
            return self.entities.contains(entity);
        }

        pub fn attach(self: *Self, entity: Entity, comptime component_name: ComponentName) void {
            assert(!self.has(entity, component_name));

            self.toggleComponent(entity, component_name);
        }

        pub fn detach(
            self: *Self,
            entity: Entity,
            comptime component_name: ComponentName,
        ) void {
            assert(self.has(entity, component_name));

            self.toggleComponent(entity, component_name);
        }

        pub fn pack(
            self: *Self,
            entity: Entity,
            comptime component_name: ComponentName,
        ) Packed(ComponentSchema(component_name)) {
            assert(self.contains(entity));
            assert(self.has(entity, component_name));

            var storage = getComponent(component_name).storage;
            return storage.pack(entity);
        }

        pub fn copy(
            self: *Self,
            entity: Entity,
            comptime component_name: ComponentName,
            dist: *ComponentSchema(component_name),
        ) void {
            assert(self.contains(entity));
            assert(self.has(entity, component_name));

            var storage = getComponent(component_name).storage;
            storage.copy(entity, dist);
        }

        pub fn clone(
            self: *Self,
            entity: Entity,
            comptime component_name: ComponentName,
        ) ComponentSchema(component_name) {
            assert(self.contains(entity));
            assert(self.has(entity, component_name));

            var storage = getComponent(component_name).storage;
            return storage.clone(entity);
        }

        pub fn write(self: *Self, entity: Entity, comptime component_name: ComponentName, data: anytype) void {
            assert(self.contains(entity));
            assert(self.has(entity, component_name));

            var storage = getComponent(component_name).storage;
            storage.write(entity, data);
        }

        // @todo simplify the fuck out of these types signatures
        pub fn get(
            self: *Self,
            entity: Entity,
            comptime component_name: ComponentName,
            comptime prop: ComponentPropField(component_name),
        ) *@TypeOf(
            @field(
                ComponentStorage(@TypeOf(getComponentDefinition(component_name))).schema_instance,
                @tagName(prop),
            ),
        ) {
            assert(self.contains(entity));
            assert(self.has(entity, component_name));

            var storage = getComponent(component_name).storage;
            return storage.get(entity, comptime @tagName(prop));
        }

        pub fn set(
            self: *Self,
            entity: Entity,
            comptime component_name: ComponentName,
            comptime prop: ComponentPropField(component_name),
            data: anytype,
        ) void {
            assert(self.contains(entity));
            assert(self.has(entity, component_name));

            var storage = getComponent(component_name).storage;
            storage.set(entity, prop, data);
        }

        // pub fn assign(
        //     self: *Self,
        //     entity: Entity,
        //     data: anytype,
        // ) void {
        //     assert(self.contains(entity));

        //     const data_fields = comptime meta.fields(@TypeOf(data));

        //     inline for (data_fields) |data_field| {
        //         const component_name = comptime data_field.name;

        //         var component_data = comptime @field(data, component_name);

        //         var name = comptime meta.stringToEnum(ComponentName, component_name).?;

        //         var storage = comptime getComponent(name).storage;
        //         self.attach(entity, name);
        //         storage.write(component_data);

        //         // const component_fields = comptime meta.fields(@TypeOf(component_data));
        //         // _ = component_data;
        //         // inline for (component_fields) |component_field| {
        //         //     const component_prop_name = comptime component_field.name;
        //         //     var component_prop_value = @field(component_fields, component_prop_name);
        //         //     var component_data = @field(data_fields, field.name);
        //         //     _ = component_data;
        //         // }
        //     }
        //     // const DataEnum = comptime meta.FieldEnum(@TypeOf(data));

        //     // inline for (comptime meta.fieldNames(DataEnum)) |field_name, i| {
        //     //     _ = field_name;
        //     //     // const component_name = comptime field.name;
        //     //     const name = comptime @intToEnum(DataEnum, i);
        //     //     var component_data = @field(data, @tagName(name));

        //     //     var storage = getComponentByString(@tagName(name)).storage;
        //     //     self.attach(entity, name);
        //     //     storage.write(component_data);
        //     // }
        //     // @tagName(value: anytype)
        // }

        pub fn query(self: *Self) *QueryBuilder(Self) {
            // Errrk so ugly
            if (self.query_builder.context != self) {
                self.query_builder.context = self;
            }
            return &self.query_builder;
        }

        pub fn addSystem(self: *Self, system: System(Self)) void {
            self.systems.append(system) catch unreachable;
        }

        // pub fn addSystem(self: *Self, system: System(*Self)) void {
        //     self.systems.append(system) catch unreachable;
        // }

        pub fn step(self: *Self) void {
            for (self.systems.items) |system| {
                system(self);
            }
        }

        pub fn getComponentDefinition(comptime component_name: ComponentName) @TypeOf(@field(components_definitions, @tagName(component_name))) {
            return comptime @field(components_definitions, @tagName(component_name));
        }

        pub fn getComponent(comptime component_name: ComponentName) @TypeOf(@field(components_definitions, @tagName(component_name))) {
            return comptime @field(components, @tagName(component_name));
        }

        // pub fn getComponentByString(comptime component_name: []const u8) @TypeOf(@field(components_definitions, component_name)) {
        //     return comptime @field(components, component_name);
        // }

        pub fn Resource(comptime field: meta.FieldEnum(Resources)) type {
            return comptime meta.fieldInfo(Resources, field).field_type;
        }

        pub fn getResource(self: *Self, comptime field: meta.FieldEnum(Resources)) Resource(field) {
            return comptime @field(self.resources, @tagName(field));
        }

        pub fn setResource(self: *Self, comptime field: meta.FieldEnum(Resources), value: Resource(field)) void {
            comptime @field(self.resources, @tagName(field)) = value;
        }

        pub fn registerType(self: *Self, comptime entity_type: anytype) void {
            entity_type.precalcArchetype(self);
        }

        fn toggleComponent(self: *Self, entity: Entity, comptime component_name: ComponentName) void {
            var archetype: *Archetype = self.entities.getArchetype(entity) orelse unreachable;

            var component = comptime getComponentDefinition(component_name);

            if (archetype.edge.get(component.id)) |edge| {
                self.swapArchetypes(entity, archetype, edge);
            } else {
                var new_archetype = self.archetypes.derive(archetype, component.id);

                // match against queries
                var queries = self.query_builder.queries.iterator();
                while (queries.next()) |*existant_query| {
                    existant_query.value_ptr.maybeRegisterArchetype(new_archetype);
                }

                self.swapArchetypes(entity, archetype, new_archetype);
            }
        }

        fn swapArchetypes(self: *Self, entity: Entity, old: *Archetype, new: *Archetype) void {
            self.entities.setArchetype(entity, new);

            old.entities.removeUnsafe(entity);
            new.entities.add(entity);
        }

        // Create a pr-egenerated entity type from a set of components.
        // A type must be registered by the context before being used.
        pub fn Type(comptime definition: anytype) type {
            const components_names = comptime std.meta.fields(@TypeOf(definition));

            return struct {
                pub var type_archetype: ?*Archetype = null;

                fn precalcArchetype(context: *Self) void {
                    var archetype = context.archetypes.getRoot();

                    inline for (components_names) |*field| {
                        const component_id = comptime blk: {
                            const component_name = @field(definition, field.name);
                            break :blk getComponentDefinition(component_name).id;
                        };

                        archetype = if (archetype.edge.get(component_id)) |derived|
                            derived
                        else
                            context.archetypes.derive(archetype, component_id);
                    }

                    type_archetype = archetype;
                }
            };
        }
        const ComponentName = meta.FieldEnum(ContextComponents);

        pub fn ComponentPropField(comptime component_name: ComponentName) type {
            return meta.FieldEnum(@TypeOf(getComponentDefinition(component_name)).Schema);
        }

        pub fn ComponentSchema(comptime component_name: ComponentName) type {
            return @TypeOf(getComponentDefinition(component_name)).Schema;
        }
    };
}

test "Create Context type with comptime components" {
    comptime {
        const Ecs = Context(.{
            .components = .{
                Component("Position", struct {
                    x: f32,
                    y: f32,
                }),
                Component("Velocity", struct {
                    x: f32,
                    y: f32,
                }),
            },
            .Resources = struct {},
            .capacity = 10,
        });

        try expect(Ecs.components_definitions.Position.id == 1);
        try expect(Ecs.components_definitions.Velocity.id == 2);
    }
}

test "Can create Entity" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 1,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();

    try expect(ent == 1);
}

test "Can remove Entity" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 1,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.deleteEntity(ent);

    try expect(!ecs.contains(ent));
}

test "Can resize" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 4,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    _ = ecs.createEmpty();
    _ = ecs.createEmpty();
    _ = ecs.createEmpty();
    _ = ecs.createEmpty();

    try expect(ecs.entities.capacity == 4);

    _ = ecs.createEmpty();

    try expect(ecs.entities.capacity == 4 * 2); // grow factor of 2?
}

test "Can create multiple worlds" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 4,
    });

    var arena_1: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    var arena_2: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_1.deinit();
    defer arena_2.deinit();

    try Ecs.setup(arena_1.child_allocator);
    defer Ecs.unsetup();

    var world_1 = try Ecs.init(.{ .allocator = arena_1.child_allocator });
    var world_2 = try Ecs.init(.{ .allocator = arena_2.child_allocator });
    defer world_1.deinit();
    defer world_2.deinit();

    var ent_1 = world_1.createEmpty();
    var ent_2 = world_2.createEmpty();

    try expect(ent_1 == 1);
    try expect(ent_2 == 2);

    try expect(world_1.contains(ent_1));
    try expect(!world_1.contains(ent_2));

    try expect(!world_2.contains(ent_1));
    try expect(world_2.contains(ent_2));

    world_1.attach(ent_1, .Position);
    world_2.attach(ent_2, .Velocity);

    try expect(world_1.has(ent_1, .Position));
    try expect(!world_1.has(ent_1, .Velocity));

    try expect(world_2.has(ent_2, .Velocity));
    try expect(!world_2.has(ent_2, .Position));
}

test "Can recycle Entity" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    try expect(ecs.contains(ent));

    ecs.deleteEntity(ent);
    try expect(!ecs.contains(ent));

    var ent2 = ecs.createEmpty();
    try expect(ent2 == ent);
}

test "Can attach component" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();

    ecs.attach(ent, .Position);
    try expect(ecs.has(ent, .Position));
    try expect(!ecs.has(ent, .Velocity));

    ecs.attach(ent, .Velocity);
    try expect(ecs.has(ent, .Position));
    try expect(ecs.has(ent, .Velocity));
}

test "Can detach component" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    try expect(ecs.has(ent, .Position));
    try expect(ecs.has(ent, .Velocity));

    ecs.detach(ent, .Position);
    try expect(!ecs.has(ent, .Position));
    try expect(ecs.has(ent, .Velocity));

    ecs.detach(ent, .Velocity);
    try expect(!ecs.has(ent, .Velocity));
}

test "Can create tag component" {
    const Ecs = Context(.{
        .components = .{
            Tag("Alive"),
            Tag("Dead"),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();

    ecs.attach(ent, .Alive);

    try expect(ecs.has(ent, .Alive));

    ecs.detach(ent, .Alive);
    try expect(!ecs.has(ent, .Alive));

    ecs.attach(ent, .Dead);
    try expect(ecs.has(ent, .Dead));
}

test "Can generate archetype" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();

    ecs.attach(ent, .Position);
    var mask = ecs.archetypes.all.items[1].mask;

    try expect(mask.has(Ecs.components.Position.id));
    try expect(!mask.has(Ecs.components.Velocity.id));
}

test "Can automatically add new archetypes to existing queries" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    var ent2 = ecs.createEmpty();

    ecs.attach(ent, .Position);

    ecs.attach(ent2, .Velocity);

    var query = ecs.query().any(.{ .Position, .Velocity }).execute();

    var ent3 = ecs.createEmpty();

    ecs.attach(ent3, .Position);
    ecs.attach(ent3, .Velocity);

    try expect(query.contains(ent3));
}

test "Can query multiple components" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    var ent2 = ecs.createEmpty();

    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    ecs.attach(ent2, .Position);

    var query = ecs.query().all(.{ .Position, .Velocity }).execute();

    try expect(query.contains(ent));
    try expect(!query.contains(ent2));

    var query2 = ecs.query().all(.{.Position}).execute();
    defer query2.deinit();

    try expect(query2.contains(ent));
    try expect(query2.contains(ent2));

    ecs.attach(ent2, .Velocity);

    try expect(query.contains(ent2));
    try expect(query2.contains(ent2));
}

test "Can iterate over query using iterator " {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Position);
    ecs.attach(ent2, .Velocity);

    var query = ecs.query().all(.{ .Position, .Velocity }).execute();

    var iterator = query.iterator();
    var counter: i32 = 0;

    while (iterator.next()) |_| {
        counter += 1;
    }

    try expect(counter == 2);
}

test "Can use the all query operator" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Position);
    ecs.attach(ent2, .Velocity);

    var ent3 = ecs.createEmpty();
    ecs.attach(ent3, .Position);

    var ent4 = ecs.createEmpty();
    ecs.attach(ent4, .Velocity);

    var query = ecs.query().all(.{ .Position, .Velocity }).execute();

    try expect(query.contains(ent));
    try expect(query.contains(ent2));
}

test "Can use the any query operator" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Position);

    var ent3 = ecs.createEmpty();
    ecs.attach(ent3, .Velocity);

    var result = ecs.query().any(.{ .Position, .Velocity }).execute();
    defer result.deinit();

    try expect(result.archetypes.items.len == 3);
}

test "Can use the not operator" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
            Component("Health", struct {
                points: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Health);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Velocity);

    var ent3 = ecs.createEmpty();
    ecs.attach(ent3, .Position);

    var query = ecs.query().not(.{ .Velocity, .Health }).execute();

    // Take into account the root archetype
    try expect(query.archetypes.items.len == 2);
    try expect(query.archetypes.items[1].entities.has(ent3));
}

test "Can use the none operator" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
            Component("Health", struct {
                points: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);
    ecs.attach(ent, .Velocity);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Health);

    var query = ecs.query().none(.{ .Position, .Velocity }).execute();

    try expect(!query.contains(ent));
}

test "Can combine query operators" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
            Component("Health", struct {
                points: f32,
            }),
            Component("Intelligence", struct {
                points: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var ent = ecs.createEmpty();
    ecs.attach(ent, .Position);

    var ent2 = ecs.createEmpty();
    ecs.attach(ent2, .Position);
    ecs.attach(ent2, .Velocity);
    ecs.attach(ent2, .Health);

    var ent3 = ecs.createEmpty();
    ecs.attach(ent3, .Health);
    ecs.attach(ent3, .Intelligence);

    var ent4 = ecs.createEmpty();
    ecs.attach(ent4, .Position);
    ecs.attach(ent4, .Intelligence);

    var query = ecs.query()
        .not(.{.Velocity})
        .any(.{ .Health, .Intelligence, .Position })
        .none(.{ .Position, .Intelligence })
        .execute();

    try expect(query.contains(ent));
    try expect(!query.contains(ent2));
    try expect(query.contains(ent3));
    try expect(!query.contains(ent4));
}

test "Can create type" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
            Component("Rotation", struct {
                degrees: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    const Actor = Ecs.Type(.{
        .Position,
        .Velocity,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    ecs.registerType(Actor);

    const ent = ecs.create(Actor);

    try expect(ent == 1);
    try expect(ecs.has(ent, .Position));
    try expect(ecs.has(ent, .Velocity));
    try expect(!ecs.has(ent, .Rotation));
}

test "Can create multiple types" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
            Component("Rotation", struct {
                degrees: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    const Actor = Ecs.Type(.{
        .Position,
        .Velocity,
    });

    const Body = Ecs.Type(.{
        .Position,
        .Velocity,
        .Rotation,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    ecs.registerType(Actor);
    ecs.registerType(Body);

    const ent = ecs.create(Actor);

    try expect(ent == 1);
    try expect(ecs.has(ent, .Position));
    try expect(ecs.has(ent, .Velocity));
    try expect(!ecs.has(ent, .Rotation));

    const ent2 = ecs.create(Body);

    try expect(ent2 == 2);
    try expect(ecs.has(ent2, .Position));
    try expect(ecs.has(ent2, .Velocity));
    try expect(ecs.has(ent2, .Rotation));
}

test "Can write component data" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    const entity = ecs.createEmpty();
    ecs.attach(entity, .Position);
    ecs.write(entity, .Position, .{ .x = 10, .y = 20 });

    var data = ecs.clone(entity, .Position);
    try expect(data.x == 10);
    try expect(data.y == 20);
}

// test "Can assign component data" {
//     const Ecs = Context(.{
//         .components = .{
//             Component("Position", struct { x: f32, y: f32 }),
//             Component("Velocity", struct { x: f32, y: f32 }),
//         },
//         .Resources = struct {},
//         .capacity = 1,
//     });

//     var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();

//     try Ecs.setup(arena.child_allocator);
//     defer Ecs.unsetup();

//     var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
//     defer ecs.deinit();

//     const entity = ecs.createEmpty();
//     ecs.assign(entity, .{
//         .Position = .{
//             .x = 10,
//             .y = 20,
//         },
//         .Velocity = .{
//             .x = 40,
//             .y = 50,
//         },
//     });

//     var position = ecs.clone(entity, .Position);
//     var velocity = ecs.clone(entity, .Velocity);

//     try expect(position.x == 10);
//     try expect(position.y == 20);

//     try expect(velocity.x == 40);
//     try expect(velocity.y == 50);
// }

test "Can set component prop" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    const entity = ecs.createEmpty();
    ecs.attach(entity, .Position);
    ecs.set(entity, .Position, .x, 10);

    var x = ecs.get(entity, .Position, .x);
    try expect(x.* == 10);
}

test "Can set component prop with packed component" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    const entity = ecs.createEmpty();
    ecs.attach(entity, .Position);

    var pos = ecs.pack(entity, .Position);
    pos.x.* = 10;
    pos.y.* = 20;

    var read_pos = ecs.clone(entity, .Position);
    try expect(read_pos.x == 10);
    try expect(read_pos.y == 20);
}

test "Can cache queries" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
            Component("Health", struct {
                points: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var query_a_1 = ecs.query().any(.{.Position}).execute();
    var query_a_2 = ecs.query().any(.{.Position}).execute();

    try expect(query_a_1 == query_a_2);
    try expect(ecs.query_builder.queries.count() == 1);

    var query_b_1 = ecs.query().any(.{ .Position, .Velocity }).execute();
    var query_b_2 = ecs.query().any(.{ .Position, .Velocity }).execute();

    try expect(query_b_1 == query_b_2);
    try expect(ecs.query_builder.queries.count() == 2);

    var query_c_1 = ecs.query().any(.{.Position}).not(.{.Velocity}).all(.{.Health}).execute();
    var query_c_2 = ecs.query().any(.{.Position}).not(.{.Velocity}).all(.{.Health}).execute();

    try expect(query_c_1 == query_c_2);
    try expect(ecs.query_builder.queries.count() == 3);
}

test "Can run systems" {
    const Ecs = Context(.{
        .components = .{
            Component("Position", struct {
                x: f32,
                y: f32,
            }),
            Component("Velocity", struct {
                x: f32,
                y: f32,
            }),
            Component("Health", struct {
                points: f32,
            }),
        },
        .Resources = struct {},
        .capacity = 10,
    });

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Ecs.setup(arena.child_allocator);
    defer Ecs.unsetup();

    var ecs = try Ecs.init(.{ .allocator = arena.child_allocator });
    defer ecs.deinit();

    var i: u32 = 0;
    while (i < 9) : (i += 1) {
        var entity = ecs.createEmpty();
        ecs.attach(entity, .Position);
        ecs.attach(entity, .Velocity);

        ecs.write(entity, .Position, .{
            .x = 0,
            .y = 0,
        });
        ecs.write(entity, .Velocity, .{
            .x = 2,
            .y = 2,
        });
    }

    const Sys = struct {
        fn testSystem(context: *Ecs) void {
            var iterator = context.query().all(.{ .Position, .Velocity }).execute().iterator();

            while (iterator.next()) |entity| {
                var pos = context.clone(entity, .Position);
                var vel = context.clone(entity, .Velocity);

                context.write(entity, .Position, .{
                    .x = pos.x + vel.x,
                    .y = pos.y + vel.y,
                });
            }
        }
    };

    ecs.addSystem(Sys.testSystem);

    ecs.step();

    var pos_1 = ecs.clone(1, .Position);
    try expect(pos_1.x == 2);
    try expect(pos_1.y == 2);

    var pos_8 = ecs.clone(8, .Position);
    try expect(pos_8.x == 2);
    try expect(pos_8.y == 2);
}
