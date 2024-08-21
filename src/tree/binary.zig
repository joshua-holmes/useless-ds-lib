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

        fn print_tree(self: *Self) AllocatorError!void {
            if (self.root == null) {
                print("BinaryTree is empty, nothing to print\n", .{});
            }
            const DLLTuple = struct { *Node(T), u32, i32 };
            const DLL = std.DoublyLinkedList(DLLTuple);
            var queue = DLL{};
            const root_q_node = try self.allocator.create(DLL.Node);
            root_q_node.* = .{ .data = .{ self.root.?, 1, 0 } };
            queue.append(root_q_node);
            var last_level: u32 = 0;
            var last_row: i32 = 0;
            print("BinaryTree - {d} total nodes:", .{self.unique_node_count});
            while (queue.popFirst()) |q_node| {
                const tree_node = q_node.data.@"0";
                const level = q_node.data.@"1";
                const row = q_node.data.@"2";
                if (level > last_level) {
                    print("\n", .{});
                    last_level = level;
                    last_row = -1;
                }
                const row_diff: u32 = @intCast(row - last_row);
                const space_count = row_diff + (self.unique_node_count * 2) / level;
                var digits: u8 = 0;
                var num = tree_node.value;
                while (num != 0) {
                    num = @divTrunc(num, 10);
                    digits += 1;
                }
                for (0..(space_count - (digits / 2))) |_| print(" ", .{});
                print("{d}", .{tree_node.value});
                for (0..space_count) |_| print(" ", .{});
                if (tree_node.left) |left| {
                    const new_q_node = try self.allocator.create(DLL.Node);
                    new_q_node.* = .{ .data = .{ left, level + 1, row * 2 } };
                    queue.append(new_q_node);
                }
                if (tree_node.right) |right| {
                    const new_q_node = try self.allocator.create(DLL.Node);
                    new_q_node.* = .{ .data = .{ right, level + 1, (row * 2) + 1 } };
                    queue.append(new_q_node);
                }
                self.allocator.destroy(q_node);
                last_row = row;
            }
            print("\n", .{});
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
    try tree.add(400);
    try tree.add(401);
    try tree.add(402);
    try tree.add(403);
    try tree.add(404);
    try tree.print_tree();
    print("{any}", .{tree});
}
