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

        fn get_from_node(node: *Node(T), value: T) ?*Node(T) {
            if (value < node.value) {
                if (node.left) |left| {
                    return get_from_node(left, value);
                }
            } else if (value > node.value) {
                if (node.right) |right| {
                    return get_from_node(right, value);
                }
            } else return node;
            return null;
        }
        fn get(self: *Self, value: T) ?*Node(T) {
            if (self.root) |root| {
                return get_from_node(root, value);
            } else return null;
        }

        fn remove(self: *Self, value: T) bool {
            var p_node: ?*Node(T) = null;
            var node = self.root;
            var went_left = false;
            while (node) |n| {
                if (n.value != value) {
                    p_node = n;
                    node = if (value < n.value) n.left else n.right;
                    went_left = value < n.value;
                    continue;
                }
                if (n.count > 1) {
                    n.count -= 1;
                    return true;
                }
                if ((n.left != null and n.right == null) or (n.left == null and n.right != null)) {
                    // single child
                    const n_node = if (n.left != null) n.left else n.right;
                    if (p_node) |p| {
                        if (went_left) p.left = n_node else p.right = n_node;
                    } else self.root = n_node;
                } else if (n.left == null and n.right == null) {
                    // no children
                    if (p_node) |p| {
                        if (went_left) p.left = null else p.right = null;
                    } else self.root = null;
                } else {
                    // two children
                    var l_node_p = n;
                    var l_node = n.right.?;
                    find_left: while (true) {
                        if (l_node.left) |l| {
                            l_node_p = l_node;
                            l_node = l;
                        } else break :find_left;
                    }
                    l_node_p.left = l_node.right;
                    if (p_node) |p| {
                        if (went_left) p.left = l_node else p.right = l_node;
                    } else self.root = l_node;
                    l_node.right = n.right;
                    l_node.left = n.left;
                }
                self.allocator.destroy(n);
                return true;
            }
            return false;
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

fn create_test_tree() AllocatorError!BinaryTree(i32) {
    //            190
    //           /   \
    // root -> 19   9 20
    //           \ /
    //            1
    const test_alloc = std.testing.allocator;
    var tree = BinaryTree(i32){ .allocator = test_alloc };
    tree.root = try Node(i32).create(test_alloc, 19);
    tree.root.?.right = try Node(i32).create(test_alloc, 190);
    tree.root.?.right.?.left = try Node(i32).create(test_alloc, 20);
    tree.root.?.left = try Node(i32).create(test_alloc, 1);
    tree.root.?.left.?.right = try Node(i32).create(test_alloc, 9);
    return tree;
}

test "add_node_new_value" {
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
test "add_node_same_value" {
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
test "get_node" {
    const testing = std.testing;
    var tree = try create_test_tree();
    defer tree.free_nodes();

    try testing.expectEqual(19, tree.get(19).?.value);
    try testing.expectEqual(190, tree.get(190).?.value);
    try testing.expectEqual(1, tree.get(1).?.value);
    try testing.expectEqual(null, tree.get(10));
}
test "remove_node" {
    const testing = std.testing;
    var tree = try create_test_tree();
    defer tree.free_nodes();

    try testing.expect(!tree.remove(10));
    try testing.expect(tree.remove(19));
    try testing.expectEqual(20, tree.root.?.value);
    try testing.expect(tree.remove(190));
    try testing.expectEqual(null, tree.root.?.right);
}
