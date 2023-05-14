const std = @import("std");
const assert = @import("std").debug.assert;
const expect = @import("std").testing.expect;

const Component = @import("./component.zig").Component;
const ComponentId = @import("./component.zig").ComponentId;
const ComponentStorage = @import("./component.zig").ComponentStorage;
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

const DEFAULT_ARCHETYPES_STORAGE_CAPACITY = @import("./archetype-storage.zig").DEFAULT_ARCHETYPES_STORAGE_CAPACITY;
const DEFAULT_WORLD_CAPACITY = 10_000;

pub fn World(comptime ComponentsTypes: anytype, comptime capacity: u32) type {
    const WorldComponents = comptime blk: {
        var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
        const ComponentsTypesFields = std.meta.fields(@TypeOf(ComponentsTypes));

        var component_counter: u32 = 0;

        inline for (ComponentsTypesFields) |field| {
            var ComponentType = @field(ComponentsTypes, field.name);

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

        // Comptime immutable components definitions
        pub const components_definitions: WorldComponents = WorldComponents{};

        // Runtime mutable components
        pub var components: WorldComponents = WorldComponents{};

        // States the runtime components have been initialized
        pub var components_are_ready = false;

        allocator: std.mem.Allocator,

        archetypes: ArchetypeStorage,

        entities: EntityStorage,

        systems: std.ArrayList(System(*Self)),

        query_builder: QueryBuilder(Self),

        root: *Archetype,

        const WorldOptions = struct {
            allocator: std.mem.Allocator,
            archetypes_capacity: ?u32 = DEFAULT_ARCHETYPES_STORAGE_CAPACITY,
        };

        pub fn init(options: WorldOptions) !Self {
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
                .query_builder = try QueryBuilder(Self).init(
                    options.allocator,
                ),
                .root = archetypes.getRoot(),
                .systems = std.ArrayList(System(*Self)).init(options.allocator),
            };

            // Init context component
            if (!components_are_ready) {
                components = WorldComponents{};

                // Ensure components capacity
                const world_components = &std.meta.fields(WorldComponents);
                inline for (world_components.*) |*component_field| {
                    var component = &@field(components, component_field.name);

                    component.storage = ComponentStorage(@TypeOf(@field(components, component_field.name))){};
                    component.storage.setup(world.allocator, capacity) catch unreachable;

                    components_are_ready = true;
                }
            }

            return world;
        }

        // Relation between components and world instance is not clear at all. Ultra footgun
        pub fn contextDeinit(allocator: std.mem.Allocator) void {
            const world_components = &std.meta.fields(@TypeOf(components));
            inline for (world_components.*) |*component_field| {
                var component_instance = @field(components, component_field.name);
                component_instance.deinit(allocator);
            }
            components_are_ready = false;
        }

        pub fn deinit(self: *Self) void {
            self.query_builder.deinit();
            self.archetypes.deinit();
            self.entities.deinit();
            self.systems.deinit();
        }

        pub fn createEmpty(self: *Self) Entity {
            return self.entities.create(self.archetypes.getRoot());
        }

        pub fn create(self: *Self, comptime entity_type: anytype) Entity {
            assert(entity_type.type_archetype != null);
            return self.entities.create(entity_type.type_archetype orelse unreachable);
        }

        pub fn deleteEntity(self: *Self, entity: Entity) void {
            self.entities.delete(entity);
        }

        pub fn has(self: *Self, entity: Entity, comptime component: anytype) bool {
            var archetype = self.entities.getArchetype(entity) orelse unreachable;
            return archetype.has(comptime getComponentDefinition(component).id);
        }

        pub fn contains(self: *Self, entity: Entity) bool {
            return self.entities.contains(entity);
        }

        pub fn attach(self: *Self, entity: Entity, comptime component: anytype) void {
            assert(!self.has(entity, component));

            self.toggleComponent(entity, getComponentDefinition(component));
        }

        pub fn detach(self: *Self, entity: Entity, comptime component: anytype) void {
            assert(self.has(entity, component));

            self.toggleComponent(entity, getComponentDefinition(component));
        }

        pub fn pack(self: *Self, entity: Entity, comptime component: anytype) Packed(component.Schema) {
            assert(self.contains(entity));
            assert(self.has(entity, component));

            var storage = comptime @field(components, component.name).storage;
            return storage.pack(entity);
        }

        pub fn read(self: *Self, entity: Entity, comptime component: anytype) component.Schema {
            assert(self.contains(entity));
            assert(self.has(entity, component));

            var storage = comptime @field(components, component.name).storage;
            return storage.read(entity);
        }

        pub fn write(self: *Self, entity: Entity, comptime component: anytype, data: anytype) void {
            assert(self.contains(entity));
            assert(self.has(entity, component));

            var storage = comptime @field(components, component.name).storage;
            storage.write(entity, data);
        }

        pub fn get(self: *Self, entity: Entity, comptime component: anytype, comptime prop: anytype) *@TypeOf(@field(ComponentStorage(component).schema_instance, prop)) {
            assert(self.contains(entity));
            assert(self.has(entity, component));

            var storage = comptime @field(components, component.name).storage;
            return storage.get(entity, prop);
        }

        pub fn set(self: *Self, entity: Entity, comptime component: anytype, comptime prop: anytype, data: anytype) void {
            assert(self.contains(entity));
            assert(self.has(entity, component));

            var storage = comptime @field(components, component.name).storage;
            storage.set(entity, prop, data);
        }

        pub fn query(self: *Self) *QueryBuilder(Self) {
            // Errrk so ugly
            if (self.query_builder.world != self) {
                self.query_builder.world = self;
            }
            return &self.query_builder;
        }

        pub fn addSystem(self: *Self, system: System(*Self)) void {
            self.systems.append(system) catch unreachable;
        }

        pub fn step(self: *Self) void {
            for (self.systems.items) |system| {
                system(self);
            }
        }

        pub fn getComponentDefinition(comptime component: anytype) @TypeOf(@field(components_definitions, component.name)) {
            return comptime @field(components_definitions, component.name);
        }

        pub fn Type(comptime definition: anytype) type {
            const definition_fields = comptime std.meta.fields(@TypeOf(definition));

            return struct {
                pub var type_archetype: ?*Archetype = null;

                fn precalcArchetype(world: *Self) void {
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

                    type_archetype = archetype;
                }
            };
        }

        pub fn registerType(self: *Self, comptime entity_type: anytype) void {
            entity_type.precalcArchetype(self);
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
    const Ecs = World(.{
        Component("Position", struct {
            x: f32,
            y: f32,
        }),
        Component("Velocity", struct {
            x: f32,
            y: f32,
        }),
    }, 10);

    try expect(Ecs.components.Position.id == 1);
    try expect(Ecs.components.Velocity.id == 2);
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

    const Ecs = World(.{
        Position,
        Velocity,
        Rotation,
    }, 10);
    var ecs = try Ecs.init(.{ .allocator = std.testing.allocator });
    defer ecs.deinit();
    defer Ecs.contextDeinit(ecs.allocator);

    var ent = ecs.createEmpty();

    ecs.attach(ent, Position);
    try expect(ecs.has(ent, Position));
    try expect(!ecs.has(ent, Rotation));

    ecs.attach(ent, Rotation);
    try expect(ecs.has(ent, Rotation));

    ecs.detach(ent, Position);
    try expect(!ecs.has(ent, Position));
    try expect(ecs.has(ent, Rotation));

    ecs.detach(ent, Rotation);
    try expect(!ecs.has(ent, Position));
    try expect(!ecs.has(ent, Rotation));
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

    const Ecs = World(.{
        Position,
        Velocity,
        Rotation,
    }, 10);

    const Actor = Ecs.Type(.{
        Position,
        Velocity,
    });

    var ecs = try Ecs.init(.{ .allocator = std.testing.allocator });
    defer ecs.deinit();
    defer Ecs.contextDeinit(ecs.allocator);

    ecs.registerType(Actor);

    const ent = ecs.create(Actor);

    try expect(ent == 1);
    try expect(ecs.has(ent, Position));
    try expect(ecs.has(ent, Velocity));
    try expect(!ecs.has(ent, Rotation));
}

test "Create multiple types" {
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

    const Ecs = World(.{
        Position,
        Velocity,
        Rotation,
    }, 10);

    const Actor = Ecs.Type(.{
        Position,
        Velocity,
    });

    const Body = Ecs.Type(.{
        Position,
        Velocity,
        Rotation,
    });

    var ecs = try Ecs.init(.{ .allocator = std.testing.allocator });
    defer ecs.deinit();
    defer Ecs.contextDeinit(ecs.allocator);

    ecs.registerType(Actor);
    ecs.registerType(Body);

    const ent = ecs.create(Actor);

    try expect(ent == 1);
    try expect(ecs.has(ent, Position));
    try expect(ecs.has(ent, Velocity));
    try expect(!ecs.has(ent, Rotation));

    const ent2 = ecs.create(Body);

    try expect(ent2 == 2);
    try expect(ecs.has(ent2, Position));
    try expect(ecs.has(ent2, Velocity));
    try expect(ecs.has(ent2, Rotation));
}

test "write component data" {
    const Position = Component("Position", struct { x: f32, y: f32 });

    const Ecs = World(.{Position}, 10);
    var ecs = try Ecs.init(.{ .allocator = std.testing.allocator });
    defer ecs.deinit();
    defer Ecs.contextDeinit(ecs.allocator);

    const entity = ecs.createEmpty();
    ecs.attach(entity, Position);
    ecs.write(entity, Position, .{ .x = 10, .y = 20 });

    var data = ecs.read(entity, Position);
    try expect(data.x == 10);
    try expect(data.y == 20);
}

test "Set component prop" {
    const Position = Component("Position", struct { x: f32, y: f32 });

    const Ecs = World(.{Position}, 10);
    var ecs = try Ecs.init(.{ .allocator = std.testing.allocator });
    defer ecs.deinit();
    defer Ecs.contextDeinit(ecs.allocator);

    const entity = ecs.createEmpty();
    ecs.attach(entity, Position);
    ecs.set(entity, Position, "x", 10);

    var x = ecs.get(entity, Position, "x");
    try expect(x.* == 10);
}

test "Queries are cached" {
    const Position = Component("Position", struct { x: f32, y: f32 });
    const Velocity = Component("Velocity", struct { x: f32, y: f32 });
    const Health = Component("Health", struct { points: u32 });

    const Ecs = World(.{ Position, Velocity, Health }, 10);
    var ecs = try Ecs.init(.{ .allocator = std.testing.allocator });
    defer ecs.deinit();
    defer Ecs.contextDeinit(ecs.allocator);

    var query_a_1 = ecs.query().any(.{Position}).execute();
    var query_a_2 = ecs.query().any(.{Position}).execute();

    try expect(query_a_1 == query_a_2);
    try expect(ecs.query_builder.queries.count() == 1);

    var query_b_1 = ecs.query().any(.{ Position, Velocity }).execute();
    var query_b_2 = ecs.query().any(.{ Position, Velocity }).execute();

    try expect(query_b_1 == query_b_2);
    try expect(ecs.query_builder.queries.count() == 2);

    var query_c_1 = ecs.query().any(.{Position}).not(.{Velocity}).all(.{Health}).execute();
    var query_c_2 = ecs.query().any(.{Position}).not(.{Velocity}).all(.{Health}).execute();

    try expect(query_c_1 == query_c_2);
    try expect(ecs.query_builder.queries.count() == 3);
}

const SysPosition = Component("SysPosition", struct { x: f32, y: f32 });
const SysVelocity = Component("SysVelocity", struct { x: f32, y: f32 });
const SysHealth = Component("SysHealth", struct { points: u32 });
const SystemEcs = World(.{ SysPosition, SysVelocity, SysHealth }, 10);
fn testSystem(world: *SystemEcs) void {
    var iterator = world.query().all(.{ SysPosition, SysVelocity }).execute().iterator();

    while (iterator.next()) |entity| {
        var pos = world.read(entity, SysPosition);
        var vel = world.read(entity, SysVelocity);
        world.write(entity, SysPosition, .{
            .x = pos.x + vel.x,
            .y = pos.y + vel.y,
        });
    }
}

test "Can use  systems" {
    var ecs = try SystemEcs.init(.{ .allocator = std.testing.allocator });
    defer ecs.deinit();
    defer SystemEcs.contextDeinit(ecs.allocator);

    const Actor = SystemEcs.Type(.{ SysPosition, SysVelocity });
    ecs.registerType(Actor);
    var i: u32 = 0;
    while (i < 9) : (i += 1) {
        var entity = ecs.create(Actor);
        ecs.write(entity, SysPosition, .{
            .x = 0,
            .y = 0,
        });
        ecs.write(entity, SysVelocity, .{
            .x = 2,
            .y = 2,
        });
    }

    ecs.addSystem(&testSystem);

    ecs.step();

    var pos_1 = ecs.read(1, SysPosition);
    try expect(pos_1.x == 2);
    try expect(pos_1.y == 2);

    var pos_8 = ecs.read(8, SysPosition);
    try expect(pos_8.x == 2);
    try expect(pos_8.y == 2);
}
