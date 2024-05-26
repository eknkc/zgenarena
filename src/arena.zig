///! `zgenarena` is a simple generational arena implementation.
///! It allows for creating, removing, and reusing elements in an arena.
///! It provides constant time insertion, lookup, and removal via indices that can be sized to fit the needs of the user.
const std = @import("std");

/// Index type for Arena that has a generation attached to it.
pub fn Index(comptime GenType: type, comptime IxType: type) type {
    const ixti = @typeInfo(IxType);
    const gnti = @typeInfo(GenType);

    comptime std.debug.assert(gnti == .Int and ixti == .Int);
    comptime std.debug.assert(gnti.Int.signedness == .unsigned and ixti.Int.signedness == .unsigned);
    comptime std.debug.assert(ixti.Int.bits < @typeInfo(usize).Int.bits);

    return struct {
        i: IxType,
        gen: GenType,
    };
}

fn Entry(comptime T: type, comptime GenType: type, comptime IxType: type) type {
    return union(enum) {
        free: struct {
            gen: GenType,
            next: ?IxType,
        },
        used: struct {
            gen: GenType,
            value: T,
        },
    };
}

/// Container that can have elements inserted into it and removed from it.
/// Indices use the `Index` type to keep track of the generation of the element.
/// When an element is removed, the generation of the index is incremented.
/// When an index is reused, the generation is incremented.
/// This allows for detecting when an index is stale.
/// `T` is the type of the elements in the arena.
/// `GenType` is the type of the generation counter. It must be an unsigned integer.
/// `IxType` is the type of the index. It must be an unsigned integer.
/// The type of `IxType` determines the max number of elements that can be stored in the arena.
/// The type of `GenType` determines the max number of times an index can be reused.
/// Using `u32` for `IxType` and `GenType` is a good default.
pub fn Arena(comptime T: type, comptime GenType: type, comptime IxType: type) type {
    return struct {
        const Self = @This();

        const SelfIndex = Index(GenType, IxType);
        const SelfEntry = Entry(T, GenType, IxType);

        entries: std.ArrayList(SelfEntry),
        first_free: ?IxType = null,
        len: IxType = 0,

        /// Create a new element in the arena and return the `Index` to it.
        pub fn create(self: *Self, val: T) !SelfIndex {
            if (self.first_free) |i| {
                const entry = self.entries.items[i];

                switch (entry) {
                    .free => {
                        const gen = entry.free.gen;

                        self.first_free = entry.free.next;
                        self.len += 1;

                        self.entries.items[i] = SelfEntry{ .used = .{ .gen = gen, .value = val } };

                        return SelfIndex{ .i = i, .gen = gen };
                    },
                    .used => unreachable,
                }
            }

            try self.entries.append(SelfEntry{ .used = .{ .gen = 0, .value = val } });
            self.len += 1;

            return SelfIndex{ .i = @intCast(self.entries.items.len - 1), .gen = 0 };
        }

        /// Attempt to get the element at the given index.
        /// Returns null if the index is out of bounds or the element has been removed.
        pub fn get(self: Self, i: SelfIndex) ?*T {
            if (i.i >= self.entries.items.len) {
                return null;
            }

            const entry = &self.entries.items[i.i];

            if (entry.* == .free) {
                return null;
            }

            return &entry.used.value;
        }

        /// Attempt to get the element at the given index.
        /// Returns null if the index is out of bounds or the element has been removed.
        /// This function will return the element by value.
        pub fn getConst(self: Self, i: SelfIndex) ?T {
            if (self.get(i)) |x| {
                return x.*;
            }

            return null;
        }

        /// Remove the element at the given index.
        /// If the index is out of bounds or the element has already been removed, this function does nothing.
        pub fn destroy(self: *Self, i: SelfIndex) void {
            if (i.i >= self.entries.items.len) {
                return;
            }

            const entry = self.entries.items[i.i];

            switch (entry) {
                .free => return,
                .used => {
                    if (entry.used.gen != i.gen) {
                        return;
                    }

                    self.entries.items[i.i] = SelfEntry{ .free = .{ .gen = i.gen + 1, .next = self.first_free } };
                    self.first_free = i.i;
                    self.len -= 1;
                },
            }
        }

        /// Deinitialize the arena.
        pub fn deinit(self: Self) void {
            self.entries.deinit();
        }

        /// Initialize the arena.
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .entries = std.ArrayList(SelfEntry).init(allocator),
            };
        }
    };
}

test "create arena" {
    var arena = Arena(i32, u32, u32).init(std.testing.allocator);
    defer arena.deinit();

    const ix1 = try arena.create(42);
    const ix2 = try arena.create(43);

    try std.testing.expect(arena.getConst(ix1) == 42);
    try std.testing.expect(arena.getConst(ix2) == 43);
}

test "destroy arena item" {
    var arena = Arena(i32, u32, u32).init(std.testing.allocator);
    defer arena.deinit();

    const ix = try arena.create(42);
    try std.testing.expect(arena.getConst(ix) == 42);
    arena.destroy(ix);
    try std.testing.expect(arena.getConst(ix) == null);
}

test "reuse arena index" {
    var arena = Arena(i32, u32, u32).init(std.testing.allocator);
    defer arena.deinit();

    const ix = try arena.create(42);
    arena.destroy(ix);

    const ix2 = try arena.create(43);

    try std.testing.expect(ix.i == ix2.i);
}

test "update generation on reuse" {
    var arena = Arena(i32, u32, u32).init(std.testing.allocator);
    defer arena.deinit();

    const ix = try arena.create(42);
    arena.destroy(ix);

    const ix2 = try arena.create(43);

    try std.testing.expect(ix.gen != ix2.gen);
}
