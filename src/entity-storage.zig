const std = @import("std");
const Archetype = @import("./archetype.zig").Archetype;
const assert = @import("std").debug.assert;

pub const DEFAULT_ENTITIES_STORAGE_CAPACITY = 10_000;

var global_entity_counter: Entity = 0;

pub const Entity = u64;

pub const EntityStorage = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    all: std.AutoHashMap(Entity, *Archetype),

    deleted: std.ArrayList(Entity),

    capacity: u32,

    count: u32 = 0,

    const EntityStorageOptions = struct {
        capacity: u32 = DEFAULT_ENTITIES_STORAGE_CAPACITY,
        allocator: std.mem.Allocator,
    };

    pub fn init(options: EntityStorageOptions) !Self {
        var entitiesArchetypes = std.AutoHashMap(Entity, *Archetype).init(options.allocator);
        try entitiesArchetypes.ensureTotalCapacity(options.capacity);

        var deletedEntities = std.ArrayList(Entity).init(options.allocator);
        try deletedEntities.ensureTotalCapacity(options.capacity);

        return Self{
            .allocator = options.allocator,
            .capacity = options.capacity,
            .all = entitiesArchetypes,
            .deleted = deletedEntities,
        };
    }

    pub fn deinit(self: *Self) void {
        self.entitiesArchetypes.deinit();
        self.deletedEntities.deinit();
    }

    pub fn create(self: *Self, archetype: *Archetype) Entity {
        if (self.count == self.capacity) {
            self.all.ensureTotalCapacity(self.capacity + self.getGrowFactor()) catch unreachable;
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

        self.all.putAssumeCapacity(created_entity, archetype);

        self.count += 1;

        return created_entity;
    }

    pub fn delete(self: *Self, entity: Entity) void {
        assert(self.exists(entity));

        var archetype = self.entitiesArchetypes.get(entity) orelse unreachable;

        archetype.entities.remove(entity);
        _ = self.entitiesArchetypes.remove(entity);

        self.deletedEntities.appendAssumeCapacity(entity);

        self.count -= 1;
    }

    pub fn exists(self: *Self, entity: Entity) bool {
        return self.all.contains(entity);
    }

    fn getGrowFactor(self: *Self) u32 {
        return self.capacity;
    }
};
