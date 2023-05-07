const std = @import("std");
var global_component_counter: u64 = 1;

pub const ComponentId = u64;

pub fn Component(comptime component_name: []const u8, comptime T: type) type {
    return struct {
        pub const name = component_name;
        id: ComponentId,
        storage: std.MultiArrayList(T) = std.MultiArrayList(T){},
    };
}

pub fn defineComponent(comptime T: type) Component(T) {
    global_component_counter += 1;
    return Component(T){ .id = global_component_counter };
}
