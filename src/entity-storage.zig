const std = @import("std");
const Archetype = @import("./archetype.zig").Archetype;
const SparseMap = @import("./sparse-map.zig").SparseMap;
const SparseArray = @import("./sparse-array.zig").SparseArray;
const assert = @import("std").debug.assert;

pub const DEFAULT_ENTITIES_STORAGE_CAPACITY = 10_000;

var global_entity_counter: Entity = 0;

pub const Entity = u64;

pub const EntityStorage = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    all: SparseArray(Entity, *Archetype),

    deleted: std.ArrayList(Entity),

    capacity: u32,

    count: u32 = 0,

    const EntityStorageOptions = struct {
        capacity: ?u32,
        allocator: std.mem.Allocator,
    };

    pub fn init(options: EntityStorageOptions) !Self {
        const capacity: u32 = options.capacity orelse DEFAULT_ENTITIES_STORAGE_CAPACITY;

        var deletedEntities = std.ArrayList(Entity).init(options.allocator);
        try deletedEntities.ensureTotalCapacity(capacity);

        return Self{
            .allocator = options.allocator,
            .capacity = capacity,
            .all = SparseArray(Entity, *Archetype).init(.{
                .allocator = options.allocator,
                .capacity = capacity,
            }),
            .deleted = deletedEntities,
        };
    }

    pub fn deinit(self: *Self) void {
        self.all.deinit();
        self.deleted.deinit();
        // where should we put this?
        global_entity_counter = 0;
    }

    pub fn create(self: *Self, archetype: *Archetype) Entity {
        if (self.count == self.capacity) {
            self.capacity += self.getGrowFactor();
        }

        var created_entity: Entity = undefined;

        if (self.deleted.popOrNull()) |ent| {
            created_entity = ent;
        } else {
            global_entity_counter += 1;
            created_entity = global_entity_counter;
        }

        archetype.entities.add(created_entity);

        self.all.set(created_entity, archetype);

        self.count += 1;

        return created_entity;
    }

    pub fn delete(self: *Self, entity: Entity) void {
        assert(self.contains(entity));

        var archetype = self.all.get(entity) orelse unreachable;

        archetype.entities.remove(entity);
        _ = self.all.delete(entity);

        self.deleted.appendAssumeCapacity(entity);

        self.count -= 1;
    }

    pub fn getArchetype(self: *Self, entity: Entity) ?*Archetype {
        return self.all.get(entity);
    }

    pub fn setArchetype(self: *Self, entity: Entity, archetype: *Archetype) void {
        self.all.set(entity, archetype);
    }

    pub fn contains(self: *Self, entity: Entity) bool {
        return self.all.has(entity);
    }

    fn getGrowFactor(self: *Self) u32 {
        return self.capacity;
    }
};
