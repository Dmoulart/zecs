const std = @import("std");
const expect = std.testing.expect;
const Component = @import("./component.zig").Component;
const World = @import("./world.zig").World;

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var world = try World.create(arena.child_allocator);
    const Position = Component(struct { x: f64 = 0, y: f64 = 0 });
    var ent = world.createEntity();
    world.attach(ent, Position);
    std.debug.print("ent {}", .{ent});
}
