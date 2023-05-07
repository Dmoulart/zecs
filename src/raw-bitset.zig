const std = @import("std");
const expect = @import("std").testing.expect;

const RAW_BITSET_CAPACITY: RawBitset.Type = 40;
const RAW_BITSET_WIDTH: RawBitset.Type = 64;

pub const RawBitset = struct {
    const Self = @This();
    const Type = usize;
    const Shift = std.math.Log2Int(Type);
    // const t = std.bit_set.DynamicBitSet
    size: Type,

    count: Type = 0,

    data: [RAW_BITSET_CAPACITY]Type,

    const RawBitsetOptions = struct {
        // allocator: std.mem.Allocator,
        // size: Type,
    };

    pub fn init(options: RawBitsetOptions) Self {
        _ = options;
        var data: [RAW_BITSET_CAPACITY]Type = undefined;
        std.mem.set(Type, data[0..], 0);

        return RawBitset{
            .size = 0,
            .data = data,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        // Delete later
    }

    pub fn set(
        self: *Self,
        bit: Type,
    ) void {
        var index = maskIndex(bit);

        if (index > self.count) self.count = index;

        self.data[maskIndex(bit)] |= maskBit(bit);
    }

    pub fn unset(
        self: *Self,
        bit: Type,
    ) void {
        // var index = maskIndex(bit);

        // if (index == self.count) return false;

        self.data[maskIndex(bit)] ^= maskBit(bit);
    }

    pub fn has(self: *Self, bit: Type) bool {
        var index = maskIndex(bit);

        if (index > self.count) return false;

        return self.data[index] & maskBit(bit) != 0;
    }

    pub fn contains(self: *Self, other: *Self) bool {
        if (self.count < other.count) return false;

        var min_size = @min(self.count, other.count);
        var i: usize = 0;

        while (i <= min_size) : (i += 1) {
            var mask = self.data[i];
            var otherMask = other.data[i];

            if ((mask & otherMask) != otherMask) {
                return false;
            }
        }

        return true;
    }

    pub fn intersects(self: *Self, other: *Self) bool {
        var min_size = @min(self.count, other.count);
        var i: usize = 0;
        while (i <= min_size) : (i += 1) {
            var mask = self.data[i];
            var otherMask = other.data[i];
            if ((mask & otherMask) > 0) {
                return true;
            }
        }

        return false;
    }

    pub fn clone(self: *Self) Self {
        var data: [RAW_BITSET_CAPACITY]Type = undefined;
        std.mem.copy(Type, data[0..], &self.data);

        return Self{
            .size = data.len,
            .data = data,
        };
    }
};

fn maskBit(index: usize) RawBitset.Type {
    return @as(RawBitset.Type, 1) << @truncate(RawBitset.Shift, index);
}

fn maskIndex(index: usize) usize {
    return index >> @bitSizeOf(RawBitset.Shift);
}

test "Can set bit" {
    var set = RawBitset.init(.{});
    set.set(1);

    try expect(!set.has(0));
    try expect(set.has(1));
    try expect(!set.has(2));
}
test "Can unset bit" {
    var set = RawBitset.init(.{});

    set.set(1);
    set.set(2);
    try expect(set.has(1));
    try expect(set.has(2));

    set.unset(1);
    try expect(!set.has(1));
    try expect(set.has(2));
}
test "Can test one bitset contains the other" {
    var a = RawBitset.init(.{});

    var b = RawBitset.init(.{});

    a.set(1);
    a.set(2);
    a.set(3);

    b.set(1);
    b.set(2);

    try expect(a.contains(&b));
    try expect(!b.contains(&a));
}
test "Can test one bitset intersects the other" {
    var a = RawBitset.init(.{});

    var b = RawBitset.init(.{});

    var c = RawBitset.init(.{});

    a.set(1);
    a.set(2);

    b.set(3);

    c.set(2);

    try expect(!a.intersects(&b));

    try expect(a.intersects(&c));
    try expect(c.intersects(&a));

    try expect(!b.intersects(&c));
}
test "Can clone itself" {
    var a = RawBitset.init(.{});

    a.set(1);
    a.set(2);

    var b = a.clone();

    try expect(b.has(1));
    try expect(b.has(2));
    try expect(!b.has(3));
}
