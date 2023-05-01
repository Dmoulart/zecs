const std = @import("std");
const Component = @import("./component.zig").Component;
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

        var all = std.ArrayList(Archetype).init(allocator);
        try all.ensureTotalCapacity(capacity);

        var storage = Self{ .allocator = allocator, .all = all, .capacity = capacity };

        var root = try Archetype.build(.{}, allocator);
        try storage.all.append(root);

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
};
