const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const AllocatorError = Allocator.Error;

pub fn Node(T: type) type {
    return struct {
        value: T,
        count: u32 = 1,
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
        fn free_recursively(self: *Self, allocator: Allocator) void {
            if (self.left) |left| {
                left.free_recursively(allocator);
            }
            if (self.right) |right| {
                right.free_recursively(allocator);
            }
            allocator.destroy(self);
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
        fn add_to_node(self: *Self, node: *Node(T), value: T) AllocatorError!bool {
            if (value < node.value) {
                if (node.left) |left| {
                    return try self.add_to_node(left, value);
                }
                node.left = try Node(T).create(self.allocator, value);
                return true;
            } else if (value > node.value) {
                if (node.right) |right| {
                    return try self.add_to_node(right, value);
                }
                node.right = try Node(T).create(self.allocator, value);
                return true;
            }
            node.count += 1;
            return false;
        }
        fn add(self: *Self, value: T) AllocatorError!void {
            if (self.root) |root| {
                const created_unique = try self.add_to_node(root, value);
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
                root.free_recursively(self.allocator);
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
    print("GET {any}\n", .{tree.get(5)});
}
test "b_tree_add_new_node_value" {
    const testing = std.testing;
    const test_alloc = std.testing.allocator;
    var tree = BinaryTree(i32){ .allocator = test_alloc };
    defer tree.free_nodes();
    try tree.add(19);
    try tree.add(190);
    try tree.add(1);
    try testing.expectEqual(19, tree.root.?.value);
    try testing.expectEqual(190, tree.root.?.right.?.value);
    try testing.expectEqual(1, tree.root.?.left.?.value);
}
test "b_tree_add_same_value" {
    const testing = std.testing;
    const test_alloc = std.testing.allocator;
    var tree = BinaryTree(i32){ .allocator = test_alloc };
    defer tree.free_nodes();
    try tree.add(19);
    try tree.add(19);
    try tree.add(190);

    try testing.expectEqual(2, tree.root.?.count);
    try testing.expectEqual(1, tree.root.?.right.?.count);
}
test "b_tree_get" {
    const testing = std.testing;
    const test_alloc = std.testing.allocator;
    var tree = BinaryTree(i32){ .allocator = test_alloc };
    defer tree.free_nodes();
    try tree.add(19);
    try tree.add(190);
    try tree.add(1);

    try testing.expect(tree.get(19) != null);
    try testing.expect(tree.get(190) != null);
    try testing.expect(tree.get(1) != null);
    try testing.expect(tree.get(10) == null);
}
