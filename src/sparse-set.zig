const std = @import("std");
const expect = std.testing.expect;

const DEFAULT_SPARSE_SET_CAPACITY = 10_000;

pub fn SparseSet(comptime T: type) type {
    return struct {
        const Self = @This();
        indices: [DEFAULT_SPARSE_SET_CAPACITY]T = undefined,
        values: [DEFAULT_SPARSE_SET_CAPACITY]T = undefined,
        count: T = 0,

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

test "Add to sparseset" {
    var sset = SparseSet(u32){};
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
    var sset = SparseSet(u32){};

    sset.add(1);
    try expect(sset.remove(1));
    try expect(!sset.has(1));

    sset.add(1);
    sset.add(2);
    sset.add(3);

    try expect(sset.remove(2));
    try expect(sset.remove(3));

    try expect(sset.has(1));
    try expect(!sset.has(2));
    try expect(!sset.has(3));

    sset.add(4);
    sset.add(5);
    sset.add(6);

    try expect(sset.remove(4));

    try expect(!sset.has(4));
    try expect(sset.has(5));
    try expect(sset.has(6));
}
