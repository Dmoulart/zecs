const std = @import("std");
const Component = @import("./component.zig").Component;
const Type = @import("./archetype.zig").Type;

var global_entity_counter: u128 = 0;

// pub fn World(comptime capacity: comptime_int) type {
//     return struct {
//         const Self = @This();
//         capacity: u128 = capacity,
//         entities: [capacity]u128 = undefined,
//         cursor: u128 = 0,

//         pub fn entity(self: *Self) u128 {
//             global_entity_counter += 1;
//             var created_entity = global_entity_counter;
//             self.cursor += 1;
//             self.entities[@as(usize, self.cursor)] = created_entity;
//             return created_entity;
//         }
//     };
// }

pub const World = struct {
    const Self = @This();
    capacity: u128,
    entities: [10000]u128 = undefined,
    cursor: usize,
    allocator: std.mem.Allocator,
    types: std.AutoHashMap(u128, Type),

    pub fn createEntity(self: *Self) u128 {
        global_entity_counter += 1;
        var created_entity = global_entity_counter;

        self.cursor += 1;
        self.entities[self.cursor] = created_entity;

        return created_entity;
    }

    pub fn attach(self: *Self, entity: u128, comptime component: type) void {
        _ = component;
        _ = entity;
        _ = self;
    }

    // pub fn create(alloc: std.mem.Allocator) !*Self {
    //     var world = try alloc.create(World);

    //     world.allocator = alloc;
    //     world.types = std.AutoHashMap(u128, Type).init(alloc);
    //     world.capacity = 0;
    //     world.cursor = 0;
    //     world.entities = undefined;

    //     return world;
    // }

    pub fn create(alloc: std.mem.Allocator) !*Self {
        var world = try alloc.create(World);

        world.allocator = alloc;
        world.types = std.AutoHashMap(u128, Type).init(alloc);
        world.capacity = 0;
        world.cursor = 0;
        world.entities = undefined;

        return world;
    }
};
