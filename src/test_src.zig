const std = @import("std");
const Io = std.Io;

pub const bing: []const u8 = "bong";

pub const baz = struct {
    bar: []const u8 = "baz",
};

/// Function to add two integers together
/// This doesn't show up
pub fn add(
    /// The first number to add
    foo: ?u32,
    /// The second number to add
    bar: u32,
) ?u32 {
    if (foo == null) {
        return null;
    }
    return foo + bar;
}

test add {
    try std.testing.expectEqual(10, add(3, 7));
}

/// Function to subtract two integers
pub fn sub(
    /// The first number to sub
    foo: u32,
    /// The second number to sub
    bar: u32,
) u32 {
    return foo - bar;
}

test sub {
    try std.testing.expectEqual(-3, sub(3, 6));
    try std.testing.expectEqual(-6, sub(3, 9));
}
