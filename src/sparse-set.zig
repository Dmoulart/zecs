const std = @import("std");
const expect = std.testing.expect;

const DEFAULT_SPARSE_SET_CAPACITY = 100;

pub fn SparseSet(comptime T: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        indices: []T = undefined,
        values: []T = undefined,
        count: T = 0,

        pub fn init(allocator: std.mem.Allocator) !Self {
            var indices = try allocator.alloc(T, DEFAULT_SPARSE_SET_CAPACITY);
            errdefer allocator.free(indices);

            var values = try allocator.alloc(T, DEFAULT_SPARSE_SET_CAPACITY);
            errdefer allocator.free(values);

            return SparseSet(T){ .allocator = allocator, .indices = indices, .values = values, .count = 0 };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.indices);
            self.allocator.free(self.values);
        }

        pub fn add(self: *Self, value: T) void {
            self.values[self.count] = value;
            self.indices[value] = self.count;
            self.count += 1;
        }

        pub fn has(self: *Self, value: T) bool {
            var index = self.indices[value];
            return index < self.count and self.values[index] == value;
        }

        pub fn remove(self: *Self, value: T) bool {
            if (!self.has(value)) return false;

            self.count -= 1;

            var last = self.values[self.count];

            if (last == value) return true;

            var index = self.indices[value];
            self.values[index] = last;
            self.indices[last] = index;

            return true;
        }
    };
}

// test "Add to sparseset" {
//     var sset = SparseSet(u32){};
//     sset.add(1);
//     try expect(sset.has(1));
//     try expect(!sset.has(2));

//     sset.add(3);
//     try expect(sset.has(1));
//     try expect(sset.has(3));
//     try expect(!sset.has(2));

//     sset.add(5);
//     try expect(sset.has(1));
//     try expect(sset.has(3));
//     try expect(sset.has(5));
//     try expect(!sset.has(2));
// }

// test "Remove from sparseset" {
//     var sset = SparseSet(u32){};

//     sset.add(1);
//     try expect(sset.remove(1));
//     try expect(!sset.has(1));

//     sset.add(1);
//     sset.add(2);
//     sset.add(3);

//     try expect(sset.remove(2));
//     try expect(sset.remove(3));

//     try expect(sset.has(1));
//     try expect(!sset.has(2));
//     try expect(!sset.has(3));

//     sset.add(4);
//     sset.add(5);
//     sset.add(6);

//     try expect(sset.remove(4));

//     try expect(!sset.has(4));
//     try expect(sset.has(5));
//     try expect(sset.has(6));
// }

// // const std = @import("std");
// // const expect = std.testing.expect;

// // const DEFAULT_SPARSE_SET_CAPACITY = 10_000;

// // pub fn SparseSet(comptime T: type) type {
// //     return struct {
// //         const Self = @This();
// //         indices: std.ArrayList(T),
// //         values: std.ArrayList(T),
// //         count: T = 0,
// //         allocator: std.mem.Allocator,

// //         pub fn init(allocator: std.mem.Allocator) Self {
// //             var indices = std.ArrayList(T).init(allocator);
// //             _ = indices.ensureTotalCapacity(DEFAULT_SPARSE_SET_CAPACITY) catch null;
// //             var values = std.ArrayList(T).init(allocator);
// //             _ = values.ensureTotalCapacity(DEFAULT_SPARSE_SET_CAPACITY) catch null;
// //             return Self{ .allocator = allocator, .indices = indices, .values = values, .count = 0 };
// //         }

// //         pub fn deinit(self: *Self) void {
// //             self.indices.deinit();
// //             self.values.deinit();
// //         }

// //         pub fn add(self: *Self, value: T) void {
// //             _ = self.values.append(value) catch null;
// //             std.debug.print("count {}", .{self.count});
// //             _ = self.indices.insert(value, self.count) catch null;
// //             // self.values[self.count] = value;
// //             // self.indices[value] = self.count;
// //             self.count += 1;
// //         }

// //         pub fn has(self: *Self, value: T) bool {
// //             // var index = self.indices[value];
// //             var index = self.indices.items[value];
// //             return index < self.count and self.values.items[index] == value;
// //         }

// //         pub fn remove(self: *Self, value: T) bool {
// //             if (!self.has(value)) return false;

// //             self.count -= 1;

// //             var last = self.values.items[self.count];

// //             if (last == value) return true;

// //             var index = self.indices.items[value];
// //             self.values.items[index] = last;
// //             self.indices.items[last] = index;

// //             return true;
// //         }
// //     };
// // }

// // test "Add to sparseset" {
// //     var sset = SparseSet(u32){};
// //     sset.add(1);
// //     try expect(sset.has(1));
// //     try expect(!sset.has(2));

// //     sset.add(3);
// //     try expect(sset.has(1));
// //     try expect(sset.has(3));
// //     try expect(!sset.has(2));

// //     sset.add(5);
// //     try expect(sset.has(1));
// //     try expect(sset.has(3));
// //     try expect(sset.has(5));
// //     try expect(!sset.has(2));
// // }

// // test "Remove from sparseset" {
// //     var sset = SparseSet(u32){};

// //     sset.add(1);
// //     try expect(sset.remove(1));
// //     try expect(!sset.has(1));

// //     sset.add(1);
// //     sset.add(2);
// //     sset.add(3);

// //     try expect(sset.remove(2));
// //     try expect(sset.remove(3));

// //     try expect(sset.has(1));
// //     try expect(!sset.has(2));
// //     try expect(!sset.has(3));

// //     sset.add(4);
// //     sset.add(5);
// //     sset.add(6);

// //     try expect(sset.remove(4));

// //     try expect(!sset.has(4));
// //     try expect(sset.has(5));
// //     try expect(sset.has(6));
// // }
