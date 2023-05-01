const std = @import("std");
const Component = @import("./component.zig").Component;
const ComponentId = @import("./component.zig").ComponentId;
const ArchetypeMask = @import("./archetype.zig").ArchetypeMask;
const Archetype = @import("./archetype.zig").Archetype;
const ArchetypeEdge = @import("./archetype.zig").ArchetypeEdge;

const DEFAULT_ARCHETYPE_STORAGE_CAPACITY = 1000;

pub const ArchetypeStorage = struct {
    const Self = @This();
    const ArchetypeStorageOptions = struct { capacity: ?u32 };

    allocator: std.mem.Allocator,
    all: std.ArrayList(Archetype),

    capacity: u32 = 0,

    pub fn init(options: ArchetypeStorageOptions, allocator: std.mem.Allocator) !Self {
        var capacity = options.capacity orelse DEFAULT_ARCHETYPE_STORAGE_CAPACITY;

        var all = try std.ArrayList(Archetype).initCapacity(allocator, capacity);

        var storage = Self{ .allocator = allocator, .all = all, .capacity = capacity };

        var root = try Archetype.build(.{}, allocator);

        storage.all.appendAssumeCapacity(root);

        return storage;
    }

    pub fn deinit(self: *Self) void {
        for (self.all.items) |*arch| {
            arch.deinit();
        }
        self.all.deinit();
    }

    pub fn getRoot(self: *Self) *Archetype {
        return &self.all.items[0];
    }

    pub fn derive(self: *Self, archetype: *Archetype, component_id: ComponentId) *Archetype {
        var derived = archetype.derive(component_id, self.allocator) catch unreachable;
        var new_archetype = self.register(&derived);

        new_archetype.edge.putAssumeCapacity(component_id, archetype);
        archetype.edge.putAssumeCapacity(component_id, new_archetype);

        return new_archetype;
    }

    pub fn register(
        self: *Self,
        archetype: *Archetype,
    ) *Archetype {
        self.all.appendAssumeCapacity(archetype.*);
        return &self.all.items[self.all.items.len - 1];
    }
};
