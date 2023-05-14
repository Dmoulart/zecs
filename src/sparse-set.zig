const std = @import("std");
const expect = std.testing.expect;

const DEFAULT_SPARSE_SET_CAPACITY: u64 = 10_000;

pub fn SparseSet(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        indices: []T = undefined,

        values: []T = undefined,

        count: T = 0,

        capacity: u64,

        pub const SparseSetOptions = struct {
            allocator: std.mem.Allocator,
            capacity: ?u64,
        };

        pub fn init(options: SparseSetOptions) Self {
            var capacity = (options.capacity orelse DEFAULT_SPARSE_SET_CAPACITY);
            // var capacity = (options.capacity orelse DEFAULT_SPARSE_SET_CAPACITY) + 1;
            // holy molly err handling
            var indices = options.allocator.alloc(T, capacity) catch unreachable;
            errdefer options.allocator.free(indices);

            var values = options.allocator.alloc(T, capacity) catch unreachable;
            errdefer options.allocator.free(values);

            return SparseSet(T){
                .allocator = options.allocator,
                .indices = indices,
                .values = values,
                .count = 0,
                .capacity = capacity,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.indices);
            self.allocator.free(self.values);
        }

        pub fn add(self: *Self, value: T) void {
            if (self.count == self.capacity or value == self.capacity) {
                self.grow();
            }
            self.values[self.count] = value;
            self.indices[value] = self.count;
            self.count += 1;
        }

        pub fn has(self: *Self, value: T) bool {
            var index = self.indices[value];
            return index < self.count and self.values[index] == value;
        }

        pub fn remove(self: *Self, value: T) void {
            if (!self.has(value)) return;

            self.count -= 1;

            var last = self.values[self.count];

            if (last == value) return;

            var index = self.indices[value];
            self.values[index] = last;
            self.indices[last] = index;
        }

        pub fn removeUnsafe(self: *Self, value: T) void {
            self.count -= 1;

            var last = self.values[self.count];

            if (last == value) return;

            var index = self.indices[value];
            self.values[index] = last;
            self.indices[last] = index;
        }

        pub fn toSlice(self: *Self) []T {
            return self.values[0..self.count];
        }

        fn grow(self: *Self) void {
            self.capacity = self.getGrowFactor();

            self.indices = self.allocator.realloc(self.indices, self.capacity) catch unreachable;
            self.values = self.allocator.realloc(self.values, self.capacity) catch unreachable;
        }

        fn getGrowFactor(self: *Self) u64 {
            return self.capacity * 2;
        }
    };
}

test "Add to sparseset" {
    var sset = SparseSet(u32).init(.{
        .allocator = std.testing.allocator,
        .capacity = 10,
    });
    defer sset.deinit();

    sset.add(1);
    try expect(sset.has(1));
    try expect(!sset.has(2));

    sset.add(3);
    try expect(sset.has(1));
    try expect(sset.has(3));
    try expect(!sset.has(2));

    sset.add(5);
    try expect(sset.has(1));
    try expect(sset.has(3));
    try expect(sset.has(5));
    try expect(!sset.has(2));
}

test "Remove from sparseset" {
    var sset = SparseSet(u32).init(.{
        .allocator = std.testing.allocator,
        .capacity = 10,
    });
    defer sset.deinit();

    sset.add(1);
    sset.remove(1);
    try expect(!sset.has(1));

    sset.add(1);
    sset.add(2);
    sset.add(3);

    sset.remove(2);
    sset.remove(3);

    try expect(sset.has(1));
    try expect(!sset.has(2));
    try expect(!sset.has(3));

    sset.add(4);
    sset.add(5);
    sset.add(6);

    sset.remove(4);

    try expect(!sset.has(4));
    try expect(sset.has(5));
    try expect(sset.has(6));
}
