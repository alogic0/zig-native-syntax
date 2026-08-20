//! A representative complete Zig source file.

const std = @import("std");

pub const Point = struct {
    /// Horizontal coordinate.
    x: f32,
    y: f32,

    pub fn length(self: Point) f32 {
        // Exercise calls, field access, builtins, and operators.
        return @sqrt(self.x * self.x + self.y * self.y);
    }
};

test "point length" {
    const message =
        \\first <line>
        \\second & line
    ;
    const point = Point{ .x = 3, .y = 4 };
    try std.testing.expect(point.length() == 5);
    _ = message;
}
