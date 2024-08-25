const std = @import("std");
const print = std.debug.print;

pub const Cell = enum(u8) {
    start,
    end,
    wall,
};

const Point = struct {
    x: i32,
    y: i32,

    const Self = @This();
    fn pathagorean(self: Self, other_point: Point) f64 {
        const diff_x: f64 = if (self.x > other_point.x) self.x - other_point.x else other_point.x - self.x;
        const diff_y: f64 = if (self.y > other_point.y) self.y - other_point.y else other_point.y - self.y;
        return std.math.sqrt(diff_x ** 2 + diff_y ** 2);
    }

    fn add(self: Self, other_point: Point) Self {
        return Self{ .x = self.x + other_point.x, .y = self.y + other_point.y };
    }
};

const Result = struct {
    allocator: std.mem.Allocator,
    found_end: bool,
    path: std.ArrayList(Point),
};

const AstarError = error{
    OutOfBounds,
};

pub fn Astar(size: comptime_int) type {
    return struct {
        grid: [size][size]?Cell,
        len: comptime_int = size,
        start: Point,
        end: Point,
        const Self = @This();
        const neighbor_directions = [8]Point{
            Point{ .x = -1, .y = -1 },
            Point{ .x = 0, .y = -1 },
            Point{ .x = 1, .y = -1 },
            Point{ .x = -1, .y = 0 },
            Point{ .x = 1, .y = 0 },
            Point{ .x = -1, .y = 1 },
            Point{ .x = 0, .y = 1 },
            Point{ .x = 1, .y = 1 },
        };
        const Node = struct {
            g_score: f64,
            h_score: f64,
            pos: Point,
            parent: ?*Node,

            fn f_score(self: Node) f64 {
                return self.h_score + self.g_score;
            }

            fn _lessThan(context: void, a: *Node, b: *Node) std.math.Order {
                _ = context;
                if (a.f_score() == b.f_score()) {
                    return std.math.order(a.h_score, b.h_score);
                }
                return std.math.order(a.f_score(), b.f_score());
            }
        };

        fn new(start: Point, end: Point, walls: []const Point) Self {
            var grid = [_][size]?Cell{[_]?Cell{null} ** size} ** size;
            grid[start.y][start.x] = .start;
            grid[end.y][end.x] = .end;
            inline for (walls) |p| {
                grid[p.y][p.x] = .wall;
            }
            return Self{ .grid = grid, .start = start, .end = end };
        }

        fn get_safe(self: Self, position: Point) AstarError!?Cell {
            if (position.x < 0 or position.x >= self.len or position.y < 0 or position.y >= self.len) {
                return AstarError.OutOfBounds;
            }
            return self.grid[position.y][position.x];
        }

        fn print_grid(self: Self) void {
            for (self.len * 2 + 1) |_| print("_", .{});
            for (self.grid) |row| {
                print("\n", .{});
                for (row) |cell| {
                    var char: u8 = ' ';
                    if (cell) |c| {
                        if (c == .start) char = 'a' else if (c == .end) char = 'b' else char = 'x';
                    }
                    print("|{c}", .{char});
                }
                print("|", .{});
            }
            print("\n", .{});
            for (self.len * 2 + 1) |_| print("-", .{});
            print("\n", .{});
        }

        fn solve(self: Self, allocator: std.mem.Allocator) !Result {
            // create list of open nodes
            var open = std.PriorityQueue(*Node, void, Node._lessThan).init(allocator, {});
            defer open.deinit();
            const first_open = try allocator.create(Node);
            first_open.* = Node{ .pos = self.start, .h_score = self.start.pathagorean(self.end), .g_score = 0, .parent = null };
            try open.add(first_open);

            var closed_hm = std.AutoHashMap(Point, *Node).init(allocator);
            defer {
                var iter = closed_hm.valueIterator();
                while (iter.next()) |n| allocator.destroy(n.*);
            }
            defer closed_hm.deinit();
            var open_hm = std.AutoHashMap(Point, *Node).init(allocator);
            defer {
                var iter = open_hm.valueIterator();
                while (iter.next()) |n| allocator.destroy(n.*);
            }
            defer open_hm.deinit();
            try open_hm.put(self.start, first_open);

            const end: ?*Node = examine_open: while (open.removeOrNull()) |cur_node| {
                _ = open_hm.remove(cur_node.pos);
                neighbors: for (neighbor_directions) |direction| {
                    const neighbor_point = cur_node.pos.add(direction);
                    const distance_from_cur_node: f64 = if (direction.x == 0 or direction.y == 0) 1.0 else std.math.sqrt2;
                    const neighbor = self.get_safe(neighbor_point) catch {
                        continue :neighbors;
                    };
                    if (neighbor != null and neighbor.? == .end) {
                        break :examine_open cur_node;
                    }
                    if (neighbor != null) {
                        continue :neighbors;
                    }
                    const g_score = cur_node.g_score + distance_from_cur_node;
                    const f_score = neighbor_point.pathagorean(self.end) + g_score;
                    const closed_node_from_hm = closed_hm.get(neighbor_point);
                    if (closed_node_from_hm) |cn| {
                        if (cn.f_score() > f_score) {
                            cn.g_score = g_score;
                            cn.parent = cur_node;
                        } else {
                            continue :neighbors;
                        }
                    }
                    const open_node_from_hm = open_hm.get(neighbor_point);
                    if (open_node_from_hm) |on| {
                        if (on.f_score() > f_score) {
                            on.g_score = g_score;
                            on.parent = cur_node;
                        } else {
                            continue :neighbors;
                        }
                    }
                    const new_open_node = try allocator.create(Node);
                    new_open_node.* = Node{ .pos = neighbor_point, .h_score = neighbor_point.pathagorean(self.end), .g_score = g_score, .parent = null };
                    new_open_node.parent = cur_node;
                }
                try closed_hm.put(cur_node.pos, cur_node);
            } else null;
            var path = std.ArrayList(Point).init(allocator);
            var node = end;
            while (node) |n| {
                try path.append(n.pos);
                node = n.parent;
            }
            return Result{ .allocator = allocator, .path = path, .found_end = end != null };
        }
    };
}

