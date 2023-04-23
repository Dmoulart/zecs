const std = @import("std");

pub fn Component(comptime T: type) type {
    return struct { storage: std.MultiArrayList(T) = std.MultiArrayList(T){} };
}
