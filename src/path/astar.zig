const std = @import("std");
const print = std.debug.print;

pub const Cell = enum(u8) {
    wall,
    empty,
};

const Point = struct {
    x: i32,
    y: i32,

    const Self = @This();
    fn pathagorean(self: Self, other_point: Point) f64 {
        const diff_x: f64 = @floatFromInt(if (self.x > other_point.x) self.x - other_point.x else other_point.x - self.x);
        const diff_y: f64 = @floatFromInt(if (self.y > other_point.y) self.y - other_point.y else other_point.y - self.y);
        return std.math.sqrt(std.math.pow(f64, diff_x, 2) + std.math.pow(f64, diff_y, 2));
    }

    fn add(self: Self, other_point: Point) Self {
        return Self{ .x = self.x + other_point.x, .y = self.y + other_point.y };
    }

    fn equal(self: Self, other_point: Point) bool {
        return self.x == other_point.x and self.y == other_point.y;
    }
};

/// Result of astar algorithm completion.
/// Requires deinitialization because `.path` uses a memory allocated list.
const Result = struct {
    /// allocator used for `.path`, which is an `ArrayList`
    allocator: std.mem.Allocator,

    /// `true` if end is found
    found_end: bool,

    /// path from end to start (notice it is in reverse), inclusive of both
    path: std.ArrayList(Point),

    const Self = @This();
    fn deinit(self: *const Self) void {
        self.path.deinit();
    }
    fn calculate_path_length(self: *const Self) f64 {
        if (self.path.items.len < 2) {
            return 0;
        }
        var sum: f64 = 0;
        const items = self.path.items;
        for (items[0 .. items.len - 1], items[1..]) |prev_point, point| {
            sum += prev_point.pathagorean(point);
        }
        return sum;
    }
};

const AstarError = error{
    OutOfBounds,
};

