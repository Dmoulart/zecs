const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;

const DEFAULT_SPARSE_MAP_CAPACITY: u64 = 10_000;

pub fn SparseMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        indices: []K = undefined,
        keys: []K = undefined,
        values: []V = undefined,
        count: K = 0,
        capacity: u64,

        pub const SparseMapOptions = struct { allocator: std.mem.Allocator, capacity: ?u64 };

        pub fn init(options: SparseMapOptions) Self {
            var allocator = options.allocator;
            var capacity = (options.capacity orelse DEFAULT_SPARSE_MAP_CAPACITY) + 1;
            // err handling anyone ?
            var indices = allocator.alloc(K, capacity) catch unreachable;
            errdefer allocator.free(indices);

            var keys = allocator.alloc(K, capacity) catch unreachable;
            errdefer allocator.free(keys);

            var values = allocator.alloc(V, capacity) catch unreachable;
            errdefer allocator.free(values);

            return SparseMap(K, V){
                .allocator = allocator,
                .indices = indices,
                .values = values,
                .keys = keys,
                .capacity = capacity,
                .count = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.indices);
            self.allocator.free(self.keys);
            self.allocator.free(self.values);
        }

        pub fn set(self: *Self, key: K, value: V) void {
            if (!self.has(key)) {
                if (self.count == self.capacity or key >= self.indices.len) {
                    self.grow();
                }
                self.keys[self.count] = key;
                self.indices[key] = self.count;
                self.values[self.count] = value;

                self.count += 1;
            } else {
                var index = self.indices[key];
                self.values[index] = value;
            }
        }

        pub fn has(self: *Self, key: K) bool {
            if (key >= self.indices.len) return false;

            var index = self.indices[key];
            // We could remove this index check by zeroing all the indices array ?
            return index < self.count and self.keys[index] == key;
        }

        pub fn get(self: *Self, key: K) ?V {
            var index = self.indices[key];

            return if (index < self.count) self.values[index] else null;
        }

        pub fn getUnsafe(self: *Self, key: K) V {
            return self.values[self.indices[key]];
        }

        pub fn delete(self: *Self, key: K) void {
            if (!self.has(key)) return;

            self.count -= 1;

            var last_value = self.values[self.count];
            var last_key = self.keys[self.count];

            if (last_key == key) return;

            var index = self.indices[key];
            self.values[index] = last_value;
            self.indices[last_key] = index;
        }

        fn grow(self: *Self) void {
            self.capacity = self.getGrowFactor();

            self.indices = self.allocator.realloc(self.indices, self.capacity) catch unreachable;
            self.values = self.allocator.realloc(self.values, self.capacity) catch unreachable;
            self.keys = self.allocator.realloc(self.keys, self.capacity) catch unreachable;
        }

        fn getGrowFactor(self: *Self) u64 {
            return self.capacity * 2;
        }
    };
}
