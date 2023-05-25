const std = @import("std");
const expect = @import("std").testing.expect;

const RAW_BITSET_CAPACITY: FixedSizeBitset.IntType = 40;
const RAW_BITSET_WIDTH: FixedSizeBitset.IntType = 64;

//
// Todo : rename size and count, add capacity in options, (make this comptime ?)
//
pub const FixedSizeBitset = struct {
    const Self = @This();
    const IntType = usize;
    const Shift = std.math.Log2Int(IntType);

    count: IntType = 0,

    data: [RAW_BITSET_CAPACITY]IntType,

    const FixedSizeBitsetOptions = struct {};

    pub fn init(options: FixedSizeBitsetOptions) Self {
        _ = options;
        var data: [RAW_BITSET_CAPACITY]IntType = undefined;

        std.mem.set(IntType, data[0..], 0);

        return FixedSizeBitset{
            .data = data,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        // Deletion ?
    }

    pub fn set(
        self: *Self,
        bit: IntType,
    ) void {
        var index = maskIndex(bit);

        if (index > self.count) self.count = index;

        self.data[index] |= maskBit(bit);
    }

    pub fn unset(
        self: *Self,
        bit: IntType,
    ) void {
        var index = maskIndex(bit);

        if (index > self.count) return;

        self.data[index] ^= maskBit(bit);

        if (self.data[index] == 0) {
            var highest_index: usize = 0;
            // must shrink
            for (self.data[0..]) |*mask, i| {
                if (mask.* == 0) {
                    break;
                } else {
                    highest_index = i;
                }
            }
            self.count = highest_index;
        }
    }

    pub fn has(self: *Self, bit: IntType) bool {
        var index = maskIndex(bit);

        if (index > self.count) return false;

        return self.data[index] & maskBit(bit) != 0;
    }

    pub fn contains(self: *Self, other: *Self) bool {
        if (self.count < other.count) return false;

        var min_count = @min(self.count, other.count);
        var i: usize = 0;

        while (i <= min_count) : (i += 1) {
            var mask = self.data[i];
            var otherMask = other.data[i];

            if ((mask & otherMask) != otherMask) {
                return false;
            }
        }

        return true;
    }

    pub fn intersects(self: *Self, other: *Self) bool {
        var min_count = @min(self.count, other.count);
        var i: usize = 0;
        while (i <= min_count) : (i += 1) {
            var mask = self.data[i];
            var otherMask = other.data[i];
            if ((mask & otherMask) > 0) {
                return true;
            }
        }

        return false;
    }

    pub fn clone(self: *Self) Self {
        var data: [RAW_BITSET_CAPACITY]IntType = undefined;
        std.mem.copy(IntType, data[0..], &self.data);

        return Self{
            .data = data,
        };
    }
};

fn maskBit(index: usize) FixedSizeBitset.IntType {
    return @as(FixedSizeBitset.IntType, 1) << @truncate(FixedSizeBitset.Shift, index);
}

fn maskIndex(index: usize) usize {
    return index >> @bitSizeOf(FixedSizeBitset.Shift);
}

test "Can set bit" {
    var set = FixedSizeBitset.init(.{});
    set.set(1);

    try expect(!set.has(0));
    try expect(set.has(1));
    try expect(!set.has(2));
}
test "Can unset bit" {
    var set = FixedSizeBitset.init(.{});

    set.set(1);
    set.set(2);
    try expect(set.has(1));
    try expect(set.has(2));

    set.unset(1);
    try expect(!set.has(1));
    try expect(set.has(2));
}
test "Can test one bitset contains the other" {
    var a = FixedSizeBitset.init(.{});

    var b = FixedSizeBitset.init(.{});

    a.set(1);
    a.set(2);
    a.set(3);

    b.set(1);
    b.set(2);

    try expect(a.contains(&b));
    try expect(!b.contains(&a));
}
test "Can test one bitset intersects the other" {
    var a = FixedSizeBitset.init(.{});

    var b = FixedSizeBitset.init(.{});

    var c = FixedSizeBitset.init(.{});

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
    var a = FixedSizeBitset.init(.{});

    a.set(1);
    a.set(2);

    var b = a.clone();

    try expect(b.has(1));
    try expect(b.has(2));
    try expect(!b.has(3));
}

test "Can shrink" {
    var a = FixedSizeBitset.init(.{});

    a.set(1);
    a.set(2);

    var b = a.clone();

    b.set(1000);
    try expect(!a.contains(&b));

    b.unset(1000);
    try expect(a.contains(&b));
}
