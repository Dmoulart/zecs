const std = @import("std");
const print = @import("std").debug.print;
const Archetype = @import("./archetype.zig").Archetype;
const World = @import("./world.zig").World;
const Entity = @import("./world.zig").Entity;

fn numMasks(bit_length: usize) usize {
    return (bit_length + (@bitSizeOf(std.bit_set.DynamicBitSet.MaskInt) - 1)) / @bitSizeOf(std.bit_set.DynamicBitSet.MaskInt);
}
fn intersects(query: *std.bit_set.DynamicBitSet, other: *std.bit_set.DynamicBitSet) bool {
    std.debug.print("\n intersect ", .{});
    const num_masks = numMasks(query.unmanaged.bit_length);

    for (query.unmanaged.masks[0..num_masks]) |*mask, i| {
        std.debug.print("\n other arch mask has Position {}", .{other.isSet(2)});
        std.debug.print("\n other arch mask has Velocity {}", .{other.isSet(4)});
        std.debug.print("\n query mask has Position {}", .{query.isSet(2)});
        std.debug.print("\n query mask has Velocity {}", .{query.isSet(4)});

        if (mask.* & other.unmanaged.masks[i] != mask.*) {
            std.debug.print("\n Masks don't intersects ! ", .{});
            std.debug.print("\n query item {} vs arch item {} ", .{ mask.*, other.unmanaged.masks[i] });
            return false;
        } else {
            std.debug.print("\n Masks  intersects ! ", .{});
            std.debug.print("\n query item {} vs arch item {} ", .{ mask.*, other.unmanaged.masks[i] });
        }
    }
    std.debug.print("\n Masks  intersects", .{});
    return true;
}

pub const Query = struct {
    const Self = @This();

    mask: std.bit_set.DynamicBitSet,

    archetypes: std.ArrayList(*Archetype),

    pub fn each(self: *Self, function: fn (entity: Entity) void) void {
        for (self.archetypes) |arch| {
            for (arch.values) |entity| {
                function(entity);
            }
        }
    }

    pub fn deinit(self: *Self) void {
        self.archetypes.deinit();
    }

    fn execute(self: *Self, world: *World) void {
        for (world.archetypes.items) |*arch| {
            if (intersects(&self.mask, &arch.mask)) {
                _ = self.archetypes.append(arch) catch null;
            }
        }
    }
};

pub const QueryBuilder = struct {
    const Self = @This();

    mask: std.bit_set.DynamicBitSet,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !QueryBuilder {
        return QueryBuilder{
            .mask = try std.bit_set.DynamicBitSet.initEmpty(allocator, 150),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.mask.deinit();
    }

    pub fn with(self: *Self, component: anytype) *Self {
        std.debug.print("\nQuery with component id {}", .{component.id});
        self.mask.set(component.id);
        std.debug.print("\nQuery mask has component id {}", .{self.mask.isSet(component.id)});
        return self;
    }

    pub fn query(self: *Self, world: *World) !Query {
        var created_query = Query{ .mask = try self.mask.clone(world.allocator), .archetypes = std.ArrayList(*Archetype).init(world.allocator) };
        self.mask = try std.bit_set.DynamicBitSet.initEmpty(world.allocator, 500);
        std.debug.print("\nExecute created query", .{});
        std.debug.print("\nBefore execution : Query mask has Position component id {}", .{created_query.mask.isSet(2)});
        std.debug.print("\nBefore execution : Query mask has Velocity component id {}", .{created_query.mask.isSet(4)});
        created_query.execute(world);
        return created_query;
    }
};
