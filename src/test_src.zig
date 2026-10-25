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
    foo: u32,
    /// The second number to add
    bar: u32,
) u32 {
    // if (foo == null) {
    //     return null;
    // }
    return foo + bar;
}

test add {
    try std.testing.expectEqual(10, add(3, 7));
}

/// Function to subtract two integers
pub fn sub(
    /// The first number to sub
    foo: i32,
    /// The second number to sub
    bar: i32,
) i32 {
    return foo - bar;
}

test sub {
    try std.testing.expectEqual(-3, sub(3, 6));
    try std.testing.expectEqual(-6, sub(3, 9));
}

// Private function that should not be included in final binary as importable
fn private(foo: i32) i32 {
    return foo + 1;
}

// Public function that uses private function that should work AND be importable
pub fn uses_private(bar: i32) i32 {
    return private(bar) + 1;
}

pub fn echo(string_to_echo: [:0]u8) [:0]u8 {
    return string_to_echo;
}