fn build_grid_possible() Astar(7) {
    // _____________
    //| | | | | | | |
    //| | |b|*|*|*| |
    //| |x|x|x|x|x|*|
    //| |x| | | |*| |
    //| | | | |a| | |
    //| | | | | | | |
    //| | | | | | | |
    // _____________
    //
    // each square is 1 unit in width and height
    // squares are sqrt(2) units away from each other, diagonally
    // correct shortest path is marked by * but will not be shown in the returned data structure
    var walls = [_]Point{undefined} ** 6;
    inline for (.{ 1, 2, 3, 4, 5 }, 0..) |x, i| {
        walls[i] = Point{ .x = x, .y = 2 };
    }
    walls[5] = Point{ .x = 1, .y = 3 };
    return Astar(7).new(Point{ .x = 4, .y = 4 }, Point{ .x = 2, .y = 1 }, &walls);
}
fn build_grid_impossible() Astar(7) {
    // _____________
    //| | | | | | | |
    //| | |b| | | | |
    //|x|x|x|x|x|x|x|
    //| |x| | | | | |
    //| | | | |a| | |
    //| | | | | | | |
    //| | | | | | | |
    // _____________
    var walls = [_]Point{undefined} ** 8;
    inline for (.{ 0, 1, 2, 3, 4, 5, 6 }, 0..) |x, i| {
        walls[i] = Point{ .x = x, .y = 2 };
    }
    walls[7] = Point{ .x = 1, .y = 3 };
    return Astar(7).new(Point{ .x = 4, .y = 4 }, Point{ .x = 2, .y = 1 }, &walls);
}
test "print_grid" {
    const astar = build_grid_possible();
    astar.print_grid();
}
test "a_reaches_b" {
    const testing = std.testing;
    const astar = build_grid_possible();
    const result = try astar.solve(testing.allocator);
    try testing.expect(result.found_end);
}
test "shortest_path_is_correct_units_long" {}
test "shortest_path_is_correct_path" {}
test "a_does_not_reach_b_given_impossible_path" {}
