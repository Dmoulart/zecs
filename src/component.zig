const std = @import("std");
var global_component_counter: u64 = 1;

pub const ComponentId = u64;

pub fn Component(comptime component_name: []const u8, comptime T: type) type {
    return struct {
        const Self = @This();

        pub const name = component_name;

        pub const Schema = T;

        id: ComponentId,

        storage: ComponentStorage(Self) = ComponentStorage(Self){},

        ready: bool = false,

        pub fn ensureTotalCapacity(self: *Self, gpa: std.mem.Allocator, capacity: usize) !void {
            try self.storage.ensureTotalCapacity(gpa, capacity);
        }

        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            self.storage.deinit(gpa);
        }
    };
}

pub fn ComponentStorage(comptime component: anytype) type {
    return struct {
        const Self = @This();

        const Schema = component.Schema;

        data: std.MultiArrayList(component.Schema) = std.MultiArrayList(component.Schema){},

        pub fn ensureTotalCapacity(self: *Self, gpa: std.mem.Allocator, capacity: u32) !void {
            try self.data.ensureTotalCapacity(gpa, capacity);
        }

        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            self.data.deinit(gpa);
        }
    };
}
