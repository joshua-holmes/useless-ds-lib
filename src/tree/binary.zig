const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const AllocatorError = Allocator.Error;

pub fn Node(T: type) type {
    return struct {
        value: T,
        count: u32 = 0,
        left: ?*Self = null,
        right: ?*Self = null,

        const Self = @This();
        fn create(allocator: Allocator, value: T) AllocatorError!*Self {
            const node = try allocator.create(Self);
            node.* = .{
                .value = value,
            };
            return node;
        }
        fn free(self: *Self, allocator: Allocator) void {
            if (self.left) |left| {
                left.free(allocator);
            }
            if (self.right) |right| {
                right.free(allocator);
            }
            allocator.destroy(self);
        }
        fn add(self: *Self, allocator: Allocator, value: T) AllocatorError!bool {
            if (value < self.value) {
                if (self.left) |left| {
                    return try left.add(allocator, value);
                }
                self.left = try Self.create(allocator, value);
                return true;
            } else if (value > self.value) {
                if (self.right) |right| {
                    return try right.add(allocator, value);
                }
                self.right = try Self.create(allocator, value);
                return true;
            }
            self.count += 1;
            return false;
        }
    };
}

