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
        fn print_nodes(self: *Self, level: u32) void {
            if (self.left) |left| {
                left.print_nodes(level + 1);
            } else print("\n", .{});
            for (0..(level * 8)) |_| print(" ", .{});
            print("{d}\n", .{self.value});
            if (self.right) |right| {
                right.print_nodes(level + 1);
            } else print("\n", .{});
        }
    };
}

pub fn BinaryTree(T: type) type {
    return struct {
        root: ?*Node(T) = null,
        unique_node_count: u32 = 0,
        allocator: Allocator,

        const Self = @This();
        fn add(self: *Self, value: T) AllocatorError!void {
            if (self.root) |root| {
                const created_unique = try root.add(self.allocator, value);
                if (created_unique) {
                    self.unique_node_count += 1;
                }
            } else {
                self.root = try Node(T).create(self.allocator, value);
                self.unique_node_count += 1;
            }
        }

        fn free_nodes(self: *Self) void {
            if (self.root) |root| {
                root.free(self.allocator);
            }
        }

        fn print_tree(self: *Self) void {
            if (self.root == null) {
                print("BinaryTree is empty, nothing to print\n", .{});
            }
            self.root.?.print_nodes(0);
        }
    };
}

test "binary_tree" {
    const test_alloc = std.testing.allocator;
    var tree = BinaryTree(i32){ .allocator = test_alloc };
    defer tree.free_nodes();
    try tree.add(8);
    try tree.add(4);
    try tree.add(40);
    // try tree.add(3);
    try tree.add(5);
    try tree.add(39);
    try tree.add(41);
    // try tree.add(400);
    // try tree.add(401);
    // try tree.add(402);
    // try tree.add(403);
    // try tree.add(404);
    tree.print_tree();
}
