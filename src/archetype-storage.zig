const std = @import("std");

const Component = @import("./component.zig").Component;
const ComponentId = @import("./component.zig").ComponentId;

const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;

const QueryCallback = @import("./system.zig").QueryCallback;

pub const DEFAULT_ARCHETYPE_CAPACITY = 10_000;
pub const DEFAULT_ARCHETYPES_STORAGE_CAPACITY = 1000;

pub fn ArchetypeStorage(comptime Context: anytype) type {
    _ = Context;
    return struct {
        const Self = @This();

        const ArchetypeStorageOptions = struct {
            capacity: ?u32,
            archetype_capacity: ?u32 = DEFAULT_ARCHETYPES_STORAGE_CAPACITY,
        };

        allocator: std.mem.Allocator,

        all: std.ArrayList(Archetype),

        // on_enter_callbacks: std.AutoHashMap(Archetype.Id, std.ArrayList(QueryCallback(Context))),

        // on_exit_callbacks: std.AutoHashMap(Archetype.Id, std.ArrayList(QueryCallback(Context))),

        capacity: u32,

        archetype_capacity: u32,

        pub fn init(options: ArchetypeStorageOptions, allocator: std.mem.Allocator) !Self {
            var capacity = options.capacity orelse DEFAULT_ARCHETYPES_STORAGE_CAPACITY;
            var archetype_capacity = options.archetype_capacity orelse DEFAULT_ARCHETYPE_CAPACITY;

            var all = try std.ArrayList(Archetype).initCapacity(allocator, capacity);

            // var on_enter_callbacks = std.AutoHashMap(Archetype.Id, std.ArrayList(QueryCallback(Context))).init(allocator);
            // _ = on_enter_callbacks;
            // var on_exit_callbacks = std.AutoHashMap(Archetype.Id, std.ArrayList(QueryCallback(Context))).init(allocator);
            // _ = on_exit_callbacks;

            var storage = Self{
                .allocator = allocator,
                .all = all,
                .capacity = capacity,
                .archetype_capacity = archetype_capacity,
                // .on_enter_callbacks = on_enter_callbacks,
                // .on_exit_callbacks = on_exit_callbacks,
            };

            var root = Archetype.build(.{}, allocator, archetype_capacity);

            storage.all.appendAssumeCapacity(root);

            return storage;
        }

        pub fn deinit(self: *Self) void {
            for (self.all.items) |*arch| {
                arch.deinit();
            }
            self.all.deinit();

            // var on_enter_callbacks = self.on_enter_callbacks.iterator();
            // while (on_enter_callbacks.next()) |*entry| {
            //     entry.value_ptr.deinit();
            // }
            // self.on_enter_callbacks.deinit();

            // var on_exit_callbacks = self.on_exit_callbacks.iterator();
            // while (on_exit_callbacks.next()) |*entry| {
            //     entry.value_ptr.deinit();
            // }
            // self.on_exit_callbacks.deinit();
        }

        pub fn derive(self: *Self, archetype: *Archetype, component_id: ComponentId) *Archetype {
            var derived = archetype.derive(component_id, self.allocator, self.archetype_capacity);
            var new_archetype = self.register(&derived);

            new_archetype.edge.set(component_id, archetype);
            archetype.edge.set(component_id, new_archetype);

            return new_archetype;
        }

        pub fn register(
            self: *Self,
            archetype: *Archetype,
        ) *Archetype {
            self.all.appendAssumeCapacity(archetype.*);
            return &self.all.items[self.all.items.len - 1];
        }

        pub fn getRoot(self: *Self) *Archetype {
            return &self.all.items[0];
        }
    };
}