/// Data structure that holds grid.
/// Call `.new(...)` to create a new instance
/// Call `.solve()` on instance to find shortest path to `.end` using the A* path finding algorithm.
pub fn Astar(size: comptime_int) type {
    return struct {
        grid: std.StaticBitSet(size * size),
        side_len: u32 = size,
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
            point: Point,
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

        /// Create new instance of `Astar`. `walls` param represents blockages that solution is not allowed to use in path.
        /// Walls passed in that are out of bounds are ignored.
        fn new(start: Point, end: Point, walls: []const Point) Self {
            const grid = std.StaticBitSet(size * size).initEmpty();
            var astar = Self{ .grid = grid, .start = start, .end = end };
            for (walls) |p| {
                if (p.equal(start) or p.equal(end)) continue;
                astar.set_cell(p, .wall) catch {}; // TODO: decide if bad walls should be handled
            }
            return astar;
        }

        fn get_cell(self: *const Self, point: Point) AstarError!Cell {
            if (point.x < 0 or point.x >= self.side_len or point.y < 0 or point.y >= self.side_len) {
                return AstarError.OutOfBounds;
            }
            const index = @as(usize, @intCast(point.y)) * @as(usize, size) + @as(usize, @intCast(point.x));
            return if (self.grid.isSet(index)) .wall else .empty;
        }

        fn set_cell(self: *Self, point: Point, value: Cell) !void {
            if (point.x < 0 or point.x >= self.side_len or point.y < 0 or point.y >= self.side_len) {
                return AstarError.OutOfBounds;
            }
            const index = @as(usize, @intCast(point.y)) * @as(usize, size) + @as(usize, @intCast(point.x));
            const b_value = switch (value) {
                .wall => true,
                .empty => false,
            };
            self.grid.setValue(index, b_value);
        }

        /// Print grid, optionally pass in a `Result` if path solution should also be printed.
        fn print_grid(self: *const Self, result: ?*const Result) !void {
            var set: ?std.AutoHashMap(Point, void) = null;
            if (result) |r| {
                set = std.AutoHashMap(Point, void).init(r.allocator);
                for (r.path.items) |point| {
                    try set.?.put(point, {});
                }
            }
            defer if (set != null) set.?.deinit();
            for (self.side_len * 2 + 1) |_| print("_", .{});
            for (0..self.side_len) |y| {
                print("\n", .{});
                for (0..self.side_len) |x| {
                    const point = Point{ .x = @intCast(x), .y = @intCast(y) };
                    const cell = try self.get_cell(point);
                    var char: u8 = if (cell == .wall) 'x' else ' ';
                    if (self.start.equal(point)) {
                        char = 'a';
                    } else if (self.end.equal(point)) {
                        char = 'b';
                    } else if (set) |s| {
                        if (s.contains(point)) char = '*';
                    }
                    print("|{c}", .{char});
                }
                print("|", .{});
            }
            print("\n", .{});
            for (self.side_len * 2 + 1) |_| print("-", .{});
            print("\n", .{});
        }

        /// solves astar algorithm and returns result
        fn solve(self: *const Self, allocator: std.mem.Allocator) !Result {
            // create list of open nodes
            var open = std.PriorityQueue(*Node, void, Node._lessThan).init(allocator, {});
            defer open.deinit();
            const first_open = try allocator.create(Node);
            first_open.* = Node{ .point = self.start, .h_score = self.start.pathagorean(self.end), .g_score = 0, .parent = null };
            try open.add(first_open);

            var closed_hm = std.AutoHashMap(Point, *Node).init(allocator);
            defer {
                var iter = closed_hm.valueIterator();
                while (iter.next()) |n| allocator.destroy(n.*);
                closed_hm.deinit();
            }
            var open_hm = std.AutoHashMap(Point, *Node).init(allocator);
            defer {
                var iter = open_hm.valueIterator();
                while (iter.next()) |n| allocator.destroy(n.*);
                open_hm.deinit();
            }
            try open_hm.put(self.start, first_open);

            const end: ?*Node = examine_open: while (open.removeOrNull()) |cur_node| {
                _ = open_hm.remove(cur_node.point);
                if (closed_hm.get(cur_node.point)) |n| allocator.destroy(n);
                try closed_hm.put(cur_node.point, cur_node);
                neighbors: for (neighbor_directions) |direction| {
                    const neighbor_point = cur_node.point.add(direction);
                    const neighbor = self.get_cell(neighbor_point) catch {
                        continue :neighbors;
                    };
                    if (neighbor == .wall) continue :neighbors;
                    if (neighbor_point.equal(self.end)) break :examine_open cur_node;

                    const nei_cur_distance: f64 = if (direction.x == 0 or direction.y == 0) 1.0 else std.math.sqrt2;
                    const g_score = cur_node.g_score + nei_cur_distance;
                    const h_score = neighbor_point.pathagorean(self.end);
                    const closed_node = closed_hm.get(neighbor_point);
                    if (closed_node) |cn| {
                        if (g_score >= cn.g_score) continue :neighbors;
                    }
                    const open_node = open_hm.get(neighbor_point);
                    if (open_node) |on| {
                        if (g_score < on.g_score) {
                            on.g_score = g_score;
                            on.parent = cur_node;
                            try open.update(on, on);
                        }
                        continue :neighbors;
                    }
                    const new_open_node = try allocator.create(Node);
                    new_open_node.* = Node{ .point = neighbor_point, .h_score = h_score, .g_score = g_score, .parent = cur_node };
                    try open_hm.put(neighbor_point, new_open_node);
                    try open.add(new_open_node);
                }
            } else null;
            var path = std.ArrayList(Point).init(allocator);
            if (end != null) try path.append(self.end);
            var node = end;
            while (node) |n| {
                try path.append(n.point);
                node = n.parent;
            }
            return Result{ .allocator = allocator, .path = path, .found_end = end != null };
        }
    };
}

