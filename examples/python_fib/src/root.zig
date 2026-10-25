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
    foo: i32,
    /// The second number to add
    bar: i32,
) i32 {
    return foo + bar;
}

test add {
    try std.testing.expectEqual(10, add(3, 7));
}

/// Function to subtract two integers
pub fn sub(
    /// The first number to sub
    foo: i16,
    /// The second number to sub
    bar: i16,
) i16 {
    return foo - bar;
}

// Private function that should not be included in final binary as importable
fn private(foo: i32) i32 {
    return foo + 1;
}

// Public function that uses private function that should work AND be importable
pub fn uses_private(bar: i32) i32 {
    return private(bar) + 1;
}

pub fn echo(string_to_echo: []u8) []u8 {
    return string_to_echo;
}

// test sub {
//     try std.testing.expectEqual(-3, sub(3, 6));
//     try std.testing.expectEqual(-6, sub(3, 9));
// }

// TODO: Also probably can't return an error? I think `extern` blocks this already
// pub fn no_return(a: i32) void {
//     _ = a;
// }

// TODO: Need to look at how to handle `init`, like for `main` functions. How do we properly handle IO here?
// fn printSomething(thing_to_print: []const u8) !void {
//     const gpa = std.heap.smp_allocator;
//
//     var threaded: std.Io.Threaded = .init(gpa, .{
//         // .argv0 = .empty,
//         // .environ = .empty,
//     });
//
//     defer threaded.deinit();
//
//     const io = threaded.io();
//
//     var buffer: [2000]u8 = undefined;
//     var writer = Io.File.stdout().writer(io, &buffer);
//     const w = &writer.interface;
//
//     defer w.flush() catch {};
//
//     try w.print("{s}\n", .{thing_to_print});
// }
//
// test printSomething {
//     try printSomething("thing to print");
// }
