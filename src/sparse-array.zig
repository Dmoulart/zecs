const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;

const DEFAULT_SPARSE_ARRAY_CAPACITY: u64 = 10_000;

pub fn SparseArray(comptime I: type, comptime V: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        values: []?V = undefined,

        pub const SparseArrayOptions = struct { allocator: std.mem.Allocator, capacity: ?u64 };

        pub fn init(options: SparseArrayOptions) Self {
            const allocator = options.allocator;
            const capacity = (options.capacity orelse DEFAULT_SPARSE_ARRAY_CAPACITY) + 1;
            // err handling anyone ?
            var values = allocator.alloc(?V, capacity) catch unreachable;
            // nullify all this crap
            std.mem.set(?V, values, null);

            errdefer allocator.free(values);

            return SparseArray(I, V){
                .allocator = allocator,
                .values = values,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.values);
        }

        pub fn set(self: *Self, index: I, value: V) void {
            if (index >= self.values.len - 1) {
                self.grow();
            }
            self.values[index] = value;
        }

        pub fn has(self: *Self, index: I) bool {
            if (index >= self.values.len) return false;

            return self.values[index] != null;
        }

        pub fn getUnsafe(self: *Self, index: I) ?V {
            return self.values[index];
        }

        pub fn get(self: *Self, index: I) ?V {
            return self.values[index];
        }

        pub fn delete(self: *Self, index: I) void {
            if (!self.has(index)) return;

            self.values[index] = null;
        }

        pub fn deleteUnsafe(self: *Self, index: I) void {
            self.values[index] = null;
        }

        fn grow(self: *Self) void {
            self.values = self.allocator.realloc(self.values, self.getGrowFactor()) catch unreachable;
        }

        fn getGrowFactor(self: *Self) u64 {
            return self.values.len * 2;
        }
    };
}
