const std = @import("std");
var global_component_counter: u64 = 1;

pub const ComponentId = u64;

pub fn Component(comptime T: type) type {
    return struct { id: u64, storage: std.MultiArrayList(T) = std.MultiArrayList(T){} };
}

pub fn defineComponent(comptime T: type) Component(T) {
    global_component_counter += 1;
    return Component(T){ .id = global_component_counter };
}
