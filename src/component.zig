const std = @import("std");
var global_component_counter: u64 = 0;
pub fn Component(comptime T: type) type {
    return struct { id: u64 = 0, storage: std.MultiArrayList(T) = std.MultiArrayList(T){} };
}