fn build_grid_possible() Astar(7) {
    //  _____________
    // | | | | | | | |
    // | | |b|*|*|*| |
    // | |x|x|x|x|x|*|
    // | |x| | | |*| |
    // | | | | |a| | |
    // | | | | | | | |
    // | | | | | | | |
    // ---------------
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
    //  _____________
    // | | | | | | | |
    // | | |b| | | | |
    // |x|x|x|x|x|x|x|
    // | |x| | | | | |
    // | | | | |a| | |
    // | | | | | | | |
    // | | | | | | | |
    // ---------------
    var walls = [_]Point{undefined} ** 8;
    inline for (.{ 0, 1, 2, 3, 4, 5, 6 }, 0..) |x, i| {
        walls[i] = Point{ .x = x, .y = 2 };
    }
    walls[7] = Point{ .x = 1, .y = 3 };
    return Astar(7).new(Point{ .x = 4, .y = 4 }, Point{ .x = 2, .y = 1 }, &walls);
}
fn build_huge_grid_possible() Astar(20) {
    // _________________________________________
    // | |x|x| | | |x| |x|x|x| |x| |x|x|*|b| | |
    // | | | | | |x|x| |x| |x| | |x| |*|x|x|x|x|
    // |x|x| | |x| | |x|x|x|x|x| |x|*|x| |x| |x|
    // |x|x|x|x|x| | | | | | |x|*|*| |x|x| | | |
    // | | |x|x| | | |x|*|*|*|*|x| | |x|x|x| |x|
    // | | |x| | | |x|*| | | | |x| | |x|x| | | |
    // |x|x|x|x|x|*|*|x| | | | |x| | | | |x| |x|
    // | |x|*|*|*|x| | | |x|x|x|x|x| |x| | | | |
    // | |*|x|x|x|x|x| | | | |x| | | | | | | |x|
    // |x| |*| | | |x|x|x|x| | |x| |x| |x|x| | |
    // | | |*| |x| |x| |x| | | | | | |x|x| |x|x|
    // | |x|*| |x| | |x|x|x| |x|x| | | | |x| |x|
    // |x|x|*| | |x|x| |x|x| | |x|x| |x| | | | |
    // | |*|x| |x|x|x| | |x|x| | | |x|x| |x| | |
    // | |*|x|x|x| |x|x| | |x|x|x|x|x| | | |x|x|
    // |x|x|*| |x|x| | | | |x| | | |x| | | | | |
    // |x| |*| |x| |x| | | |x| | | | | |x| | |x|
    // | |x|*|x| | |x| |x|x| | | | |x| | | | |x|
    // | | |a| |x|x| | | | | | |x|x| | |x| | | |
    // | | | |x| | | | | |x| | | |x| | | | | | |
    // -----------------------------------------
    var prng = std.Random.DefaultPrng.init(8019);
    const rand = prng.random();
    var walls = [_]Point{undefined} ** 200;
    for (0..200) |i| {
        walls[i] = Point{ .x = rand.intRangeLessThan(i32, 0, 20), .y = rand.intRangeLessThan(i32, 0, 20) };
    }
    return Astar(20).new(Point{ .x = 2, .y = 18 }, Point{ .x = 17, .y = 0 }, &walls);
}
test "print_grid" {
    const astar = build_grid_possible();
    print("\nUnsolved grid:\n", .{});
    try astar.print_grid(null);
}
test "print_possible_grid_with_result" {
    const testing = std.testing;
    const astar = build_grid_possible();
    const result = try astar.solve(testing.allocator);
    defer result.deinit();
    print("\nSolved grid:\n", .{});
    try astar.print_grid(&result);
}
test "print_impossible_grid_with_result" {
    const testing = std.testing;
    const astar = build_grid_impossible();
    const result = try astar.solve(testing.allocator);
    defer result.deinit();
    print("\nUnsolvable grid:\n", .{});
    try astar.print_grid(&result);
}
test "a_reaches_b" {
    const testing = std.testing;
    const astar = build_grid_possible();
    const result = try astar.solve(testing.allocator);
    defer result.deinit();
    try testing.expect(result.found_end);
}
test "shortest_path_is_correct_units_long" {
    const testing = std.testing;
    const astar = build_grid_possible();
    const result = try astar.solve(testing.allocator);
    defer result.deinit();
    try testing.expectApproxEqAbs(7.2426, result.calculate_path_length(), 0.0001);
}
test "shortest_path_is_correct_path" {
    const testing = std.testing;
    const astar = build_grid_possible();
    const result = try astar.solve(testing.allocator);
    defer result.deinit();

    const expected = [_]Point{
        Point{ .x = 2, .y = 1 },
        Point{ .x = 3, .y = 1 },
        Point{ .x = 4, .y = 1 },
        Point{ .x = 5, .y = 1 },
        Point{ .x = 6, .y = 2 },
        Point{ .x = 5, .y = 3 },
        Point{ .x = 4, .y = 4 },
    };
    for (expected, result.path.items) |exp, res| {
        try testing.expect(exp.equal(res));
    }
}
test "a_does_not_reach_b_given_impossible_path" {
    const testing = std.testing;
    const astar = build_grid_impossible();
    const result = try astar.solve(testing.allocator);
    defer result.deinit();
    try testing.expect(!result.found_end);
    try testing.expectEqual(0, result.path.items.len);
}
test "huge_grid" {
    const testing = std.testing;
    const astar = build_huge_grid_possible();
    const result = try astar.solve(testing.allocator);
    defer result.deinit();
    try testing.expect(result.found_end);
    try astar.print_grid(&result);
}
